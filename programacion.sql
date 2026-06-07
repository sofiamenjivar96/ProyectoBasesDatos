-- ==========================================================
--    PROGRAMACION SQL – SISTEMA DE RESERVAS DE HOTEL
-- ==========================================================

-- ==========================================================
-- FUNCIÓN 1: Calcular total de hospedaje
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_hospedaje(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    precio NUMERIC;
    noches INT;
BEGIN
    SELECT 
        th.precio_noche,
        (r.fecha_fin - r.fecha_inicio)
    INTO precio, noches
    FROM reservacion r
    INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
    INNER JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo
    WHERE r.id_reservacion = p_id_reservacion;

    RETURN precio * noches;
END;
$$ LANGUAGE plpgsql;


-- ==========================================================
-- FUNCIÓN 2: Calcular total de servicios consumidos
-- ==========================================================
CREATE OR REPLACE FUNCTION calcular_total_servicios(p_id_reservacion BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    total NUMERIC;
BEGIN
    SELECT 
        COALESCE(SUM(cs.cantidad * s.costo_unitario), 0)
    INTO total
    FROM consumo_servicio cs
    INNER JOIN servicio s ON cs.id_servicio = s.id_servicio
    WHERE cs.id_reservacion = p_id_reservacion;

    RETURN total;
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
    subtotal NUMERIC;
    impuestos NUMERIC;
    total NUMERIC;
BEGIN
    subtotal := calcular_total_final(p_id_reservacion);
    impuestos := subtotal * 0.13;
    total := subtotal + impuestos;

    INSERT INTO factura (numero_factura, fecha_emision, subtotal, impuestos, total_final, id_reservacion, id_empleado)
    VALUES (
        (SELECT COALESCE(MAX(numero_factura),0) + 1 FROM factura),
        NOW(),
        subtotal,
        impuestos,
        total,
        p_id_reservacion,
        p_id_empleado
    );
END;
$$;


-- ==========================================================
-- PROCEDIMIENTO: Agregar detalle de factura
-- ==========================================================
CREATE OR REPLACE PROCEDURE agregar_detalle_factura(p_id_factura BIGINT, p_id_servicio BIGINT, p_cantidad INT)
LANGUAGE plpgsql
AS $$
DECLARE
    precio NUMERIC;
BEGIN
    SELECT costo_unitario INTO precio
    FROM servicio
    WHERE id_servicio = p_id_servicio;

    INSERT INTO detalles_factura (id_factura, id_servicio, cantidad, precio)
    VALUES (p_id_factura, p_id_servicio, p_cantidad, precio);
END;
$$;


-- ==========================================================
-- TRIGGER 1: Validar fechas de check-in/out
-- ==========================================================
CREATE OR REPLACE FUNCTION validar_fechas_checkin()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_salida IS NOT NULL 
       AND NEW.fecha_salida <= NEW.fecha_entrada THEN
        RAISE EXCEPTION 'La fecha de salida debe ser mayor que la fecha de entrada';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    UPDATE habitacion
    SET estado = 'Ocupada'
    WHERE id_habitacion = NEW.id_habitacion;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    IF NEW.estado_reserva = 'Finalizada' THEN
        UPDATE habitacion
        SET estado = 'Disponible'
        WHERE id_habitacion = NEW.id_habitacion;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_liberar_habitacion
AFTER UPDATE ON reservacion
FOR EACH ROW
EXECUTE FUNCTION liberar_habitacion();
