-- ==========================================================
--      CONSULTAS SQL – SISTEMA DE RESERVAS DE HOTEL
-- ==========================================================

-- 1. Mostrar todos los hoteles
SELECT * FROM hotel;

-- 2. Mostrar habitaciones disponibles
SELECT 
    id_habitacion,
    numero,
    piso,
    estado,
    id_hotel
FROM habitacion
WHERE estado = 'Disponible';

-- 3. Mostrar reservaciones con datos del huésped y habitación
SELECT 
    r.id_reservacion,
    h.nombre AS nombre_huesped,
    h.apellido AS apellido_huesped,
    ha.numero AS numero_habitacion,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado_reserva
FROM reservacion r
INNER JOIN huesped h ON r.id_huesped = h.id_huesped
INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion;

-- 4. Mostrar cuántas habitaciones tiene cada hotel
SELECT 
    ho.nombre AS hotel,
    COUNT(ha.id_habitacion) AS total_habitaciones
FROM hotel ho
INNER JOIN habitacion ha ON ho.id_hotel = ha.id_hotel
GROUP BY ho.nombre
ORDER BY total_habitaciones DESC;

-- 5. Mostrar total a pagar por hospedaje según noches
SELECT 
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
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
INNER JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo;

-- 6. Mostrar consumos de servicios por reservación
SELECT 
    r.id_reservacion,
    hu.nombre,
    hu.apellido,
    s.nombre_servicio,
    cs.cantidad,
    s.costo_unitario,
    (cs.cantidad * s.costo_unitario) AS total_servicio
FROM consumo_servicio cs
INNER JOIN reservacion r ON cs.id_reservacion = r.id_reservacion
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
INNER JOIN servicio s ON cs.id_servicio = s.id_servicio;

-- 7. Mostrar total gastado por cada huésped (hospedaje + servicios)
SELECT 
    hu.id_huesped,
    hu.nombre,
    hu.apellido,
    COALESCE(SUM((r.fecha_fin - r.fecha_inicio) * th.precio_noche),0) 
        + COALESCE(SUM(cs.cantidad * s.costo_unitario),0) AS total_gastado
FROM huesped hu
LEFT JOIN reservacion r ON hu.id_huesped = r.id_huesped
LEFT JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
LEFT JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo
LEFT JOIN consumo_servicio cs ON r.id_reservacion = cs.id_reservacion
LEFT JOIN servicio s ON cs.id_servicio = s.id_servicio
GROUP BY hu.id_huesped, hu.nombre, hu.apellido
ORDER BY total_gastado DESC;

-- 8. Servicios más consumidos
SELECT 
    s.nombre_servicio,
    COUNT(cs.id_consumo) AS veces_consumido,
    SUM(cs.cantidad) AS total_cantidad
FROM servicio s
LEFT JOIN consumo_servicio cs ON s.id_servicio = cs.id_servicio
GROUP BY s.nombre_servicio
ORDER BY total_cantidad DESC;

-- 9. Tasa de ocupación por hotel
SELECT 
    ho.nombre AS hotel,
    COUNT(r.id_reservacion) AS total_reservaciones
FROM hotel ho
LEFT JOIN habitacion ha ON ho.id_hotel = ha.id_hotel
LEFT JOIN reservacion r ON ha.id_habitacion = r.id_habitacion
GROUP BY ho.nombre
ORDER BY total_reservaciones DESC;

-- 10. Mostrar detalle de cada factura
SELECT 
    f.id_factura, 
    s.nombre_servicio, 
    d.cantidad, 
    d.precio, 
    (d.cantidad * d.precio) AS total
FROM detalles_factura d
INNER JOIN factura f ON d.id_factura = f.id_factura
INNER JOIN servicio s ON d.id_servicio = s.id_servicio;

-- 11. Total por factura (hospedaje + servicios)
SELECT 
    f.id_factura, 
    hu.nombre, 
    hu.apellido,
    calcular_total_final(f.id_reservacion) AS total_hospedaje,
    SUM(d.cantidad * d.precio) AS total_servicios,
    calcular_total_final(f.id_reservacion) + SUM(d.cantidad * d.precio) AS total_final
FROM factura f
INNER JOIN reservacion r ON f.id_reservacion = r.id_reservacion
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
LEFT JOIN detalles_factura d ON f.id_factura = d.id_factura
GROUP BY f.id_factura, hu.nombre, hu.apellido, f.id_reservacion;

-- 12. Reservaciones activas actualmente
SELECT *
FROM reservacion
WHERE estado_reserva = 'Activa';

