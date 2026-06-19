-- .................................................
--       SISTEMA DE RESERVAS DE HOTEL
--...................................................

-- ==========================================================
-- FUNCIÓN 1: Calcular total de hospedaje
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_hospedaje(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_precio NUMERIC;
    v_noches INT;
BEGIN
    SELECT 
        th.precio_noche,
        (r.fecha_fin - r.fecha_inicio)
    INTO v_precio, v_noches
    FROM reservacion r
    INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
    INNER JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo
    WHERE r.id_reservacion = p_id_reservacion;

    RETURN COALESCE(v_precio * v_noches, 0);
END;
$$ LANGUAGE plpgsql;


-- ==========================================================
-- FUNCIÓN 2: Calcular total de servicios consumidos
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_servicios(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT 
        COALESCE(SUM(cs.cantidad * s.costo_unitario), 0)
    INTO v_total
    FROM consumo_servicio cs
    INNER JOIN servicio s ON cs.id_servicio = s.id_servicio
    WHERE cs.id_reservacion = p_id_reservacion;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;


-- ==========================================================
-- FUNCIÓN 3: Calcular total final (hospedaje + servicios)
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_final(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
BEGIN
    RETURN 
        calcular_total_hospedaje(p_id_reservacion)
        +
        calcular_total_servicios(p_id_reservacion);
END;
$$ LANGUAGE plpgsql;


-- ==========================================================
-- PROCEDIMIENTO: Generar factura automáticamente
-- ==========================================================
CREATE OR REPLACE PROCEDURE generar_factura(p_id_reservacion BIGINT, p_id_empleado BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_subtotal  NUMERIC;
    v_impuestos NUMERIC;
    v_total NUMERIC;
    v_numero INT;

BEGIN  
    v_subtotal := calcular_total_final(p_id_reservacion);  
    v_impuestos := v_subtotal * 0.13;
    v_total := v_subtotal + v_impuestos;
    
    SELECT COALESCE(MAX(numero_factura), 0) + 1 INTO v_numero FROM factura; 
   

      INSERT INTO factura (numero_factura, fecha_emision, subtotal, impuestos, total_final, id_reservacion, id_empleado)   
    VALUES (v_numero, NOW(), v_subtotal, v_impuestos, v_total, p_id_reservacion, p_id_empleado);
    
    RAISE NOTICE 'Factura generada correctamente. Número: %, Total: %', v_numero, v_total;
END;
$$;


-- ==========================================================
-- PROCEDIMIENTO: Agregar detalle de factura
-- ==========================================================
CREATE OR REPLACE PROCEDURE agregar_detalle_factura(p_id_factura BIGINT, p_id_servicio BIGINT, p_cantidad INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio NUMERIC;
BEGIN
  
    SELECT costo_unitario INTO v_precio  
    FROM servicio
    WHERE id_servicio = p_id_servicio;
    
   
    IF v_precio IS NULL THEN 
        RAISE EXCEPTION 'El servicio con ID % no existe', p_id_servicio;
    END IF;
    
    
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
    END IF;

   
    INSERT INTO detalles_factura (id_factura, id_servicio, cantidad, precio) 
    VALUES (p_id_factura, p_id_servicio, p_cantidad, v_precio);
    
    RAISE NOTICE 'Detalle agregado: Servicio %, Cantidad %, Precio %', 
        p_id_servicio, p_cantidad, v_precio;
END;
$$;


-- ==========================================================
-- TRIGGER 1: Validar fechas de check-in/out
-- ==========================================================
CREATE OR REPLACE FUNCTION validar_fechas_checkin()
RETURNS TRIGGER AS $$
BEGIN
   
    IF NEW.fecha_entrada IS NULL THEN  
        RAISE EXCEPTION 'La fecha de entrada no puede ser NULL';
    END IF;
    
  
    IF NEW.fecha_salida IS NOT NULL AND NEW.fecha_salida <= NEW.fecha_entrada THEN  
        RAISE EXCEPTION 'La fecha de salida (%) debe ser mayor que la fecha de entrada (%)',
            NEW.fecha_salida, NEW.fecha_entrada;
    END IF;
    
    
    IF NEW.fecha_entrada > (CURRENT_DATE + INTERVAL '30 days') THEN 
        RAISE WARNING 'La fecha de entrada es muy lejana: %', NEW.fecha_entrada;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_validar_fechas_checkin ON check_in_out;
CREATE TRIGGER tg_validar_fechas_checkin
BEFORE INSERT OR UPDATE ON check_in_out
FOR EACH ROW
EXECUTE FUNCTION validar_fechas_checkin();


-- ==========================================================
-- TRIGGER 2: Ocupar habitación al crear reservación
-- ==========================================================
CREATE OR REPLACE FUNCTION ocupar_habitacion()
RETURNS TRIGGER AS $$
BEGIN
    
    IF (SELECT estado FROM habitacion WHERE id_habitacion = NEW.id_habitacion) != 'Disponible' THEN
        RAISE WARNING 'La habitación % no está disponible (estado actual: %)',
            NEW.id_habitacion, (SELECT estado FROM habitacion WHERE id_habitacion = NEW.id_habitacion);
    END IF;
    
    UPDATE habitacion
    SET estado = 'Ocupada'
    WHERE id_habitacion = NEW.id_habitacion;
    
    RAISE NOTICE 'Habitación % ocupada exitosamente', NEW.id_habitacion;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_ocupar_habitacion ON reservacion;
CREATE TRIGGER tg_ocupar_habitacion
AFTER INSERT ON reservacion
FOR EACH ROW
EXECUTE FUNCTION ocupar_habitacion();


-- ==========================================================
-- TRIGGER 3: Liberar habitación al finalizar reservación
-- ==========================================================
CREATE OR REPLACE FUNCTION liberar_habitacion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado_reserva = 'Finalizada' AND OLD.estado_reserva != 'Finalizada' THEN
        UPDATE habitacion
        SET estado = 'Disponible'
        WHERE id_habitacion = NEW.id_habitacion;
        
        RAISE NOTICE 'Habitación % liberada al finalizar reservación', NEW.id_habitacion;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_liberar_habitacion ON reservacion;
CREATE TRIGGER tg_liberar_habitacion
AFTER UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION liberar_habitacion();


-- ==========================================================
-- TRIGGER 4: Verificar que la habitación no esté reservada
--            en el mismo período
-- ==========================================================
CREATE OR REPLACE FUNCTION verificar_disponibilidad_habitacion()
RETURNS TRIGGER AS $$
DECLARE
    v_habitacion_existente RECORD;
BEGIN
   
    SELECT r.id_reservacion, r.estado_reserva, r.fecha_inicio, r.fecha_fin
    INTO v_habitacion_existente
    FROM reservacion r
    WHERE r.id_habitacion = NEW.id_habitacion
      AND r.estado_reserva != 'Cancelada'
      AND r.id_reservacion != COALESCE(NEW.id_reservacion, -1)
      AND (NEW.fecha_inicio, NEW.fecha_fin) OVERLAPS (r.fecha_inicio, r.fecha_fin)
    LIMIT 1;
    

    IF FOUND THEN
        RAISE EXCEPTION 'La habitación % ya tiene una reservación activa en ese período.%',
            NEW.id_habitacion,
            CHR(10) || 'Reservación conflictiva: ID ' || v_habitacion_existente.id_reservacion ||
            ', Estado: ' || v_habitacion_existente.estado_reserva ||
            ', Fechas: ' || v_habitacion_existente.fecha_inicio || ' a ' || v_habitacion_existente.fecha_fin;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_verificar_disponibilidad ON reservacion;
CREATE TRIGGER tg_verificar_disponibilidad
BEFORE INSERT OR UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION verificar_disponibilidad_habitacion();


-- ==========================================================
-- TRIGGER 5: Liberar habitación al cancelar reservación
-- ==========================================================
CREATE OR REPLACE FUNCTION liberar_habitacion_cancelada()
RETURNS TRIGGER AS $$
BEGIN
  
    IF NEW.estado_reserva = 'Cancelada' AND OLD.estado_reserva != 'Cancelada' THEN
        UPDATE habitacion
        SET estado = 'Disponible'
        WHERE id_habitacion = NEW.id_habitacion;
        
        RAISE NOTICE 'Habitación % liberada al cancelar reservación %', 
            NEW.id_habitacion, NEW.id_reservacion;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_liberar_habitacion_cancelada ON reservacion;
CREATE TRIGGER tg_liberar_habitacion_cancelada
AFTER UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION liberar_habitacion_cancelada();


-- ==========================================================
-- TRIGGER 6: Validar que las fechas de reservación sean lógicas
-- ==========================================================
CREATE OR REPLACE FUNCTION validar_fechas_reservacion()
RETURNS TRIGGER AS $$
BEGIN
  
    IF NEW.fecha_inicio < NEW.fecha_reserva THEN
        RAISE EXCEPTION 'La fecha de inicio (%) no puede ser anterior a la fecha de reserva (%)',
            NEW.fecha_inicio, NEW.fecha_reserva;
    END IF;
    
 
    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        RAISE EXCEPTION 'La fecha de fin (%) debe ser mayor que la fecha de inicio (%)',
            NEW.fecha_fin, NEW.fecha_inicio;
    END IF;
    
    
    IF NEW.fecha_inicio > (CURRENT_DATE + INTERVAL '1 year') THEN
        RAISE WARNING 'La reservación es para más de 1 año en el futuro: %', NEW.fecha_inicio;
    END IF;
    
    
    IF (NEW.fecha_fin - NEW.fecha_inicio) > 30 THEN
        RAISE WARNING 'La estadía es de % días (máximo recomendado: 30 días)',
            (NEW.fecha_fin - NEW.fecha_inicio);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_validar_fechas_reservacion ON reservacion;
CREATE TRIGGER tg_validar_fechas_reservacion
BEFORE INSERT OR UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION validar_fechas_reservacion();


-- ==========================================================
-- TRIGGER 7: Actualizar estado de reservación automáticamente
-- ==========================================================
CREATE OR REPLACE FUNCTION actualizar_estado_reservacion_vencida()
RETURNS TRIGGER AS $$
BEGIN
    
    IF NEW.estado_reserva = 'Activa' AND NEW.fecha_inicio < CURRENT_DATE THEN
        RAISE WARNING 'La reservación % tiene fecha de inicio pasada (%), debería revisarse',
            NEW.id_reservacion, NEW.fecha_inicio;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_actualizar_estado_vencido ON reservacion;
CREATE TRIGGER tg_actualizar_estado_vencido
BEFORE INSERT OR UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION actualizar_estado_reservacion_vencida();


-- ==========================================================
-- VISTA: Reservaciones activas con detalles completos
-- ==========================================================
CREATE OR REPLACE VIEW v_reservaciones_activas AS
SELECT
    r.id_reservacion,
    hu.nombre AS huesped_nombre,
    hu.apellido AS huesped_apellido,
    hu.telefono AS huesped_telefono,
    ha.numero AS habitacion_numero,
    ha.piso AS habitacion_piso,
    ho.nombre AS hotel_nombre,
    th.descripcion AS tipo_habitacion,
    th.precio_noche,
    r.fecha_inicio,
    r.fecha_fin,
    (r.fecha_fin - r.fecha_inicio) AS noches,
    r.fecha_reserva,
    r.estado_reserva
FROM reservacion r
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
INNER JOIN hotel ho ON ha.id_hotel = ho.id_hotel
INNER JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo
WHERE r.estado_reserva = 'Activa'
ORDER BY r.fecha_inicio;


-- ==========================================================
-- VISTA: Resumen de facturación por hotel
-- ==========================================================
CREATE OR REPLACE VIEW v_facturacion_por_hotel AS
SELECT
    ho.nombre AS hotel,
    COUNT(f.id_factura) AS total_facturas,
    SUM(f.subtotal) AS total_subtotal,
    SUM(f.impuestos) AS total_impuestos,
    SUM(f.total_final) AS total_ingresos,
    AVG(f.total_final) AS promedio_factura
FROM hotel ho
INNER JOIN habitacion ha ON ho.id_hotel = ha.id_hotel
INNER JOIN reservacion r ON ha.id_habitacion = r.id_habitacion
INNER JOIN factura f ON r.id_reservacion = f.id_reservacion
GROUP BY ho.nombre
ORDER BY total_ingresos DESC;


-- ==========================================================
-- VISTA: Top 10 huéspedes con mayor gasto
-- ==========================================================
CREATE OR REPLACE VIEW v_top_huespedes AS
SELECT
    hu.id_huesped,
    hu.nombre,
    hu.apellido,
    hu.telefono,
    hu.email,
    COUNT(r.id_reservacion) AS total_reservaciones,
    calcular_total_final(r.id_reservacion) AS total_gastado
FROM huesped hu
INNER JOIN reservacion r ON hu.id_huesped = r.id_huesped
WHERE r.estado_reserva IN ('Finalizada', 'Activa')
GROUP BY hu.id_huesped, hu.nombre, hu.apellido, hu.telefono, hu.email, r.id_reservacion
ORDER BY total_gastado DESC
LIMIT 10;


-- ==========================================================
-- FUNCIÓN: Verificar disponibilidad de habitación en fechas
-- ==========================================================
CREATE OR REPLACE FUNCTION verificar_disponibilidad_fechas(
    p_id_habitacion BIGINT,
    p_fecha_inicio DATE,
    p_fecha_fin DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    v_disponible BOOLEAN;
BEGIN
   
    SELECT NOT EXISTS (
        SELECT 1
        FROM reservacion
        WHERE id_habitacion = p_id_habitacion
          AND estado_reserva != 'Cancelada'
          AND (p_fecha_inicio, p_fecha_fin) OVERLAPS (fecha_inicio, fecha_fin)
    ) INTO v_disponible;
    
    RETURN v_disponible;
END;
$$ LANGUAGE plpgsql;


-- ==========================================================
-- PROCEDIMIENTO: Cancelar reservación con validaciones
-- ==========================================================
CREATE OR REPLACE PROCEDURE cancelar_reservacion(p_id_reservacion BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual VARCHAR(20);
    v_fecha_inicio DATE;
BEGIN
   
    SELECT estado_reserva, fecha_inicio INTO v_estado_actual, v_fecha_inicio
    FROM reservacion
    WHERE id_reservacion = p_id_reservacion;
    

    IF v_estado_actual IS NULL THEN
        RAISE EXCEPTION 'La reservación con ID % no existe', p_id_reservacion;
    END IF;
    
   
    IF v_estado_actual = 'Cancelada' THEN
        RAISE NOTICE 'La reservación % ya está cancelada', p_id_reservacion;
        RETURN;
    END IF;
    
    IF v_estado_actual = 'Finalizada' THEN
        RAISE EXCEPTION 'No se puede cancelar una reservación ya finalizada';
    END IF;
    
   
    IF v_fecha_inicio < CURRENT_DATE THEN
        RAISE WARNING 'La reservación tiene fecha de inicio pasada (%), se cancelará igualmente', v_fecha_inicio;
    END IF;
    
    UPDATE reservacion
    SET estado_reserva = 'Cancelada'
    WHERE id_reservacion = p_id_reservacion;
    
    RAISE NOTICE 'Reservación % cancelada exitosamente', p_id_reservacion;
END;
$$;


-- ==========================================================
-- PROCEDIMIENTO: Finalizar reservación automáticamente
-- ==========================================================
CREATE OR REPLACE PROCEDURE finalizar_reservacion(p_id_reservacion BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual VARCHAR(20);
BEGIN
 
    SELECT estado_reserva INTO v_estado_actual
    FROM reservacion
    WHERE id_reservacion = p_id_reservacion;
    

    IF v_estado_actual IS NULL THEN
        RAISE EXCEPTION 'La reservación con ID % no existe', p_id_reservacion;
    END IF;
    
 
    IF v_estado_actual = 'Cancelada' THEN
        RAISE EXCEPTION 'No se puede finalizar una reservación cancelada';
    END IF;
    
    IF v_estado_actual = 'Finalizada' THEN
        RAISE NOTICE 'La reservación % ya está finalizada', p_id_reservacion;
        RETURN;
    END IF;
    
   
    UPDATE reservacion
    SET estado_reserva = 'Finalizada'
    WHERE id_reservacion = p_id_reservacion;
    
    RAISE NOTICE 'Reservación % finalizada exitosamente', p_id_reservacion;
END;
$$;


-- ==========================================================
-- MENSAJE DE CONFIRMACIÓN
-- ==========================================================
DO $$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE '  PROGRAMACIÓN SQL CARGADA EXITOSAMENTE';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '  Funciones: 4';
    RAISE NOTICE '  Procedimientos: 4';
    RAISE NOTICE '  Triggers: 7';
    RAISE NOTICE '  Vistas: 3';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '  ✅ calcular_total_hospedaje()';
    RAISE NOTICE '  ✅ calcular_total_servicios()';
    RAISE NOTICE '  ✅ calcular_total_final()';
    RAISE NOTICE '  ✅ verificar_disponibilidad_fechas()';
    RAISE NOTICE '  ✅ generar_factura()';
    RAISE NOTICE '  ✅ agregar_detalle_factura()';
    RAISE NOTICE '  ✅ cancelar_reservacion()';
    RAISE NOTICE '  ✅ finalizar_reservacion()';
    RAISE NOTICE '==========================================';
END;
$$;
