--......................................................
--          SISTEMA DE RESERVAS DE HOTEL
-- .....................................................

-- Este script define la estructura de la base de datos del sistema de reservas de hotel.
-- Incluye tablas, relaciones, restricciones e índices para garantizar integridad y buen rendimiento.

-- ==========================================
--             ELIMINAR TABLAS
-- ==========================================
-- Se eliminan primero las tablas dependientes para evitar conflictos por llaves foráneas.
DROP TABLE IF EXISTS detalles_factura CASCADE;
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
-- Almacena la información general de cada hotel.
CREATE TABLE hotel (
    id_hotel BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion TEXT NOT NULL,
    telefono VARCHAR(20)
);

-- ==========================================
--          TABLA: tipo_habitacion
-- ==========================================
-- Define los tipos de habitación disponibles y su precio por noche.
CREATE TABLE tipo_habitacion (
    id_tipo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descripcion TEXT,
    precio_noche NUMERIC(10,2) NOT NULL,
    -- El precio por noche siempre debe ser mayor que cero.
    CONSTRAINT ck_precio_habitacion CHECK (precio_noche > 0)
);

-- ==========================================
--            TABLA: Habitacion
-- ==========================================
-- Registra las habitaciones de cada hotel.
CREATE TABLE habitacion (
    id_habitacion BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero VARCHAR(10) NOT NULL,
    piso INT,
    estado VARCHAR(20) NOT NULL DEFAULT 'Disponible',
    id_tipo BIGINT NOT NULL,
    id_hotel BIGINT NOT NULL,
    CONSTRAINT fk_habitacion_tipo FOREIGN KEY (id_tipo) REFERENCES tipo_habitacion(id_tipo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_habitacion_hotel FOREIGN KEY (id_hotel) REFERENCES hotel(id_hotel)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- Estados permitidos para cada habitación.
    CONSTRAINT ck_estado_habitacion CHECK (estado IN ('Disponible', 'Ocupada', 'Mantenimiento')),
    -- Evita habitaciones duplicadas dentro del mismo hotel.
    CONSTRAINT uq_habitacion UNIQUE (id_hotel, numero)
);

-- ==========================================
--              TABLA: huesped
-- ==========================================
-- Guarda la información de cada huésped.
CREATE TABLE huesped (
    id_huesped BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dui_pasaporte VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    telefono VARCHAR(20),
    CONSTRAINT uq_huesped_dui UNIQUE (dui_pasaporte),
    -- Valida el formato básico del correo electrónico.
    CONSTRAINT ck_email_huesped CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ==========================================
--            TABLA: reservacion
-- ==========================================
-- Registra las reservaciones realizadas por los huéspedes.
CREATE TABLE reservacion (
    id_reservacion BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_reserva DATE NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado_reserva VARCHAR(20) NOT NULL DEFAULT 'Activa',
    id_huesped BIGINT NOT NULL,
    id_habitacion BIGINT NOT NULL,
    CONSTRAINT fk_reservacion_huesped FOREIGN KEY (id_huesped) REFERENCES huesped(id_huesped)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reservacion_habitacion FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_estado_reserva CHECK (estado_reserva IN ('Activa', 'Cancelada', 'Finalizada')),
    -- La fecha final debe ser posterior a la fecha inicial.
    CONSTRAINT ck_fechas_reserva CHECK (fecha_fin > fecha_inicio)
);

-- ==========================================
--            TABLA: check_in_out
-- ==========================================
-- Lleva el control del ingreso y salida real del huésped.
CREATE TABLE check_in_out (
    id_registro BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_entrada TIMESTAMP,
    fecha_salida TIMESTAMP,
    id_reservacion BIGINT NOT NULL,
    CONSTRAINT fk_check_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    -- Si existe fecha de salida, debe ser posterior a la fecha de entrada.
    CONSTRAINT ck_fechas_checkin CHECK (fecha_salida IS NULL OR fecha_salida > fecha_entrada)
);

-- ==========================================
--             TABLA: servicio
-- ==========================================
-- Catálogo de servicios adicionales ofrecidos por el hotel.
CREATE TABLE servicio (
    id_servicio BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_servicio VARCHAR(100) NOT NULL,
    costo_unitario NUMERIC(10,2) NOT NULL,
    -- El costo del servicio no puede ser negativo.
    CONSTRAINT ck_costo_servicio CHECK (costo_unitario >= 0)
);

-- ==========================================
--          TABLA: consumo_servicio
-- ==========================================
-- Registra los servicios consumidos durante una reservación.
CREATE TABLE consumo_servicio (
    id_consumo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cantidad INT NOT NULL,
    fecha_consumo TIMESTAMP NOT NULL,
    id_reservacion BIGINT NOT NULL,
    id_servicio BIGINT NOT NULL,
    CONSTRAINT fk_consumo_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_consumo_servicio FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- La cantidad consumida siempre debe ser mayor a cero.
    CONSTRAINT ck_cantidad_consumo CHECK (cantidad > 0)
);

-- ==========================================
--             TABLA: empleado
-- ==========================================
-- Almacena la información del personal autorizado del hotel.
CREATE TABLE empleado (
    id_empleado BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dui VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    cargo VARCHAR(50) NOT NULL,
    CONSTRAINT uq_empleado_dui UNIQUE (dui)
);

-- ==========================================
--             TABLA: factura
-- ==========================================
-- Registra la factura final generada por cada reservación.
CREATE TABLE factura (
    id_factura BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_factura INT NOT NULL,
    fecha_emision TIMESTAMP NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL,
    impuestos NUMERIC(10,2) NOT NULL,
    total_final NUMERIC(10,2) NOT NULL,
    id_reservacion BIGINT NOT NULL,
    id_empleado BIGINT NOT NULL,
    CONSTRAINT fk_factura_reservacion FOREIGN KEY (id_reservacion) REFERENCES reservacion(id_reservacion)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_factura_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- Una reservación solo puede generar una factura.
    CONSTRAINT uq_factura_reservacion UNIQUE (id_reservacion),
    CONSTRAINT uq_numero_factura UNIQUE (numero_factura),
    -- Garantiza coherencia entre subtotal, impuestos y total final.
    CONSTRAINT ck_factura_valores CHECK (
        subtotal >= 0
        AND impuestos >= 0
        AND total_final = subtotal + impuestos
    )
);

-- ==========================================
--         TABLA: Detalles de factura
-- ==========================================
-- Guarda el detalle de servicios cobrados en cada factura.
CREATE TABLE detalles_factura (
    id_detalle BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_factura BIGINT NOT NULL,
    id_servicio BIGINT NOT NULL,
    cantidad INT NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    CONSTRAINT fk_detalle_factura FOREIGN KEY (id_factura) REFERENCES factura(id_factura)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_detalle_servicio FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_cantidad_detalle CHECK (cantidad > 0),
    CONSTRAINT ck_precio_detalle CHECK (precio >= 0)
);

-- ==========================================
--                  ÍNDICES
-- ==========================================
-- Índices para optimizar búsquedas, joins y consultas frecuentes.
CREATE INDEX idx_habitacion_hotel ON habitacion(id_hotel);
CREATE INDEX idx_reservacion_habitacion ON reservacion(id_habitacion);
CREATE INDEX idx_reservacion_huesped ON reservacion(id_huesped);
CREATE INDEX idx_reservacion_fechas ON reservacion(fecha_inicio, fecha_fin);
CREATE INDEX idx_consumo_reservacion ON consumo_servicio(id_reservacion);
CREATE INDEX idx_factura_reservacion ON factura(id_reservacion);
CREATE INDEX idx_check_reservacion ON check_in_out(id_reservacion);
