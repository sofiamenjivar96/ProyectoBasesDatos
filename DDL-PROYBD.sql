--......................................................
--          SISTEMA DE RESERVAS DE HOTEL
-- Script DDL: Creación de tablas y restricciones
-- .....................................................

-- ==========================================
--             ELIMINAR TABLAS
-- ==========================================

DROP TABLE IF EXISTS factura CASCADE;
DROP TABLE IF EXISTS consumo_servicio CASCADE;
DROP TABLE IF EXISTS check_in_out CASCADE;
DROP TABLE IF EXISTS reservacion CASCADE;
DROP TABLE IF EXISTS empleado CASCADE;
DROP TABLE IF EXISTS servicio CASCADE;
DROP TABLE IF EXISTS huesped CASCADE;
DROP TABLE IF EXISTS habitacion CASCADE;
DROP TABLE IF EXISTS tipo_habitacion CASCADE;
DROP TABLE IF EXISTS hotel CASCADE;

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
--          TABLA: tipo_habitacion
-- ==========================================
CREATE TABLE tipo_habitacion (
    id_tipo SERIAL PRIMARY KEY,
    descripcion TEXT,
    precio_noche NUMERIC(10,2) NOT NULL,
    CONSTRAINT ck_precio_habitacion CHECK (precio_noche > 0)
);

-- ==========================================
--            TABLA: Habitacion
-- ==========================================
CREATE TABLE habitacion (
    id_habitacion SERIAL PRIMARY KEY,
    numero  VARCHAR(10) NOT NULL,
    piso INT,
    estado VARCHAR(20) NOT NULL DEFAULT 'Disponible',
    id_tipoINT NOT NULL,
    id_hotel INT NOT NULL,
    CONSTRAINT fk_habitacion_tipo FOREIGN KEY (id_tipo) REFERENCES tipo_habitacion(id_tipo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_habitacion_hotel FOREIGN KEY (id_hotel) REFERENCES hotel(id_hotel)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_estado_habitacion CHECK (estado IN ('Disponible', 'Ocupada', 'Mantenimiento')),
    CONSTRAINT uq_habitacion UNIQUE (id_hotel, numero)
);

-- ==========================================
--              TABLA: huesped
-- ==========================================
CREATE TABLE huesped (
    id_huesped SERIAL PRIMARY KEY,
    dui_pasaporte VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    telefono VARCHAR(20)
);

ALTER TABLE huesped
ADD CONSTRAINT uq_huesped_dui UNIQUE (dui_pasaporte);

-- ==========================================
--            TABLA: reservacion
-- ==========================================
CREATE TABLE reservacion (
    id_reservacion SERIAL PRIMARY KEY,
    fecha_reserva DATE NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado_reserva VARCHAR(20) NOT NULL DEFAULT 'Activa',
    id_huesped INT NOT NULL,
    id_habitacion INT NOT NULL,
    CONSTRAINT fk_reservacion_huesped FOREIGN KEY (id_huesped) REFERENCES huesped(id_huesped)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reservacion_habitacion FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_estado_reserva CHECK (estado_reserva IN ('Activa', 'Cancelada', 'Finalizada')),
    CONSTRAINT ck_fechas_reserva CHECK (fecha_fin > fecha_inicio)
);

-- ==========================================
--            TABLA: check_in_out
-- ==========================================
CREATE TABLE check_in_out (
    id_registro SERIAL PRIMARY KEY,
    fecha_entrada TIMESTAMP,
    fecha_salida TIMESTAMP,
    id_reservacion INT NOT NULL,
    CONSTRAINT fk_check_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
        ON UPDATE CASCADE ON DELETE CASCADE
);

ALTER TABLE check_in_out
ADD CONSTRAINT ck_fechas_checkin
CHECK (fecha_salida IS NULL OR fecha_salida > fecha_entrada);

-- ==========================================
--             TABLA: servicio
-- ==========================================
CREATE TABLE servicio (
    id_servicio SERIAL PRIMARY KEY,
    nombre_servicio VARCHAR(100) NOT NULL,
    costo_unitario NUMERIC(10,2) NOT NULL
);

ALTER TABLE servicio
ADD CONSTRAINT ck_costo_servicio CHECK (costo_unitario >= 0);

-- ==========================================
--          TABLA: consumo_servicio
-- ==========================================
CREATE TABLE consumo_servicio (
    id_consumo SERIAL PRIMARY KEY,
    cantidad INT NOT NULL,
    fecha_consumo TIMESTAMP NOT NULL,
    id_reservacion INT NOT NULL,
    id_servicio INT NOT NULL,
    CONSTRAINT fk_consumo_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_consumo_servicio FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

ALTER TABLE consumo_servicio
ADD CONSTRAINT ck_cantidad_consumo CHECK (cantidad > 0);

-- ==========================================
--             TABLA: empleado
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
--             TABLA: factura
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
    CONSTRAINT fk_factura_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_factura_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_factura_reservacion UNIQUE (id_reservacion)
);

ALTER TABLE factura
ADD CONSTRAINT ck_factura_valores
CHECK (subtotal >= 0 AND impuestos >= 0 AND total_final >= 0);