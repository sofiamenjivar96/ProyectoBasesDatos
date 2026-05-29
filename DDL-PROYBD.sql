
--......................................................
--               SISTEMA DE RESERVAS DE HOTEL
-- Script DDL: Creación de tablas y restricciones
-- .....................................................

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE hotel (
id_hotel SERIAL PRIMARY KEY,
nombre VARCHAR(100) NOT NULL,
direccion TEXT NOT NULL,
telefono VARCHAR(20)
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE tipo_habitacion (
id_tipo SERIAL PRIMARY KEY,
descripcion TEXT,
precio_noche NUMERIC(10,2) NOT NULL
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE habitacion (
id_habitacion SERIAL PRIMARY KEY,
numero VARCHAR(10) NOT NULL,
piso INT,    
estado VARCHAR(20) NOT NULL, -- Disponible, Ocupada, Mantenimiento
id_tipo INT NOT NULL,
id_hotel INT NOT NULL,
CONSTRAINT fk_habitacion_tipo FOREIGN KEY (id_tipo) REFERENCES tipo_habitacion(id_tipo),
CONSTRAINT fk_habitacion_hotel FOREIGN KEY (id_hotel) REFERENCES hotel(id_hotel),
CONSTRAINT uq_habitacion UNIQUE (id_hotel, numero) 
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE huesped (
id_huesped SERIAL PRIMARY KEY,
dui_pasaporte VARCHAR(30) NOT NULL,
nombre VARCHAR(100) NOT NULL,
apellido VARCHAR(100) NOT NULL,
email VARCHAR(100),
telefono VARCHAR(20),
CONSTRAINT uq_huesped_dui UNIQUE (dui_pasaporte) 
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE reservacion (
id_reservacion SERIAL PRIMARY KEY,
fecha_reserva DATE NOT NULL,
fecha_inicio DATE NOT NULL,
fecha_fin DATE NOT NULL,
estado_reserva VARCHAR(20) NOT NULL, -- Activa, Cancelada, Finalizada
id_huesped INT NOT NULL,
id_habitacion INT NOT NULL,
CONSTRAINT fk_reservacion_huesped FOREIGN KEY (id_huesped) REFERENCES huesped(id_huesped),
CONSTRAINT fk_reservacion_habitacion FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion),
CONSTRAINT ck_fechas_reserva CHECK (fecha_fin > fecha_inicio)
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE check_in_out (
id_registro SERIAL PRIMARY KEY,
fecha_entrada TIMESTAMP,
fecha_salida TIMESTAMP,
id_reservacion INT NOT NULL,
CONSTRAINT fk_check_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE servicio (
id_servicio SERIAL PRIMARY KEY,
nombre_servicio VARCHAR(100) NOT NULL,
costo_unitario NUMERIC(10,2) NOT NULL
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE consumo_servicio (
id_consumo SERIAL PRIMARY KEY,
cantidad INT NOT NULL,
fecha_consumo TIMESTAMP NOT NULL,
id_reservacion INT NOT NULL,
id_servicio INT NOT NULL,
CONSTRAINT fk_consumo_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion),
CONSTRAINT fk_consumo_servicio FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio)
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE empleado (
id_empleado SERIAL PRIMARY KEY,
dui VARCHAR(30) NOT NULL,
nombre VARCHAR(100) NOT NULL,
apellido VARCHAR(100) NOT NULL,
cargo VARCHAR(50) NOT NULL,
CONSTRAINT uq_empleado_dui UNIQUE (dui) 
);

-- ==========================================
--               TABLA: Hotel
-- ==========================================
CREATE TABLE factura (
id_factura SERIAL PRIMARY KEY,
numero_factura INT NOT NULL,
fecha_emision TIMESTAMP NOT NULL,
subtotal NUMERIC(10,2) NOT NULL,
impuestos NUMERIC(10,2) NOT NULL,
total_final NUMERIC(10,2) NOT NULL,
id_reservacion INT NOT NULL,
id_empleado INT NOT NULL,
CONSTRAINT fk_factura_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion),
CONSTRAINT fk_factura_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado),
CONSTRAINT uq_numero_factura UNIQUE (numero_factura) 
);
