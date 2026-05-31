INSERT INTO hotel (nombre, direccion, telefono) VALUES
('Hotel Paradise', 'San Salvador Centro', '2222-1111'),
('Hotel Costa Azul', 'La Libertad', '2222-2222'),
('Hotel Montaña Verde', 'Santa Ana', '2222-3333'),
('Hotel Las Palmeras', 'Sonsonate', '2222-4444'),
('Hotel Ejecutivo', 'San Miguel', '2222-5555'),
('Hotel Vista Hermosa', 'Ahuachapan', '2222-6666'),
('Hotel El Descanso', 'Usulutan', '2222-7777');

INSERT INTO tipo_habitacion (descripcion, precio_noche) VALUES
('Individual', 45.00),
('Doble', 75.00),
('Suite', 150.00),
('Familiar', 120.00),
('Ejecutiva', 95.00),
('Premium', 180.00),
('Presidencial', 300.00);

INSERT INTO huesped
(dui_pasaporte, nombre, apellido, email, telefono)
VALUES
('01234567-8','Carlos','Martinez','carlos@gmail.com','7000-1111'),
('02345678-9','Ana','Lopez','ana@gmail.com','7000-2222'),
('03456789-0','Jose','Ramirez','jose@gmail.com','7000-3333'),
('04567890-1','Maria','Hernandez','maria@gmail.com','7000-4444'),
('05678901-2','Luis','Garcia','luis@gmail.com','7000-5555'),
('06789012-3','Sofia','Castro','sofia@gmail.com','7000-6666'),
('07890123-4','Miguel','Ruiz','miguel@gmail.com','7000-7777');

INSERT INTO habitacion
(numero,piso,estado,id_tipo,id_hotel)
VALUES
('101',1,'Disponible',1,1),
('201',2,'Disponible',2,1),

('101',1,'Ocupada',2,2),
('201',2,'Disponible',3,2),

('101',1,'Disponible',4,3),
('201',2,'Mantenimiento',5,3),

('101',1,'Disponible',6,4),
('201',2,'Disponible',7,4),

('101',1,'Ocupada',1,5),
('201',2,'Disponible',3,5),

('101',1,'Disponible',2,6),
('201',2,'Disponible',4,6),

('101',1,'Disponible',5,7),
('201',2,'Disponible',6,7);

INSERT INTO reservacion
(fecha_reserva,fecha_inicio,fecha_fin,estado_reserva,id_huesped,id_habitacion)
VALUES
('2026-05-01','2026-06-01','2026-06-05','Activa',1,1),
('2026-05-02','2026-06-06','2026-06-10','Finalizada',2,3),
('2026-05-03','2026-06-08','2026-06-12','Activa',3,5),
('2026-05-04','2026-06-10','2026-06-14','Cancelada',4,7),
('2026-05-05','2026-06-15','2026-06-18','Finalizada',5,9),
('2026-05-06','2026-06-20','2026-06-25','Activa',6,11),
('2026-05-07','2026-06-22','2026-06-27','Finalizada',7,13);

INSERT INTO check_in_out
(fecha_entrada,fecha_salida,id_reservacion)
VALUES
('2026-06-01 14:00:00',NULL,1),
('2026-06-06 13:00:00','2026-06-10 12:00:00',2),
('2026-06-08 15:00:00',NULL,3),
('2026-06-10 14:30:00',NULL,4),
('2026-06-15 13:00:00','2026-06-18 11:00:00',5),
('2026-06-20 14:00:00',NULL,6),
('2026-06-22 15:00:00','2026-06-27 12:00:00',7);

INSERT INTO servicio
(nombre_servicio,costo_unitario)
VALUES
('Restaurante',15.00),
('Lavanderia',8.00),
('Spa',30.00),
('Transporte',20.00),
('Minibar',10.00),
('Gimnasio',12.00),
('Tour Turistico',40.00);


INSERT INTO consumo_servicio
(cantidad,fecha_consumo,id_reservacion,id_servicio)
VALUES
(2,'2026-06-02 08:00:00',1,1),
(1,'2026-06-07 10:00:00',2,2),
(3,'2026-06-09 18:00:00',3,5),
(2,'2026-06-11 11:00:00',4,4),
(1,'2026-06-16 15:00:00',5,3),
(4,'2026-06-21 20:00:00',6,1),
(2,'2026-06-23 09:00:00',7,7);