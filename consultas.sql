-- .........................................................
--           SISTEMA DE RESERVAS DE HOTEL
-- ..........................................................

-- ==========================================
--                CONSULTAS
-- ==========================================

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
WHERE estado = 'Disponible'
ORDER BY id_hotel, numero;

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
INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
ORDER BY r.fecha_inicio DESC;

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
INNER JOIN tipo_habitacion th ON ha.id_tipo = th.id_tipo
ORDER BY total_habitacion DESC;

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
INNER JOIN reservacion r  ON cs.id_reservacion = r.id_reservacion
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
INNER JOIN servicio s  ON cs.id_servicio = s.id_servicio
ORDER BY r.id_reservacion, total_servicio DESC;

-- 7. Total gastado por cada huésped 
SELECT
    hu.id_huesped,
    hu.nombre,
    hu.apellido,
    COALESCE(SUM((r.fecha_fin - r.fecha_inicio) * th.precio_noche), 0)
        + COALESCE(SUM(cs.cantidad * s.costo_unitario), 0) AS total_gastado
FROM huesped hu
LEFT JOIN reservacion r  ON hu.id_huesped = r.id_huesped
LEFT JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
LEFT JOIN tipo_habitacion  th ON ha.id_tipo = th.id_tipo
LEFT JOIN consumo_servicio cs ON r.id_reservacion = cs.id_reservacion
LEFT JOIN servicio s  ON cs.id_servicio = s.id_servicio
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
LEFT JOIN habitacion  ha ON ho.id_hotel = ha.id_hotel
LEFT JOIN reservacion r  ON ha.id_habitacion = r.id_habitacion
GROUP BY ho.nombre
ORDER BY total_reservaciones DESC;

-- 10. Tasa de ocupación por tipo de habitación
SELECT
    th.descripcion AS tipo_habitacion,
    COUNT(r.id_reservacion) AS total_reservaciones
FROM tipo_habitacion th
LEFT JOIN habitacion  ha ON th.id_tipo = ha.id_tipo
LEFT JOIN reservacion r  ON ha.id_habitacion = r.id_habitacion
GROUP BY th.descripcion
ORDER BY total_reservaciones DESC;

-- 11. Habitaciones disponibles en un rango de fechas dado
SELECT
    ha.id_habitacion,
    ha.numero,
    ha.piso,
    th.descripcion  AS tipo,
    th.precio_noche,
    ho.nombre AS hotel
FROM habitacion ha
INNER JOIN tipo_habitacion th ON ha.id_tipo  = th.id_tipo
INNER JOIN hotel ho ON ha.id_hotel = ho.id_hotel
WHERE ha.estado = 'Disponible'
  AND ha.id_habitacion NOT IN (
      SELECT id_habitacion
      FROM reservacion
      WHERE estado_reserva != 'Cancelada'
        AND (fecha_inicio, fecha_fin) OVERLAPS ('2026-07-01'::DATE, '2026-07-05'::DATE)
  )
ORDER BY ho.nombre, th.precio_noche;

-- 12. Detalle de cada factura
SELECT
    f.id_factura,
    s.nombre_servicio,
    d.cantidad,
    d.precio,
    (d.cantidad * d.precio) AS total
FROM detalles_factura d
INNER JOIN factura  f ON d.id_factura  = f.id_factura
INNER JOIN servicio s ON d.id_servicio = s.id_servicio
ORDER BY f.id_factura;

-- 13. Total por factura (hospedaje + servicios)
SELECT
    f.id_factura,
    hu.nombre,
    hu.apellido,
    calcular_total_final(f.id_reservacion) AS total_hospedaje,
    COALESCE(SUM(d.cantidad * d.precio), 0) AS total_servicios,
    calcular_total_final(f.id_reservacion)
        + COALESCE(SUM(d.cantidad * d.precio), 0) AS total_final
FROM factura f
INNER JOIN reservacion r  ON f.id_reservacion = r.id_reservacion
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
LEFT  JOIN detalles_factura d  ON f.id_factura = d.id_factura
GROUP BY f.id_factura, hu.nombre, hu.apellido, f.id_reservacion
ORDER BY total_final DESC;

-- 14. Reservaciones activas con detalles completos
SELECT
    r.id_reservacion,
    hu.nombre,
    hu.apellido,
    ha.numero AS habitacion,
    r.fecha_inicio,
    r.fecha_fin
FROM reservacion r
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
WHERE r.estado_reserva = 'Activa'
ORDER BY r.fecha_inicio;

-- 15. Top 5 huéspedes con mayor gasto
SELECT
    hu.id_huesped,
    hu.nombre,
    hu.apellido,
    COALESCE(SUM((r.fecha_fin - r.fecha_inicio) * th.precio_noche), 0)
        + COALESCE(SUM(cs.cantidad * s.costo_unitario), 0)   AS total_gastado
FROM huesped hu
LEFT JOIN reservacion r  ON hu.id_huesped = r.id_huesped
LEFT JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
LEFT JOIN tipo_habitacion  th ON ha.id_tipo = th.id_tipo
LEFT JOIN consumo_servicio cs ON r.id_reservacion = cs.id_reservacion
LEFT JOIN servicio s  ON cs.id_servicio = s.id_servicio
GROUP BY hu.id_huesped, hu.nombre, hu.apellido
ORDER BY total_gastado DESC
LIMIT 5;

-- 16. Ingresos totales por hotel
SELECT
    ho.nombre AS hotel,
    COUNT(f.id_factura) AS total_facturas,
    SUM(f.total_final) AS ingresos_totales
FROM hotel ho
INNER JOIN habitacion ha ON ho.id_hotel = ha.id_hotel
INNER JOIN reservacion r ON ha.id_habitacion = r.id_habitacion
INNER JOIN factura f ON r.id_reservacion = f.id_reservacion
GROUP BY ho.nombre
ORDER BY ingresos_totales DESC;

-- 17. Habitaciones más reservadas (Top 10)
SELECT
    ha.id_habitacion,
    ha.numero,
    ho.nombre AS hotel,
    COUNT(r.id_reservacion) AS veces_reservada
FROM habitacion ha
INNER JOIN hotel ho ON ha.id_hotel = ho.id_hotel
LEFT JOIN reservacion r ON ha.id_habitacion = r.id_habitacion
GROUP BY ha.id_habitacion, ha.numero, ho.nombre
ORDER BY veces_reservada DESC
LIMIT 10;

-- 18. Servicios más rentables
SELECT
    s.nombre_servicio,
    SUM(cs.cantidad) AS total_unidades_vendidas,
    SUM(cs.cantidad * s.costo_unitario) AS ingresos_totales
FROM servicio s
INNER JOIN consumo_servicio cs ON s.id_servicio = cs.id_servicio
GROUP BY s.nombre_servicio
ORDER BY ingresos_totales DESC;

-- 19. Check-ins y check-outs programados para hoy
SELECT
    r.id_reservacion,
    hu.nombre,
    hu.apellido,
    ha.numero AS habitacion,
    c.fecha_entrada,
    c.fecha_salida,
    CASE 
        WHEN DATE(c.fecha_entrada) = CURRENT_DATE THEN 'Check-in Hoy'
        WHEN DATE(c.fecha_salida) = CURRENT_DATE THEN 'Check-out Hoy'
    END AS tipo_evento
FROM check_in_out c
INNER JOIN reservacion r ON c.id_reservacion = r.id_reservacion
INNER JOIN huesped hu ON r.id_huesped = hu.id_huesped
INNER JOIN habitacion ha ON r.id_habitacion = ha.id_habitacion
WHERE DATE(c.fecha_entrada) = CURRENT_DATE
   OR DATE(c.fecha_salida) = CURRENT_DATE;

-- 20. Estadísticas generales del sistema
SELECT
    (SELECT COUNT(*) FROM hotel) AS total_hoteles,
    (SELECT COUNT(*) FROM habitacion) AS total_habitaciones,
    (SELECT COUNT(*) FROM huesped) AS total_huespedes,
    (SELECT COUNT(*) FROM reservacion) AS total_reservaciones,
    (SELECT COUNT(*) FROM reservacion WHERE estado_reserva = 'Activa') AS reservas_activas,
    (SELECT COUNT(*) FROM factura) AS total_facturas,
    (SELECT SUM(total_final) FROM factura) AS ingresos_totales;
