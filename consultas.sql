-- ==========================================================
--      CONSULTAS SQL – SISTEMA DE RESERVAS DE HOTEL
-- ==========================================================


SELECT * FROM hotel; --Mostrar todos los hoteles

SELECT -- Mostrar habitaciones disponibles
    id_habitacion,
    numero,
    piso,
    estado,
    id_hotel
FROM habitacion
WHERE estado = 'Disponible';


SELECT --  Mostrar reservaciones con datos del huésped y habitación
    r.id_reservacion,
    h.nombre AS nombre_huesped,
    h.apellido AS apellido_huesped,
    ha.numero AS numero_habitacion,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado_reserva
FROM reservacion r
INNER JOIN huesped h 
    ON r.id_huesped = h.id_huesped
INNER JOIN habitacion ha 
    ON r.id_habitacion = ha.id_habitacion;


SELECT -- Mostrar cuántas habitaciones tiene cada hotel
    ho.nombre AS hotel,
    COUNT(ha.id_habitacion) AS total_habitaciones
FROM hotel ho
INNER JOIN habitacion ha 
    ON ho.id_hotel = ha.id_hotel
GROUP BY ho.nombre
ORDER BY total_habitaciones DESC;


SELECT -- Mostrar total a pagar por hospedaje según noches
    r.id_reservacion,
    hu.nombre AS nombre_huesped,
    hu.apellido AS apellido_huesped,
    th.descripcion AS tipo_habitacion,
    th.precio_noche,
    r.fecha_inicio,
    r.fecha_fin,
    (r.fecha_fin - r.fecha_inicio) AS noches,
    (r.fecha_fin - r.fecha_inicio) * th.precio_noche AS total_habitacion
FROM reservacion r
INNER JOIN huesped hu 
    ON r.id_huesped = hu.id_huesped
INNER JOIN habitacion ha 
    ON r.id_habitacion = ha.id_habitacion
INNER JOIN tipo_habitacion th 
    ON ha.id_tipo = th.id_tipo;


SELECT -- Mostrar consumos de servicios por reservación
    r.id_reservacion,
    hu.nombre,
    hu.apellido,
    s.nombre_servicio,
    cs.cantidad,
    s.costo_unitario,
    (cs.cantidad * s.costo_unitario) AS total_servicio
FROM consumo_servicio cs
INNER JOIN reservacion r 
    ON cs.id_reservacion = r.id_reservacion
INNER JOIN huesped hu 
    ON r.id_huesped = hu.id_huesped
INNER JOIN servicio s 
    ON cs.id_servicio = s.id_servicio;


SELECT -- Mostrar total gastado por cada huésped (hospedaje + servicios)
    hu.id_huesped,
    hu.nombre,
    hu.apellido,
    COALESCE(SUM((r.fecha_fin - r.fecha_inicio) * th.precio_noche),0) 
        + COALESCE(SUM(cs.cantidad * s.costo_unitario),0) AS total_gastado
FROM huesped hu
LEFT JOIN reservacion r 
    ON hu.id_huesped = r.id_huesped
LEFT JOIN habitacion ha 
    ON r.id_habitacion = ha.id_habitacion
LEFT JOIN tipo_habitacion th 
    ON ha.id_tipo = th.id_tipo
LEFT JOIN consumo_servicio cs 
    ON r.id_reservacion = cs.id_reservacion
LEFT JOIN servicio s 
    ON cs.id_servicio = s.id_servicio
GROUP BY hu.id_huesped, hu.nombre, hu.apellido
ORDER BY total_gastado DESC;


SELECT -- Servicios más consumidos
    s.nombre_servicio,
    COUNT(cs.id_consumo) AS veces_consumido,
    SUM(cs.cantidad) AS total_cantidad
FROM servicio s
LEFT JOIN consumo_servicio cs 
    ON s.id_servicio = cs.id_servicio
GROUP BY s.nombre_servicio
ORDER BY total_cantidad DESC;


SELECT --  Tasa de ocupación por hotel
    ho.nombre AS hotel,
    COUNT(r.id_reservacion) AS total_reservaciones
FROM hotel ho
LEFT JOIN habitacion ha 
    ON ho.id_hotel = ha.id_hotel
LEFT JOIN reservacion r 
    ON ha.id_habitacion = r.id_habitacion
GROUP BY ho.nombre
ORDER BY total_reservaciones DESC;


SELECT * --  Reservaciones activas actualmente
FROM reservacion
WHERE estado_reserva = 'Activa';
