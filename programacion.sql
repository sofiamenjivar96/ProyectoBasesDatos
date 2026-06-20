-- .................................................
--       SISTEMA DE RESERVAS DE HOTEL
-- .................................................

-- ==========================================================
-- FUNCIÓN 1: Calcular total de hospedaje
-- Esta función obtiene el precio por noche de la habitación
-- reservada y lo multiplica por la cantidad de noches.
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_hospedaje(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_precio NUMERIC;
    v_noches INT;
BEGIN
    -- Obtiene precio por noche y cantidad de noches reservadas
    SELECT 
        th.precio_noche,
        (r.fecha_fin - r.fecha_inicio)
    INTO v_precio, v_noches
    FROM reservacion r
    INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
    INNER JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo
    WHERE r.id_reservacion = p_id_reservacion;

    -- Retorna el total del hospedaje
    RETURN COALESCE(v_precio * v_noches, 0);
END;
$$ LANGUAGE plpgsql;


-- ==========================================================
-- FUNCIÓN 2: Calcular total de servicios consumidos
-- Suma todos los servicios asociados a una reservación.
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_servicios(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    -- Calcula el total gastado en servicios
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
-- FUNCIÓN 3: Calcular total final
-- Suma hospedaje + servicios consumidos.
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
-- Calcula subtotal, impuestos y total final, luego inserta
-- la factura en la tabla correspondiente.
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
    -- Calcula subtotal e impuestos (13%)
    v_subtotal := calcular_total_final(p_id_reservacion);  
    v_impuestos := v_subtotal * 0.13;
    v_total := v_subtotal + v_impuestos;
    
    -- Genera número de factura consecutivo
    SELECT COALESCE(MAX(numero_factura), 0) + 1 
    INTO v_numero 
    FROM factura; 
   
    -- Inserta la factura
    INSERT INTO factura (
        numero_factura, fecha_emision, subtotal, impuestos,
        total_final, id_reservacion, id_empleado
    )   
    VALUES (
        v_numero, NOW(), v_subtotal, v_impuestos,
        v_total, p_id_reservacion, p_id_empleado
    );
    
    RAISE NOTICE 'Factura generada correctamente. Número: %, Total: %', v_numero, v_total;
END;
$$;


-- ==========================================================
-- PROCEDIMIENTO: Agregar detalle de factura
-- Inserta los servicios consumidos dentro de una factura.
-- ==========================================================
CREATE OR REPLACE PROCEDURE agregar_detalle_factura(
    p_id_factura BIGINT,
    p_id_servicio BIGINT,
    p_cantidad INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio NUMERIC;
BEGIN
  
    -- Obtiene precio unitario del servicio
    SELECT costo_unitario 
    INTO v_precio  
    FROM servicio
    WHERE id_servicio = p_id_servicio;
    
    -- Verifica que el servicio exista
    IF v_precio IS NULL THEN 
        RAISE EXCEPTION 'El servicio con ID % no existe', p_id_servicio;
    END IF;
    
    -- Valida cantidad ingresada
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
    END IF;

    -- Inserta detalle en factura
    INSERT INTO detalles_factura (id_factura, id_servicio, cantidad, precio) 
    VALUES (p_id_factura, p_id_servicio, p_cantidad, v_precio);
    
    RAISE NOTICE 'Detalle agregado: Servicio %, Cantidad %, Precio %', 
        p_id_servicio, p_cantidad, v_precio;
END;
$$;


-- ==========================================================
-- TRIGGER 1: Validar fechas de check-in/out
-- Evita inconsistencias en fechas de entrada y salida.
-- ==========================================================
CREATE OR REPLACE FUNCTION validar_fechas_checkin()
RETURNS TRIGGER AS $$
BEGIN
   
    -- La fecha de entrada no puede ser nula
    IF NEW.fecha_entrada IS NULL THEN  
        RAISE EXCEPTION 'La fecha de entrada no puede ser NULL';
    END IF;
    
    -- La fecha de salida debe ser posterior a la entrada
    IF NEW.fecha_salida IS NOT NULL AND NEW.fecha_salida <= NEW.fecha_entrada THEN  
        RAISE EXCEPTION 'La fecha de salida (%) debe ser mayor que la fecha de entrada (%)',
            NEW.fecha_salida, NEW.fecha_entrada;
    END IF;
    
    -- Advertencia si la fecha es muy lejana
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
-- Cambia automáticamente el estado de la habitación.
-- ==========================================================
CREATE OR REPLACE FUNCTION ocupar_habitacion()
RETURNS TRIGGER AS $$
BEGIN
    
    -- Verifica disponibilidad de habitación
    IF (SELECT estado FROM habitacion WHERE id_habitacion = NEW.id_habitacion) != 'Disponible' THEN
        RAISE EXCEPTION 'La habitación % no está disponible (estado actual: %)',
            NEW.id_habitacion, 
            (SELECT estado FROM habitacion WHERE id_habitacion = NEW.id_habitacion);
    END IF;
    
    -- Marca habitación como ocupada
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
-- TRIGGER 3: Liberar habitación al finalizar o cancelar reservación
-- Devuelve la habitación al estado Disponible.
-- ==========================================================
CREATE OR REPLACE FUNCTION liberar_habitacion_por_cambio_estado()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el estado cambia a Finalizada o Cancelada, libera la habitación
    IF NEW.estado_reserva IN ('Finalizada', 'Cancelada') AND OLD.estado_reserva NOT IN ('Finalizada', 'Cancelada') THEN
        UPDATE habitacion
        SET estado = 'Disponible'
        WHERE id_habitacion = NEW.id_habitacion;
        
        RAISE NOTICE 'Habitación % liberada (Reservación % estado: %)', 
            NEW.id_habitacion, NEW.id_reservacion, NEW.estado_reserva;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Eliminar los triggers antiguos
DROP TRIGGER IF EXISTS tg_liberar_habitacion ON reservacion;
DROP TRIGGER IF EXISTS tg_liberar_habitacion_cancelada ON reservacion;

-- Crear el trigger unificado
CREATE TRIGGER tg_liberar_habitacion_estado
AFTER UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION liberar_habitacion_por_cambio_estado();


-- ==========================================================
-- TRIGGER 4: Verificar disponibilidad de habitación
-- Evita reservaciones en fechas superpuestas.
-- ==========================================================
CREATE OR REPLACE FUNCTION verificar_disponibilidad_habitacion()
RETURNS TRIGGER AS $$
DECLARE
    v_habitacion_existente RECORD;
BEGIN
   
    -- Busca reservaciones que entren en conflicto
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
-- TRIGGER 5: Validar fechas de reservación
-- Verifica que las fechas de reserva sean coherentes.
-- ==========================================================
CREATE OR REPLACE FUNCTION validar_fechas_reservacion()
RETURNS TRIGGER AS $$
BEGIN
  
    -- La fecha de inicio no puede ser anterior a la fecha de reserva
    IF NEW.fecha_inicio < NEW.fecha_reserva THEN
        RAISE EXCEPTION 'La fecha de inicio (%) no puede ser anterior a la fecha de reserva (%)',
            NEW.fecha_inicio, NEW.fecha_reserva;
    END IF;
    
    -- La fecha de fin debe ser mayor que la fecha de inicio
    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        RAISE EXCEPTION 'La fecha de fin (%) debe ser mayor que la fecha de inicio (%)',
            NEW.fecha_fin, NEW.fecha_inicio;
    END IF;
    
    -- Advertencia si la reservación es muy lejana
    IF NEW.fecha_inicio > (CURRENT_DATE + INTERVAL '1 year') THEN
        RAISE WARNING 'La reservación es para más de 1 año en el futuro: %', NEW.fecha_inicio;
    END IF;
    
    -- Advertencia para estadías largas
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
-- TRIGGER 6: Validar reservaciones con fecha vencida
-- Lanza advertencia si una reservación activa ya debería
-- haber iniciado.
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
-- Facilita la consulta de reservaciones activas.
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
-- Muestra ingresos y estadísticas de facturación.
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
-- Lista huéspedes con más consumo en el sistema.
-- ==========================================================
CREATE OR REPLACE VIEW v_top_huespedes AS
SELECT
    hu.id_huesped,
    hu.nombre,
    hu.apellido,
    hu.telefono,
    hu.email,
    COUNT(r.id_reservacion) AS total_reservaciones,
    SUM(calcular_total_final(r.id_reservacion)) AS total_gastado  --  Suma todas las reservaciones
FROM huesped hu
INNER JOIN reservacion r ON hu.id_huesped = r.id_huesped
WHERE r.estado_reserva IN ('Finalizada', 'Activa')
GROUP BY hu.id_huesped, hu.nombre, hu.apellido, hu.telefono, hu.email  -- Solo agrupa por huésped
ORDER BY total_gastado DESC
LIMIT 10;

-- ==========================================================
-- FUNCIÓN: Verificar disponibilidad por fechas
-- Retorna TRUE si la habitación está libre.
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
-- PROCEDIMIENTO: Cancelar reservación
-- Valida y cambia estado a Cancelada.
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

    -- Verifica existencia
    IF v_estado_actual IS NULL THEN
        RAISE EXCEPTION 'La reservación con ID % no existe', p_id_reservacion;
    END IF;
    
    -- Valida estados no permitidos
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
-- PROCEDIMIENTO: Finalizar reservación
-- Cambia estado a Finalizada con validaciones.
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

    -- Verifica existencia
    IF v_estado_actual IS NULL THEN
        RAISE EXCEPTION 'La reservación con ID % no existe', p_id_reservacion;
    END IF;
    
    -- Valida estados
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
-- Muestra resumen de objetos creados en el sistema.
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
