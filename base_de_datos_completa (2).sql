-- ============================================================
-- BellaVista Remis — ESTRUCTURA DE LA BASE DE DATOS (PostgreSQL 14+)
-- Versión para clase: 22 tablas normalizadas hasta 3FN. Ejecutar primero.
-- ============================================================

-- ---------- Tablas de catálogo (valores fijos) ----------
CREATE TABLE rol (
  id     SMALLINT    PRIMARY KEY,
  nombre VARCHAR(20) NOT NULL UNIQUE            -- pasajero, conductor, comercio, admin
);

CREATE TABLE estado_viaje (
  id     SMALLINT    PRIMARY KEY,
  codigo VARCHAR(12) NOT NULL UNIQUE,           -- buscando, asignado, camino, llego, curso, finalizado, cancelado, programado
  nombre VARCHAR(40) NOT NULL
);

CREATE TABLE medio_pago (
  id     SMALLINT    PRIMARY KEY,
  nombre VARCHAR(30) NOT NULL UNIQUE            -- Billetera, Efectivo, Puntos, Mercado Pago, Ualá, Transferencia, Tarjeta
);

CREATE TABLE marca (
  id     SERIAL      PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL UNIQUE
);

CREATE TABLE modelo (
  id       SERIAL      PRIMARY KEY,
  marca_id INT         NOT NULL REFERENCES marca(id),
  nombre   VARCHAR(40) NOT NULL,
  UNIQUE (marca_id, nombre)
);

CREATE TABLE tipo_patente (
  id     SMALLINT    PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL UNIQUE            -- Mercosur (AB 123 CD) / Anterior (ABC 123)
);

CREATE TABLE tipo_documento (                   -- qué documentación se le exige al chofer (la edita el super admin)
  id              SMALLINT     PRIMARY KEY,
  codigo          VARCHAR(20)  NOT NULL UNIQUE,
  nombre          VARCHAR(80)  NOT NULL,
  aplica_a        VARCHAR(10)  NOT NULL CHECK (aplica_a IN ('conductor','vehiculo')),
  pide_vencimiento BOOLEAN     NOT NULL DEFAULT FALSE,
  pide_numero     BOOLEAN      NOT NULL DEFAULT FALSE,
  pide_entidad    BOOLEAN      NOT NULL DEFAULT FALSE,
  obligatorio     BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE tarifa (                           -- cada fila es una versión; la vigente es la más reciente
  id                   SERIAL        PRIMARY KEY,
  precio_100m          NUMERIC(10,2) NOT NULL CHECK (precio_100m >= 0),
  minima               NUMERIC(10,2) NOT NULL CHECK (minima >= 0),
  base                 NUMERIC(10,2) NOT NULL DEFAULT 0,   -- solo si no hay mapa
  por_km               NUMERIC(10,2) NOT NULL DEFAULT 0,   -- solo si no hay mapa
  recargo_nocturno_pct NUMERIC(5,2)  NOT NULL DEFAULT 0,
  recargo_rural_pct    NUMERIC(5,2)  NOT NULL DEFAULT 0,
  vigente_desde        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ---------- Personas ----------
CREATE TABLE usuario (
  id            UUID         PRIMARY KEY,   -- en Supabase coincide con el id del login (auth.users)
  rol_id        SMALLINT     NOT NULL REFERENCES rol(id),
  nombre        VARCHAR(80)  NOT NULL,
  apellido      VARCHAR(80)  NOT NULL DEFAULT '',
  dni           VARCHAR(12),
  telefono      VARCHAR(30)  NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  foto          TEXT,                            -- URL o imagen en base64 (256 px)
  estado        VARCHAR(10)  NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','bloqueado')),
  creado_en     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE pasajero (                          -- especialización 1 a 1 de usuario
  usuario_id    UUID          PRIMARY KEY REFERENCES usuario(id) ON DELETE CASCADE,
  saldo         NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (saldo >= 0),
  puntos        INT           NOT NULL DEFAULT 0 CHECK (puntos >= 0),
  viajes_gratis INT           NOT NULL DEFAULT 0 CHECK (viajes_gratis >= 0)
);

CREATE TABLE comercio (                          -- supermercados / comercios con pantalla de pedidos
  usuario_id   UUID         PRIMARY KEY REFERENCES usuario(id) ON DELETE CASCADE,
  nombre_local VARCHAR(100) NOT NULL,
  direccion    VARCHAR(200) NOT NULL,
  lat          NUMERIC(9,6),
  lng          NUMERIC(9,6)
);

CREATE TABLE conductor (
  id                SERIAL      PRIMARY KEY,
  usuario_id        UUID        NOT NULL UNIQUE REFERENCES usuario(id) ON DELETE CASCADE,
  licencia          VARCHAR(30) NOT NULL UNIQUE,
  estado_aprobacion VARCHAR(10) NOT NULL DEFAULT 'pendiente' CHECK (estado_aprobacion IN ('pendiente','aprobado','rechazado')),
  disponible        BOOLEAN     NOT NULL DEFAULT FALSE,
  puntos            INT         NOT NULL DEFAULT 0 CHECK (puntos >= 0),
  bonos             INT         NOT NULL DEFAULT 0 CHECK (bonos >= 0)
);

CREATE TABLE vehiculo (
  id           SERIAL      PRIMARY KEY,
  conductor_id INT         NOT NULL REFERENCES conductor(id) ON DELETE CASCADE,
  modelo_id    INT         NOT NULL REFERENCES modelo(id),
  tipo_patente_id SMALLINT NOT NULL REFERENCES tipo_patente(id),
  anio         SMALLINT    NOT NULL CHECK (anio BETWEEN 1990 AND 2100),
  asientos     SMALLINT    NOT NULL DEFAULT 4 CHECK (asientos BETWEEN 2 AND 9),
  color        VARCHAR(30) NOT NULL,
  patente      VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE documento (                        -- documentación que sube el chofer y revisa el super admin
  id                SERIAL       PRIMARY KEY,
  conductor_id      INT          NOT NULL REFERENCES conductor(id) ON DELETE CASCADE,
  vehiculo_id       INT          REFERENCES vehiculo(id) ON DELETE CASCADE,     -- NULL si es del chofer (licencia)
  tipo_documento_id SMALLINT     NOT NULL REFERENCES tipo_documento(id),
  numero            VARCHAR(40),                                                  -- ej: N° de póliza
  entidad           VARCHAR(80),                                                  -- ej: aseguradora
  vence_el          DATE,
  archivo           TEXT         NOT NULL,                                        -- imagen del documento
  estado            VARCHAR(10)  NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','aprobado','rechazado')),
  observacion       TEXT,                                                         -- motivo si se rechaza
  revisado_por      UUID         REFERENCES usuario(id) ON DELETE SET NULL,
  revisado_en       TIMESTAMPTZ,
  creado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (conductor_id, tipo_documento_id)                                        -- vale la última versión subida
);

-- ---------- Viajes ----------
CREATE TABLE viaje (
  id                  BIGSERIAL     PRIMARY KEY,
  codigo              VARCHAR(12)   NOT NULL UNIQUE,                 -- BV-000125
  solicitante_id      UUID          NOT NULL REFERENCES usuario(id), -- pasajero o comercio
  conductor_id        INT           REFERENCES conductor(id),        -- NULL hasta que alguien acepta
  estado_id           SMALLINT      NOT NULL REFERENCES estado_viaje(id),
  cliente_nombre      VARCHAR(80),                                   -- solo viajes pedidos desde un comercio
  cliente_telefono    VARCHAR(30),
  origen_direccion    VARCHAR(200)  NOT NULL,
  origen_lat          NUMERIC(9,6),
  origen_lng          NUMERIC(9,6),
  destino_direccion   VARCHAR(200)  NOT NULL,
  destino_lat         NUMERIC(9,6),
  destino_lng         NUMERIC(9,6),
  distancia_m         INT           CHECK (distancia_m >= 0),
  cantidad_pasajeros  SMALLINT      NOT NULL DEFAULT 1 CHECK (cantidad_pasajeros BETWEEN 1 AND 8),
  observaciones       TEXT,
  tarifa              NUMERIC(10,2) NOT NULL CHECK (tarifa >= 0),
  medio_pago_id       SMALLINT      REFERENCES medio_pago(id),       -- Puntos = viaje gratis
  programado_para     TIMESTAMPTZ,                                   -- NULL si es inmediato
  creado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),
  finalizado_en       TIMESTAMPTZ
);

CREATE TABLE viaje_rechazo (                      -- relación N a M: conductores que rechazaron un viaje
  viaje_id     BIGINT      NOT NULL REFERENCES viaje(id) ON DELETE CASCADE,
  conductor_id INT         NOT NULL REFERENCES conductor(id),
  creado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (viaje_id, conductor_id)
);

CREATE TABLE cancelacion (
  id         SERIAL       PRIMARY KEY,
  viaje_id   BIGINT       NOT NULL REFERENCES viaje(id) ON DELETE CASCADE,
  usuario_id UUID         NOT NULL REFERENCES usuario(id),          -- quién canceló (su rol dice si fue pasajero o conductor)
  motivo     VARCHAR(120) NOT NULL,
  creado_en  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE calificacion (
  id         SERIAL      PRIMARY KEY,
  viaje_id   BIGINT      NOT NULL UNIQUE REFERENCES viaje(id) ON DELETE CASCADE,  -- una por viaje
  estrellas  SMALLINT    NOT NULL CHECK (estrellas BETWEEN 1 AND 5),
  comentario TEXT,
  creado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Billetera y puntos ----------
CREATE TABLE movimiento_billetera (
  id            BIGSERIAL     PRIMARY KEY,
  usuario_id    UUID          NOT NULL REFERENCES pasajero(usuario_id),
  viaje_id      BIGINT        REFERENCES viaje(id),                 -- NULL en las cargas
  tipo          VARCHAR(5)    NOT NULL CHECK (tipo IN ('carga','viaje')),
  monto         NUMERIC(12,2) NOT NULL CHECK (monto >= 0),
  detalle       VARCHAR(160)  NOT NULL,
  medio_pago_id SMALLINT      NOT NULL REFERENCES medio_pago(id),
  creado_en     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE movimiento_puntos (
  id         BIGSERIAL   PRIMARY KEY,
  usuario_id UUID        NOT NULL REFERENCES usuario(id),
  viaje_id   BIGINT      REFERENCES viaje(id),
  puntos     INT         NOT NULL,                                   -- + gana, - canjea
  motivo     VARCHAR(20) NOT NULL CHECK (motivo IN ('viaje','calificacion_5','canje_viaje_gratis','canje_bono')),
  creado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Índices ----------
CREATE INDEX ix_viaje_conductor_estado ON viaje (conductor_id, estado_id);
CREATE INDEX ix_viaje_solicitante      ON viaje (solicitante_id);
CREATE INDEX ix_viaje_creado           ON viaje (creado_en);
CREATE INDEX ix_mov_billetera_usuario  ON movimiento_billetera (usuario_id, creado_en);
CREATE INDEX ix_mov_puntos_usuario     ON movimiento_puntos (usuario_id, creado_en);

-- ---------- Vistas (datos derivados: no se guardan duplicados) ----------
CREATE VIEW vw_calificacion_conductor AS
SELECT v.conductor_id, ROUND(AVG(c.estrellas), 2) AS promedio, COUNT(*) AS cantidad
FROM calificacion c JOIN viaje v ON v.id = c.viaje_id
WHERE v.conductor_id IS NOT NULL
GROUP BY v.conductor_id;

CREATE VIEW vw_ranking_choferes AS
SELECT d.id AS conductor_id, u.nombre, u.apellido,
       COUNT(v.id) FILTER (WHERE e.codigo = 'finalizado') AS viajes_finalizados,
       COALESCE(SUM(v.tarifa) FILTER (WHERE e.codigo = 'finalizado' AND mp.nombre IS DISTINCT FROM 'Puntos'), 0) AS ganado,
       COALESCE(r.promedio, 0) AS calificacion,
       d.puntos
FROM conductor d
JOIN usuario u ON u.id = d.usuario_id
LEFT JOIN viaje v ON v.conductor_id = d.id
LEFT JOIN estado_viaje e ON e.id = v.estado_id
LEFT JOIN medio_pago mp ON mp.id = v.medio_pago_id
LEFT JOIN vw_calificacion_conductor r ON r.conductor_id = d.id
WHERE d.estado_aprobacion = 'aprobado'
GROUP BY d.id, u.nombre, u.apellido, r.promedio, d.puntos
ORDER BY viajes_finalizados DESC, calificacion DESC;

-- ---------- Ajustes editables (puntos y modo de cargas) ----------
CREATE TABLE configuracion (
  clave VARCHAR(40)  PRIMARY KEY,
  valor VARCHAR(100) NOT NULL
);
CREATE TABLE auditoria (                 -- quién hizo qué (acciones del administrador y del super admin)
  id         BIGSERIAL    PRIMARY KEY,
  usuario_id UUID         REFERENCES usuario(id) ON DELETE SET NULL,
  accion     VARCHAR(40)  NOT NULL,
  detalle    TEXT,
  creado_en  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE SEQUENCE seq_viaje START 125;     -- número de viaje: BV-000125

-- ---------- Datos iniciales de los catálogos ----------
INSERT INTO rol VALUES (1,'pasajero'),(2,'conductor'),(3,'comercio'),(4,'admin'),(5,'superadmin');
INSERT INTO estado_viaje VALUES
  (1,'buscando','Buscando conductor'),(2,'asignado','Conductor asignado'),(3,'camino','Conductor en camino'),
  (4,'llego','Conductor llegó'),(5,'curso','Viaje en curso'),(6,'finalizado','Viaje finalizado'),
  (7,'cancelado','Viaje cancelado'),(8,'programado','Viaje programado');
INSERT INTO tipo_patente VALUES (1,'Mercosur (AB 123 CD)'),(2,'Anterior (ABC 123)');
INSERT INTO tipo_documento (id, codigo, nombre, aplica_a, pide_vencimiento, pide_numero, pide_entidad, obligatorio) VALUES
  (1,'foto_auto',    'Foto del auto',                     'vehiculo', FALSE, FALSE, FALSE, TRUE),
  (2,'foto_patente', 'Foto de la patente',                'vehiculo', FALSE, FALSE, FALSE, TRUE),
  (3,'licencia',     'Licencia de conducir profesional',  'conductor',TRUE,  FALSE, FALSE, TRUE),
  (4,'seguro',       'Seguro del vehículo (al día)',      'vehiculo', TRUE,  TRUE,  TRUE,  TRUE),
  (5,'vtv',          'Verificación técnica (VTV/RTO)',    'vehiculo', TRUE,  FALSE, FALSE, TRUE),
  (6,'cedula',       'Cédula del vehículo',               'vehiculo', FALSE, FALSE, FALSE, TRUE),
  (7,'habilitacion', 'Habilitación municipal de remis',   'vehiculo', TRUE,  TRUE,  FALSE, TRUE);
INSERT INTO medio_pago VALUES
  (1,'Billetera'),(2,'Efectivo'),(3,'Puntos'),(4,'Mercado Pago'),(5,'Ualá'),(6,'Transferencia'),(7,'Tarjeta');
INSERT INTO tarifa (precio_100m, minima, base, por_km, recargo_nocturno_pct, recargo_rural_pct)
VALUES (300, 1200, 800, 220, 15, 25);
INSERT INTO configuracion VALUES
  ('carga_simulada','true'),                -- 'true' = las cargas de saldo son de prueba. Poner 'false' al cobrar de verdad
  ('puntos_pasajero_por_viaje','150'), ('meta_puntos_pasajero','1000'),
  ('puntos_conductor_por_viaje','100'), ('bonus_5_estrellas','50'), ('meta_puntos_conductor','2000');


-- ============================================================
-- BellaVista Remis — DATOS DE EJEMPLO (ejecutar después de 01_estructura.sql)
-- Datos coherentes: saldos, puntos y cobros salen de los viajes.
-- ============================================================

INSERT INTO usuario (id, rol_id, nombre, apellido, dni, telefono, email, estado, creado_en) VALUES
('00000000-0000-4000-8000-000000000001', 5, 'Raúl', 'Montoya', '28111222', '381 555 0101', 'dueno@bellavistaremis.com', 'activo', '2026-09-11 10:00:00-03'),
('00000000-0000-4000-8000-000000000002', 4, 'Laura', 'Benítez', '30222333', '381 555 0102', 'laura.benitez@bellavistaremis.com', 'activo', '2026-09-12 10:00:00-03'),
('00000000-0000-4000-8000-000000000003', 1, 'María', 'López', '35111001', '381 555 0103', 'maria.lopez@gmail.com', 'activo', '2026-09-13 10:00:00-03'),
('00000000-0000-4000-8000-000000000004', 1, 'Juan', 'Pérez', '36222002', '381 555 0104', 'juan.perez@gmail.com', 'activo', '2026-09-14 10:00:00-03'),
('00000000-0000-4000-8000-000000000005', 1, 'Lucía', 'Gómez', '37333003', '381 555 0105', 'lucia.gomez@gmail.com', 'activo', '2026-09-15 10:00:00-03'),
('00000000-0000-4000-8000-000000000006', 1, 'Pedro', 'Díaz', '34444004', '381 555 0106', 'pedro.diaz@gmail.com', 'activo', '2026-09-16 10:00:00-03'),
('00000000-0000-4000-8000-000000000007', 1, 'Sofía', 'Ruiz', '38555005', '381 555 0107', 'sofia.ruiz@gmail.com', 'activo', '2026-09-17 10:00:00-03'),
('00000000-0000-4000-8000-000000000008', 1, 'Martín', 'Torres', '33666006', '381 555 0108', 'martin.torres@gmail.com', 'activo', '2026-09-18 10:00:00-03'),
('00000000-0000-4000-8000-000000000009', 3, 'Supermercado El Sol', '', '30999001', '381 555 0109', 'elsol@supermercados.com', 'activo', '2026-09-19 10:00:00-03'),
('00000000-0000-4000-8000-000000000010', 3, 'Autoservicio La Esquina', '', '30999002', '381 555 0110', 'laesquina@autoservicio.com', 'activo', '2026-09-20 10:00:00-03'),
('00000000-0000-4000-8000-000000000011', 2, 'Carlos', 'Gómez', '27123456', '381 555 0111', 'carlos.gomez@gmail.com', 'activo', '2026-09-21 10:00:00-03'),
('00000000-0000-4000-8000-000000000012', 2, 'Luis', 'Ramos', '29234567', '381 555 0112', 'luis.ramos@gmail.com', 'activo', '2026-09-22 10:00:00-03'),
('00000000-0000-4000-8000-000000000013', 2, 'Ana', 'Torres', '31345678', '381 555 0113', 'ana.torres@gmail.com', 'activo', '2026-09-23 10:00:00-03'),
('00000000-0000-4000-8000-000000000014', 2, 'Diego', 'Sosa', '32456789', '381 555 0114', 'diego.sosa@gmail.com', 'activo', '2026-09-24 10:00:00-03');

INSERT INTO pasajero (usuario_id, saldo, puntos, viajes_gratis) VALUES
('00000000-0000-4000-8000-000000000003', 4200, 50, 1),
('00000000-0000-4000-8000-000000000004', 3000, 150, 0),
('00000000-0000-4000-8000-000000000005', 800, 450, 0),
('00000000-0000-4000-8000-000000000006', 2000, 150, 0),
('00000000-0000-4000-8000-000000000007', 2600, 300, 0),
('00000000-0000-4000-8000-000000000008', 0, 150, 0);

INSERT INTO comercio (usuario_id, nombre_local, direccion, lat, lng) VALUES
('00000000-0000-4000-8000-000000000009', 'Supermercado El Sol', 'Av. San Martín 450', -27.0291, -65.3012),
('00000000-0000-4000-8000-000000000010', 'Autoservicio La Esquina', 'Calle Belgrano 120', -27.0312, -65.3055);

INSERT INTO marca (nombre) VALUES ('Fiat'),('Chevrolet'),('Volkswagen'),('Renault');
INSERT INTO modelo (marca_id, nombre) VALUES (1,'Siena'),(1,'Cronos'),(2,'Onix'),(3,'Gol'),(4,'Logan');

INSERT INTO conductor (id, usuario_id, licencia, estado_aprobacion, disponible, puntos, bonos) VALUES
(1, '00000000-0000-4000-8000-000000000011', 'LIC-2024-101', 'aprobado', TRUE, 1100, 0),
(2, '00000000-0000-4000-8000-000000000012', 'LIC-2024-102', 'aprobado', TRUE, 1000, 0),
(3, '00000000-0000-4000-8000-000000000013', 'LIC-2024-103', 'aprobado', FALSE, 250, 0),
(4, '00000000-0000-4000-8000-000000000014', 'LIC-2024-104', 'pendiente', FALSE, 0, 0);

INSERT INTO vehiculo (id, conductor_id, modelo_id, tipo_patente_id, anio, asientos, color, patente) VALUES
(1, 1, 1, 1, 2020, 4, 'Blanco', 'AB123CD'),
(2, 2, 3, 1, 2021, 4, 'Rojo',   'AC456EF'),
(3, 3, 4, 2, 2015, 4, 'Negro',  'GHT582'),
(4, 4, 5, 1, 2019, 4, 'Gris',   'AA987BB');

INSERT INTO documento (id, conductor_id, vehiculo_id, tipo_documento_id, numero, entidad, vence_el, archivo, estado, observacion, revisado_por, revisado_en) VALUES
(1, 1, 1, 1, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(2, 1, 1, 2, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(3, 1, NULL, 3, NULL, NULL, '2027-06-30', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(4, 1, 1, 4, 'POL-5011', 'La Caja', '2026-11-15', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(5, 1, 1, 5, NULL, NULL, '2027-03-10', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(6, 1, 1, 6, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(7, 1, 1, 7, 'HAB-301', NULL, '2027-01-31', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-15 15:00:00-03'),
(8, 2, 2, 1, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(9, 2, 2, 2, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(10, 2, NULL, 3, NULL, NULL, '2028-01-15', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(11, 2, 2, 4, 'POL-5022', 'Federación Patronal', '2027-02-28', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(12, 2, 2, 5, NULL, NULL, '2026-12-20', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(13, 2, 2, 6, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(14, 2, 2, 7, 'HAB-302', NULL, '2027-05-31', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-16 15:00:00-03'),
(15, 3, 3, 1, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(16, 3, 3, 2, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(17, 3, NULL, 3, NULL, NULL, '2027-09-01', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(18, 3, 3, 4, 'POL-5033', 'Sancor Seguros', '2026-10-10', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(19, 3, 3, 5, NULL, NULL, '2027-08-01', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(20, 3, 3, 6, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(21, 3, 3, 7, 'HAB-303', NULL, '2027-02-15', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'aprobado', NULL, '00000000-0000-4000-8000-000000000001', '2026-09-17 15:00:00-03'),
(22, 4, 4, 1, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'pendiente', NULL, NULL, NULL),
(23, 4, 4, 2, NULL, NULL, NULL, 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'pendiente', NULL, NULL, NULL),
(24, 4, NULL, 3, NULL, NULL, '2027-04-01', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'pendiente', NULL, NULL, NULL),
(25, 4, 4, 4, 'POL-9001', 'La Caja', '2027-04-01', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'rechazado', 'Foto borrosa', '00000000-0000-4000-8000-000000000001', '2026-10-26 11:00:00-03'),
(26, 4, 4, 5, NULL, NULL, '2027-05-20', 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', 'pendiente', NULL, NULL, NULL);

INSERT INTO viaje (id, codigo, solicitante_id, conductor_id, estado_id, cliente_nombre, cliente_telefono, origen_direccion, origen_lat, origen_lng, destino_direccion, destino_lat, destino_lng, distancia_m, cantidad_pasajeros, observaciones, tarifa, medio_pago_id, programado_para, creado_en, finalizado_en) VALUES
(1, 'BV-000125', '00000000-0000-4000-8000-000000000004', 1, 6, NULL, NULL, 'Calle Belgrano 898', -27.033119, -65.304731, 'Plaza Central', -27.013119, -65.274731, 15200, 2, NULL, 45600, 2, NULL, '2026-10-01 18:40:00-03', '2026-10-01 18:55:00-03'),
(2, 'BV-000126', '00000000-0000-4000-8000-000000000003', 3, 6, NULL, NULL, 'Av. Sarmiento 593', -27.034247, -65.306461, 'Terminal de ómnibus', -27.014247, -65.276461, 6800, 2, NULL, 20400, 2, NULL, '2026-10-02 11:50:00-03', '2026-10-02 12:22:00-03'),
(3, 'BV-000127', '00000000-0000-4000-8000-000000000003', 3, 6, NULL, NULL, 'Calle Rivadavia 196', -27.037598, -65.294068, 'Hospital Zonal', -27.017598, -65.264068, 9000, 1, NULL, 27000, 2, NULL, '2026-10-05 22:20:00-03', '2026-10-05 22:47:00-03'),
(4, 'BV-000128', '00000000-0000-4000-8000-000000000003', 2, 6, NULL, NULL, 'Calle Belgrano 761', -27.035373, -65.290927, 'Complejo Batalla de Tucumán', -27.015373, -65.260927, 3100, 1, NULL, 9300, 2, NULL, '2026-10-07 15:50:00-03', '2026-10-07 16:20:00-03'),
(5, 'BV-000129', '00000000-0000-4000-8000-000000000009', 2, 6, 'Rosa', '381 555 9874', 'Av. San Martín 450', -27.031840, -65.294334, 'Barrio Norte', -27.011840, -65.264334, 6800, 1, NULL, 20400, 2, NULL, '2026-10-09 18:40:00-03', '2026-10-09 18:54:00-03'),
(6, 'BV-000130', '00000000-0000-4000-8000-000000000003', 2, 7, NULL, NULL, 'Av. Sarmiento 803', -27.032961, -65.306865, 'Escuela N° 12', -27.012961, -65.276865, 1750, 3, NULL, 5400, NULL, NULL, '2026-10-11 21:10:00-03', NULL),
(7, 'BV-000131', '00000000-0000-4000-8000-000000000007', 1, 6, NULL, NULL, 'Av. Sarmiento 833', -27.024164, -65.305669, 'Club Atlético', -27.004164, -65.275669, 5200, 1, NULL, 15600, 2, NULL, '2026-10-13 22:10:00-03', '2026-10-13 22:26:00-03'),
(8, 'BV-000132', '00000000-0000-4000-8000-000000000009', 2, 6, 'Rosa', '381 555 6668', 'Av. San Martín 450', -27.028884, -65.298639, 'Barrio Sur', -27.008884, -65.268639, 15200, 1, NULL, 45600, 2, NULL, '2026-10-14 13:30:00-03', '2026-10-14 13:58:00-03'),
(9, 'BV-000133', '00000000-0000-4000-8000-000000000010', 2, 6, 'Rosa', '381 555 2831', 'Calle Belgrano 120', -27.028743, -65.296594, 'Mercado Municipal', -27.008743, -65.266594, 6800, 1, NULL, 20400, 2, NULL, '2026-10-14 22:45:00-03', '2026-10-14 23:09:00-03'),
(10, 'BV-000134', '00000000-0000-4000-8000-000000000003', 1, 6, NULL, NULL, 'Av. Mitre 800', -27.038071, -65.301279, 'Estación de servicio YPF', -27.018071, -65.271279, 1200, 1, NULL, 3600, 1, NULL, '2026-10-15 11:30:00-03', '2026-10-15 11:58:00-03'),
(11, 'BV-000135', '00000000-0000-4000-8000-000000000004', NULL, 8, NULL, NULL, 'Calle San Martín 761', -27.024818, -65.295553, 'Cooperativa eléctrica', -27.004818, -65.265553, 3100, 1, NULL, 9300, NULL, '2026-10-30 09:00:00-03', '2026-10-15 20:10:00-03', NULL),
(12, 'BV-000136', '00000000-0000-4000-8000-000000000003', 2, 6, NULL, NULL, 'Av. Mitre 398', -27.029867, -65.304464, 'Barrio Las Flores', -27.009867, -65.274464, 6800, 1, NULL, 20400, 2, NULL, '2026-10-15 22:45:00-03', '2026-10-15 22:57:00-03'),
(13, 'BV-000137', '00000000-0000-4000-8000-000000000004', 2, 7, NULL, NULL, 'Av. Mitre 521', -27.036772, -65.304878, 'Plaza Central', -27.016772, -65.274878, 4213, 1, NULL, 12900, NULL, NULL, '2026-10-17 15:45:00-03', NULL),
(14, 'BV-000138', '00000000-0000-4000-8000-000000000003', 1, 6, NULL, NULL, 'Av. Mitre 340', -27.031709, -65.309691, 'Terminal de ómnibus', -27.011709, -65.279691, 1200, 1, NULL, 3600, 1, NULL, '2026-10-18 08:30:00-03', '2026-10-18 08:43:00-03'),
(15, 'BV-000139', '00000000-0000-4000-8000-000000000009', 2, 6, 'Oscar', '381 555 6722', 'Av. San Martín 450', -27.033802, -65.308123, 'Hospital Zonal', -27.013802, -65.278123, 15200, 1, NULL, 45600, 2, NULL, '2026-10-18 16:30:00-03', '2026-10-18 16:42:00-03'),
(16, 'BV-000140', '00000000-0000-4000-8000-000000000005', 1, 6, NULL, NULL, 'Calle 25 de Mayo 770', -27.033701, -65.300879, 'Complejo Batalla de Tucumán', -27.013701, -65.270879, 2400, 3, NULL, 7200, 1, NULL, '2026-10-18 19:30:00-03', '2026-10-18 19:58:00-03'),
(17, 'BV-000141', '00000000-0000-4000-8000-000000000005', 2, 6, NULL, NULL, 'Av. Sarmiento 320', -27.039240, -65.301916, 'Barrio Norte', -27.019240, -65.271916, 5200, 3, NULL, 15600, 2, NULL, '2026-10-18 22:45:00-03', '2026-10-18 23:00:00-03'),
(18, 'BV-000142', '00000000-0000-4000-8000-000000000005', 1, 6, NULL, NULL, 'Av. Mitre 802', -27.030747, -65.290418, 'Escuela N° 12', -27.010747, -65.260418, 1750, 1, NULL, 5400, 2, NULL, '2026-10-19 14:15:00-03', '2026-10-19 14:31:00-03'),
(19, 'BV-000143', '00000000-0000-4000-8000-000000000006', 2, 7, NULL, NULL, 'Calle Rivadavia 498', -27.022774, -65.296372, 'Club Atlético', -27.002774, -65.266372, 6800, 1, NULL, 20400, NULL, NULL, '2026-10-19 22:00:00-03', NULL),
(20, 'BV-000144', '00000000-0000-4000-8000-000000000007', 2, 6, NULL, NULL, 'Calle 25 de Mayo 832', -27.021059, -65.302874, 'Barrio Sur', -27.001059, -65.272874, 800, 2, NULL, 2400, 1, NULL, '2026-10-22 22:30:00-03', '2026-10-22 23:01:00-03'),
(21, 'BV-000145', '00000000-0000-4000-8000-000000000003', 2, 6, NULL, NULL, 'Calle Rivadavia 396', -27.022432, -65.304371, 'Mercado Municipal', -27.002432, -65.274371, 1200, 1, NULL, 3600, 1, NULL, '2026-10-23 20:50:00-03', '2026-10-23 21:03:00-03'),
(22, 'BV-000146', '00000000-0000-4000-8000-000000000010', 1, 6, 'Oscar', '381 555 9397', 'Calle Belgrano 120', -27.034061, -65.301667, 'Estación de servicio YPF', -27.014061, -65.271667, 15200, 1, NULL, 45600, 2, NULL, '2026-10-24 17:10:00-03', '2026-10-24 17:36:00-03'),
(23, 'BV-000147', '00000000-0000-4000-8000-000000000008', 1, 6, NULL, NULL, 'Av. Sarmiento 157', -27.029157, -65.303150, 'Cooperativa eléctrica', -27.009157, -65.273150, 800, 1, NULL, 2400, 2, NULL, '2026-10-26 19:10:00-03', '2026-10-26 19:37:00-03'),
(24, 'BV-000148', '00000000-0000-4000-8000-000000000009', 1, 6, 'Marta', '381 555 3029', 'Av. San Martín 450', -27.036758, -65.307546, 'Barrio Las Flores', -27.016758, -65.277546, 6800, 3, NULL, 20400, 2, NULL, '2026-10-26 22:40:00-03', '2026-10-26 23:08:00-03'),
(25, 'BV-000149', '00000000-0000-4000-8000-000000000006', 1, 6, NULL, NULL, 'Calle 25 de Mayo 409', -27.032919, -65.297042, 'Plaza Central', -27.012919, -65.267042, 9000, 1, NULL, 27000, 2, NULL, '2026-10-27 08:10:00-03', '2026-10-27 08:27:00-03'),
(26, 'BV-000150', '00000000-0000-4000-8000-000000000004', 2, 5, NULL, NULL, 'Calle Belgrano 493', -27.031505, -65.307474, 'Terminal de ómnibus', -27.011505, -65.277474, 1200, 2, NULL, 3600, NULL, NULL, '2026-10-28 11:05:00-03', NULL),
(27, 'BV-000151', '00000000-0000-4000-8000-000000000003', NULL, 1, NULL, NULL, 'Calle San Martín 893', -27.035214, -65.301580, 'Hospital Zonal', -27.015214, -65.271580, 2400, 1, NULL, 7200, NULL, NULL, '2026-10-28 11:40:00-03', NULL);

INSERT INTO viaje_rechazo (viaje_id, conductor_id) VALUES (12, 1), (18, 2), (27, 1);

INSERT INTO cancelacion (viaje_id, usuario_id, motivo, creado_en) VALUES
(6, '00000000-0000-4000-8000-000000000003', 'Pedí por error', '2026-10-11 21:14:00-03'),
(13, '00000000-0000-4000-8000-000000000004', 'Demoró mucho', '2026-10-17 15:49:00-03'),
(19, '00000000-0000-4000-8000-000000000006', 'Cambié de idea', '2026-10-19 22:04:00-03'),
(12, '00000000-0000-4000-8000-000000000011', 'Problema mecánico', '2026-10-15 22:48:00-03');

INSERT INTO calificacion (viaje_id, estrellas, comentario, creado_en) VALUES
(1, 4, 'Todo bien', '2026-10-01 19:00:00-03'),
(2, 5, 'Podría ser más rápido', '2026-10-02 12:27:00-03'),
(3, 3, 'Demoró en llegar', '2026-10-05 22:52:00-03'),
(4, 5, 'Podría ser más rápido', '2026-10-07 16:25:00-03'),
(16, 4, 'Auto limpio', '2026-10-18 20:03:00-03'),
(17, 5, 'Podría ser más rápido', '2026-10-18 23:05:00-03'),
(18, 5, 'Podría ser más rápido', '2026-10-19 14:36:00-03'),
(20, 4, 'Podría ser más rápido', '2026-10-22 23:06:00-03'),
(21, 3, 'Demoró en llegar', '2026-10-23 21:08:00-03'),
(23, 3, 'Demoró en llegar', '2026-10-26 19:42:00-03'),
(25, 5, 'Todo bien', '2026-10-27 08:32:00-03');

INSERT INTO movimiento_billetera (usuario_id, viaje_id, tipo, monto, detalle, medio_pago_id, creado_en) VALUES
('00000000-0000-4000-8000-000000000003', NULL, 'carga', 5000, 'Carga de dinero', 4, '2026-10-01 09:00:00-03'),
('00000000-0000-4000-8000-000000000004', 1, 'viaje', 45600, 'Viaje a Plaza Central', 2, '2026-10-01 18:55:00-03'),
('00000000-0000-4000-8000-000000000004', NULL, 'carga', 3000, 'Carga de dinero', 6, '2026-10-02 12:00:00-03'),
('00000000-0000-4000-8000-000000000003', 2, 'viaje', 20400, 'Viaje a Terminal de ómnibus', 2, '2026-10-02 12:22:00-03'),
('00000000-0000-4000-8000-000000000005', NULL, 'carga', 8000, 'Carga de dinero', 7, '2026-10-04 08:15:00-03'),
('00000000-0000-4000-8000-000000000006', NULL, 'carga', 2000, 'Carga de dinero', 4, '2026-10-05 20:00:00-03'),
('00000000-0000-4000-8000-000000000003', 3, 'viaje', 27000, 'Viaje a Hospital Zonal', 2, '2026-10-05 22:47:00-03'),
('00000000-0000-4000-8000-000000000003', 4, 'viaje', 9300, 'Viaje a Complejo Batalla de Tucumán', 2, '2026-10-07 16:20:00-03'),
('00000000-0000-4000-8000-000000000003', NULL, 'carga', 10000, 'Carga de dinero', 5, '2026-10-13 18:30:00-03'),
('00000000-0000-4000-8000-000000000007', 7, 'viaje', 15600, 'Viaje a Club Atlético', 2, '2026-10-13 22:26:00-03'),
('00000000-0000-4000-8000-000000000003', 10, 'viaje', 3600, 'Viaje a Estación de servicio YPF', 1, '2026-10-15 11:58:00-03'),
('00000000-0000-4000-8000-000000000003', 12, 'viaje', 20400, 'Viaje a Barrio Las Flores', 2, '2026-10-15 22:57:00-03'),
('00000000-0000-4000-8000-000000000003', 14, 'viaje', 3600, 'Viaje a Terminal de ómnibus', 1, '2026-10-18 08:43:00-03'),
('00000000-0000-4000-8000-000000000005', 16, 'viaje', 7200, 'Viaje a Complejo Batalla de Tucumán', 1, '2026-10-18 19:58:00-03'),
('00000000-0000-4000-8000-000000000005', 17, 'viaje', 15600, 'Viaje a Barrio Norte', 2, '2026-10-18 23:00:00-03'),
('00000000-0000-4000-8000-000000000005', 18, 'viaje', 5400, 'Viaje a Escuela N° 12', 2, '2026-10-19 14:31:00-03'),
('00000000-0000-4000-8000-000000000007', NULL, 'carga', 5000, 'Carga de dinero', 5, '2026-10-20 10:30:00-03'),
('00000000-0000-4000-8000-000000000007', 20, 'viaje', 2400, 'Viaje a Barrio Sur', 1, '2026-10-22 23:01:00-03'),
('00000000-0000-4000-8000-000000000003', 21, 'viaje', 3600, 'Viaje a Mercado Municipal', 1, '2026-10-23 21:03:00-03'),
('00000000-0000-4000-8000-000000000008', 23, 'viaje', 2400, 'Viaje a Cooperativa eléctrica', 2, '2026-10-26 19:37:00-03'),
('00000000-0000-4000-8000-000000000006', 25, 'viaje', 27000, 'Viaje a Plaza Central', 2, '2026-10-27 08:27:00-03');

INSERT INTO movimiento_puntos (usuario_id, viaje_id, puntos, motivo, creado_en) VALUES
('00000000-0000-4000-8000-000000000004', 1, 150, 'viaje', '2026-10-01 18:55:00-03'),
('00000000-0000-4000-8000-000000000011', 1, 100, 'viaje', '2026-10-01 18:55:00-03'),
('00000000-0000-4000-8000-000000000003', 2, 150, 'viaje', '2026-10-02 12:22:00-03'),
('00000000-0000-4000-8000-000000000013', 2, 100, 'viaje', '2026-10-02 12:22:00-03'),
('00000000-0000-4000-8000-000000000013', 2, 50, 'calificacion_5', '2026-10-02 12:27:00-03'),
('00000000-0000-4000-8000-000000000003', 3, 150, 'viaje', '2026-10-05 22:47:00-03'),
('00000000-0000-4000-8000-000000000013', 3, 100, 'viaje', '2026-10-05 22:47:00-03'),
('00000000-0000-4000-8000-000000000003', 4, 150, 'viaje', '2026-10-07 16:20:00-03'),
('00000000-0000-4000-8000-000000000012', 4, 100, 'viaje', '2026-10-07 16:20:00-03'),
('00000000-0000-4000-8000-000000000012', 4, 50, 'calificacion_5', '2026-10-07 16:25:00-03'),
('00000000-0000-4000-8000-000000000012', 5, 100, 'viaje', '2026-10-09 18:54:00-03'),
('00000000-0000-4000-8000-000000000007', 7, 150, 'viaje', '2026-10-13 22:26:00-03'),
('00000000-0000-4000-8000-000000000011', 7, 100, 'viaje', '2026-10-13 22:26:00-03'),
('00000000-0000-4000-8000-000000000012', 8, 100, 'viaje', '2026-10-14 13:58:00-03'),
('00000000-0000-4000-8000-000000000012', 9, 100, 'viaje', '2026-10-14 23:09:00-03'),
('00000000-0000-4000-8000-000000000003', 10, 150, 'viaje', '2026-10-15 11:58:00-03'),
('00000000-0000-4000-8000-000000000011', 10, 100, 'viaje', '2026-10-15 11:58:00-03'),
('00000000-0000-4000-8000-000000000003', 12, 150, 'viaje', '2026-10-15 22:57:00-03'),
('00000000-0000-4000-8000-000000000012', 12, 100, 'viaje', '2026-10-15 22:57:00-03'),
('00000000-0000-4000-8000-000000000003', 14, 150, 'viaje', '2026-10-18 08:43:00-03'),
('00000000-0000-4000-8000-000000000011', 14, 100, 'viaje', '2026-10-18 08:43:00-03'),
('00000000-0000-4000-8000-000000000012', 15, 100, 'viaje', '2026-10-18 16:42:00-03'),
('00000000-0000-4000-8000-000000000005', 16, 150, 'viaje', '2026-10-18 19:58:00-03'),
('00000000-0000-4000-8000-000000000011', 16, 100, 'viaje', '2026-10-18 19:58:00-03'),
('00000000-0000-4000-8000-000000000005', 17, 150, 'viaje', '2026-10-18 23:00:00-03'),
('00000000-0000-4000-8000-000000000012', 17, 100, 'viaje', '2026-10-18 23:00:00-03'),
('00000000-0000-4000-8000-000000000012', 17, 50, 'calificacion_5', '2026-10-18 23:05:00-03'),
('00000000-0000-4000-8000-000000000005', 18, 150, 'viaje', '2026-10-19 14:31:00-03'),
('00000000-0000-4000-8000-000000000011', 18, 100, 'viaje', '2026-10-19 14:31:00-03'),
('00000000-0000-4000-8000-000000000011', 18, 50, 'calificacion_5', '2026-10-19 14:36:00-03'),
('00000000-0000-4000-8000-000000000007', 20, 150, 'viaje', '2026-10-22 23:01:00-03'),
('00000000-0000-4000-8000-000000000012', 20, 100, 'viaje', '2026-10-22 23:01:00-03'),
('00000000-0000-4000-8000-000000000003', 21, 150, 'viaje', '2026-10-23 21:03:00-03'),
('00000000-0000-4000-8000-000000000003', 21, -1000, 'canje_viaje_gratis', '2026-10-23 21:03:00-03'),
('00000000-0000-4000-8000-000000000012', 21, 100, 'viaje', '2026-10-23 21:03:00-03'),
('00000000-0000-4000-8000-000000000011', 22, 100, 'viaje', '2026-10-24 17:36:00-03'),
('00000000-0000-4000-8000-000000000008', 23, 150, 'viaje', '2026-10-26 19:37:00-03'),
('00000000-0000-4000-8000-000000000011', 23, 100, 'viaje', '2026-10-26 19:37:00-03'),
('00000000-0000-4000-8000-000000000011', 24, 100, 'viaje', '2026-10-26 23:08:00-03'),
('00000000-0000-4000-8000-000000000006', 25, 150, 'viaje', '2026-10-27 08:27:00-03'),
('00000000-0000-4000-8000-000000000011', 25, 100, 'viaje', '2026-10-27 08:27:00-03'),
('00000000-0000-4000-8000-000000000011', 25, 50, 'calificacion_5', '2026-10-27 08:32:00-03');

INSERT INTO auditoria (usuario_id, accion, detalle, creado_en) VALUES
('00000000-0000-4000-8000-000000000001', 'aprobar_conductor', 'conductor 1 aprobado', '2026-09-15 15:30:00-03'),
('00000000-0000-4000-8000-000000000001', 'aprobar_conductor', 'conductor 2 aprobado', '2026-09-16 11:10:00-03'),
('00000000-0000-4000-8000-000000000001', 'aprobar_conductor', 'conductor 3 aprobado', '2026-09-17 16:45:00-03'),
('00000000-0000-4000-8000-000000000001', 'revisar_documento', 'documento 25 rechazado: Foto borrosa', '2026-10-26 11:00:00-03'),
('00000000-0000-4000-8000-000000000002', 'guardar_tarifa', 'precio_100m=300', '2026-09-20 09:00:00-03');

SELECT setval('marca_id_seq',4); SELECT setval('modelo_id_seq',5); SELECT setval('conductor_id_seq',4); SELECT setval('vehiculo_id_seq',4);
SELECT setval('documento_id_seq',26); SELECT setval('viaje_id_seq',27); SELECT setval('seq_viaje',151);
SELECT setval(pg_get_serial_sequence('cancelacion','id'), (SELECT MAX(id) FROM cancelacion)); SELECT setval(pg_get_serial_sequence('calificacion','id'), (SELECT MAX(id) FROM calificacion));
SELECT setval(pg_get_serial_sequence('auditoria','id'), (SELECT MAX(id) FROM auditoria));

-- ============================================================
-- BellaVista Remis — VISTAS, FUNCIONES Y TRIGGER (ejecutar después de 02_datos.sql)
-- ============================================================

-- Vista: detalle de cada viaje con todos los datos ya unidos
CREATE VIEW vw_viajes_detalle AS
SELECT v.id, v.codigo, v.creado_en, e.codigo AS estado,
       s.nombre || ' ' || s.apellido AS solicitante, r.nombre AS rol_solicitante,
       cu.nombre || ' ' || cu.apellido AS chofer,
       v.origen_direccion, v.destino_direccion, v.distancia_m, v.tarifa, mp.nombre AS medio_pago
FROM viaje v
JOIN estado_viaje e ON e.id = v.estado_id
JOIN usuario s ON s.id = v.solicitante_id
JOIN rol r ON r.id = s.rol_id
LEFT JOIN conductor c ON c.id = v.conductor_id
LEFT JOIN usuario cu ON cu.id = c.usuario_id
LEFT JOIN medio_pago mp ON mp.id = v.medio_pago_id;

-- Vista: un chofer está habilitado si fue aprobado y tiene TODA la documentación obligatoria aprobada y vigente
CREATE VIEW vw_habilitacion_choferes AS
SELECT c.id AS conductor_id, u.nombre || ' ' || u.apellido AS chofer, c.estado_aprobacion,
       (SELECT COUNT(*) FROM tipo_documento WHERE obligatorio) AS docs_obligatorios,
       (SELECT COUNT(*) FROM tipo_documento t JOIN documento d ON d.tipo_documento_id = t.id AND d.conductor_id = c.id
         WHERE t.obligatorio AND d.estado = 'aprobado' AND (NOT t.pide_vencimiento OR d.vence_el >= current_date)) AS docs_vigentes,
       (c.estado_aprobacion = 'aprobado' AND NOT EXISTS (
          SELECT 1 FROM tipo_documento t WHERE t.obligatorio AND NOT EXISTS (
            SELECT 1 FROM documento d WHERE d.conductor_id = c.id AND d.tipo_documento_id = t.id AND d.estado = 'aprobado'
              AND (NOT t.pide_vencimiento OR d.vence_el >= current_date)))) AS habilitado
FROM conductor c JOIN usuario u ON u.id = c.usuario_id;

-- Función: precio de un viaje = cuadras de 100 m (redondeando hacia arriba) x precio vigente, con la tarifa mínima como piso
CREATE FUNCTION calcular_tarifa(p_distancia_m int) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT GREATEST(CEIL(p_distancia_m / 100.0) * t.precio_100m, t.minima)
  FROM tarifa t ORDER BY t.vigente_desde DESC, t.id DESC LIMIT 1 $$;

-- Función: saldo que corresponde según los movimientos (cargas menos viajes pagados con billetera)
CREATE FUNCTION saldo_calculado(p_usuario uuid) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE(SUM(CASE WHEN m.tipo = 'carga' THEN m.monto
                           WHEN m.tipo = 'viaje' AND mp.nombre = 'Billetera' THEN -m.monto ELSE 0 END), 0)
  FROM movimiento_billetera m JOIN medio_pago mp ON mp.id = m.medio_pago_id WHERE m.usuario_id = p_usuario $$;

-- Función: finaliza un viaje en curso, lo cobra (billetera, efectivo o viaje gratis) y reparte los puntos
CREATE FUNCTION finalizar_viaje(p_viaje bigint) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v viaje%ROWTYPE; es_pasajero boolean; sal numeric; medio text; mid smallint;
BEGIN
  SELECT * INTO v FROM viaje WHERE id = p_viaje FOR UPDATE;
  IF NOT FOUND OR v.estado_id <> (SELECT id FROM estado_viaje WHERE codigo = 'curso') THEN
    RAISE EXCEPTION 'El viaje % no está en curso.', p_viaje; END IF;
  es_pasajero := EXISTS (SELECT 1 FROM pasajero WHERE usuario_id = v.solicitante_id);
  IF es_pasajero THEN
    SELECT saldo INTO sal FROM pasajero WHERE usuario_id = v.solicitante_id FOR UPDATE;
    IF v.medio_pago_id = (SELECT id FROM medio_pago WHERE nombre = 'Puntos') THEN medio := 'Puntos';
    ELSIF sal >= v.tarifa THEN medio := 'Billetera'; UPDATE pasajero SET saldo = saldo - v.tarifa WHERE usuario_id = v.solicitante_id;
    ELSE medio := 'Efectivo'; END IF;
    SELECT id INTO mid FROM medio_pago WHERE nombre = medio;
    INSERT INTO movimiento_billetera (usuario_id, viaje_id, tipo, monto, detalle, medio_pago_id)
    VALUES (v.solicitante_id, p_viaje, 'viaje', CASE WHEN medio = 'Puntos' THEN 0 ELSE v.tarifa END, 'Viaje a ' || v.destino_direccion, mid);
    UPDATE pasajero SET puntos = puntos + cfg_puntos_pasajero() WHERE usuario_id = v.solicitante_id;
    INSERT INTO movimiento_puntos (usuario_id, viaje_id, puntos, motivo) VALUES (v.solicitante_id, p_viaje, cfg_puntos_pasajero(), 'viaje');
    IF (SELECT puntos FROM pasajero WHERE usuario_id = v.solicitante_id) >= 1000 THEN
      UPDATE pasajero SET puntos = puntos - 1000, viajes_gratis = viajes_gratis + 1 WHERE usuario_id = v.solicitante_id;
      INSERT INTO movimiento_puntos (usuario_id, viaje_id, puntos, motivo) VALUES (v.solicitante_id, p_viaje, -1000, 'canje_viaje_gratis');
    END IF;
  ELSE medio := 'Efectivo'; mid := (SELECT id FROM medio_pago WHERE nombre = 'Efectivo'); END IF;
  UPDATE viaje SET estado_id = (SELECT id FROM estado_viaje WHERE codigo = 'finalizado'), medio_pago_id = mid, finalizado_en = now() WHERE id = p_viaje;
  UPDATE conductor SET puntos = puntos + 100 WHERE id = v.conductor_id;
  INSERT INTO movimiento_puntos (usuario_id, viaje_id, puntos, motivo)
  SELECT usuario_id, p_viaje, 100, 'viaje' FROM conductor WHERE id = v.conductor_id;
  RETURN medio;
END $$;

CREATE FUNCTION cfg_puntos_pasajero() RETURNS int LANGUAGE sql STABLE AS $$
  SELECT valor::int FROM configuracion WHERE clave = 'puntos_pasajero_por_viaje' $$;

-- Disparador: cada vez que cambia el estado de aprobación de un chofer queda registrado en la auditoría
CREATE FUNCTION trg_conductor_estado() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.estado_aprobacion IS DISTINCT FROM OLD.estado_aprobacion THEN
    INSERT INTO auditoria (accion, detalle)
    VALUES ('cambio_estado_conductor', 'conductor ' || NEW.id || ': ' || OLD.estado_aprobacion || ' -> ' || NEW.estado_aprobacion);
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_conductor_estado AFTER UPDATE ON conductor FOR EACH ROW EXECUTE FUNCTION trg_conductor_estado();

-- ============================================================
-- BellaVista Remis — CONSULTAS (ejecutar después de 01, 02 y 03)
-- Cada consulta tiene: número, título y para qué sirve.
-- ============================================================

-- ###SECCION|A. Consultas simples (SELECT, WHERE, ORDER BY, LIKE, BETWEEN, IN, IS NULL, LIMIT)

-- ##A1|Roles del sistema|Lista los tipos de cuenta que existen.
SELECT * FROM rol ORDER BY id;

-- ##A2|Usuarios activos ordenados por apellido|Sirve para el listado general de cuentas.
SELECT nombre, apellido, email FROM usuario WHERE estado = 'activo' ORDER BY apellido, nombre;

-- ##A3|Pasajeros con saldo mayor a $2.000|Filtra por una condición numérica y ordena de mayor a menor.
SELECT u.nombre, u.apellido, p.saldo
FROM pasajero p JOIN usuario u ON u.id = p.usuario_id
WHERE p.saldo > 2000 ORDER BY p.saldo DESC;

-- ##A4|Búsqueda de usuarios por apellido (LIKE)|Apellidos que empiezan con G o terminan en "ez".
SELECT nombre, apellido FROM usuario WHERE apellido ILIKE 'g%' OR apellido ILIKE '%ez' ORDER BY apellido;

-- ##A5|Viajes de la segunda quincena de octubre (BETWEEN)|Filtra por rango de fechas.
SELECT codigo, creado_en::date AS fecha, tarifa
FROM viaje WHERE creado_en BETWEEN '2026-10-15' AND '2026-10-28 23:59:59' ORDER BY creado_en;

-- ##A6|Viajes sin chofer asignado (IS NULL)|Son los pedidos que todavía esperan que un chofer los acepte, o los programados.
SELECT v.codigo, e.nombre AS estado, v.origen_direccion, v.destino_direccion
FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE v.conductor_id IS NULL;

-- ##A7|Marcas de autos registradas|Listado del catálogo de marcas.
SELECT nombre FROM marca ORDER BY nombre;

-- ##A8|Los 5 viajes más caros (LIMIT)|Ordena por tarifa y se queda con los primeros cinco.
SELECT codigo, destino_direccion, distancia_m, tarifa FROM viaje ORDER BY tarifa DESC LIMIT 5;

-- ##A9|Choferes pendientes o rechazados (IN)|Cuentas de chofer que todavía no pueden trabajar.
SELECT c.id, u.nombre, u.apellido, c.estado_aprobacion
FROM conductor c JOIN usuario u ON u.id = c.usuario_id WHERE c.estado_aprobacion IN ('pendiente', 'rechazado');

-- ##A10|Documentos que se le exigen al chofer|Lee el catálogo de tipos de documento obligatorios.
SELECT nombre, aplica_a, pide_vencimiento FROM tipo_documento WHERE obligatorio ORDER BY id;

-- ###SECCION|B. Consultas con JOIN (varias tablas relacionadas)

-- ##B1|Ficha completa de cada chofer con su vehículo|Une conductor, usuario, vehículo, modelo, marca y tipo de patente (6 tablas).
SELECT u.nombre || ' ' || u.apellido AS chofer, c.estado_aprobacion AS estado,
       ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.color, v.patente, tp.nombre AS tipo_patente
FROM conductor c
JOIN usuario u ON u.id = c.usuario_id
JOIN vehiculo v ON v.conductor_id = c.id
JOIN modelo mo ON mo.id = v.modelo_id
JOIN marca ma ON ma.id = mo.marca_id
JOIN tipo_patente tp ON tp.id = v.tipo_patente_id
ORDER BY c.id;

-- ##B2|Viajes finalizados con pasajero, chofer y forma de pago|Usa la vista vw_viajes_detalle (ya trae todo unido).
SELECT codigo, creado_en::date AS fecha, solicitante, chofer, destino_direccion AS destino, tarifa, medio_pago
FROM vw_viajes_detalle WHERE estado = 'finalizado' ORDER BY creado_en LIMIT 12;

-- ##B3|Choferes que no hicieron ningún viaje (LEFT JOIN)|Detecta choferes sin actividad.
SELECT u.nombre || ' ' || u.apellido AS chofer, c.estado_aprobacion
FROM conductor c JOIN usuario u ON u.id = c.usuario_id
LEFT JOIN viaje v ON v.conductor_id = c.id
WHERE v.id IS NULL;

-- ##B4|Documentación de cada chofer|Une chofer, tipo de documento y documento, con su vencimiento y estado de revisión.
SELECT u.nombre AS chofer, t.nombre AS documento, d.numero, d.entidad, d.vence_el, d.estado
FROM documento d
JOIN conductor c ON c.id = d.conductor_id
JOIN usuario u ON u.id = c.usuario_id
JOIN tipo_documento t ON t.id = d.tipo_documento_id
WHERE t.pide_vencimiento ORDER BY u.nombre, t.id;

-- ##B5|Movimientos de la billetera de María López|Historial de cargas y gastos con el medio de pago.
SELECT m.creado_en::date AS fecha, m.tipo, m.monto, mp.nombre AS medio, m.detalle
FROM movimiento_billetera m
JOIN medio_pago mp ON mp.id = m.medio_pago_id
JOIN usuario u ON u.id = m.usuario_id
WHERE u.nombre = 'María' AND u.apellido = 'López' ORDER BY m.creado_en;

-- ##B6|Cancelaciones y quién las hizo|Une cancelación, viaje, usuario y rol (muestra si canceló un pasajero o un chofer).
SELECT v.codigo, u.nombre || ' ' || u.apellido AS cancelo, r.nombre AS rol, c.motivo, c.creado_en::date AS fecha
FROM cancelacion c
JOIN viaje v ON v.id = c.viaje_id
JOIN usuario u ON u.id = c.usuario_id
JOIN rol r ON r.id = u.rol_id
ORDER BY c.creado_en;

-- ##B7|Choferes que rechazaron viajes (relación N a M)|La tabla viaje_rechazo une viajes con choferes.
SELECT u.nombre || ' ' || u.apellido AS chofer, v.codigo, v.destino_direccion AS destino
FROM viaje_rechazo vr
JOIN conductor c ON c.id = vr.conductor_id
JOIN usuario u ON u.id = c.usuario_id
JOIN viaje v ON v.id = vr.viaje_id
ORDER BY v.codigo;

-- ##B8|Viajes finalizados con su calificación (LEFT JOIN)|Muestra también los viajes que nadie calificó.
SELECT v.codigo, u.nombre AS chofer, COALESCE(k.estrellas::text, 'sin calificar') AS estrellas, k.comentario
FROM viaje v
JOIN estado_viaje e ON e.id = v.estado_id AND e.codigo = 'finalizado'
JOIN conductor c ON c.id = v.conductor_id
JOIN usuario u ON u.id = c.usuario_id
LEFT JOIN calificacion k ON k.viaje_id = v.id
ORDER BY v.codigo LIMIT 12;

-- ##B9|Pedidos hechos desde los supermercados|Muestra el comercio, el cliente que pidió y el destino.
SELECT co.nombre_local AS comercio, v.cliente_nombre AS cliente, v.destino_direccion AS destino, v.tarifa, e.nombre AS estado
FROM viaje v
JOIN comercio co ON co.usuario_id = v.solicitante_id
JOIN estado_viaje e ON e.id = v.estado_id
ORDER BY co.nombre_local, v.creado_en;

-- ##B10|Registro de auditoría con quién hizo cada acción|LEFT JOIN: algunas acciones las registra el sistema.
SELECT a.creado_en::date AS fecha, COALESCE(u.nombre || ' ' || u.apellido, '(sistema)') AS quien, a.accion, a.detalle
FROM auditoria a LEFT JOIN usuario u ON u.id = a.usuario_id ORDER BY a.id;

-- ###SECCION|C. Consultas de resumen (COUNT, SUM, AVG, MAX, GROUP BY, HAVING)

-- ##C1|Cantidad de viajes por estado|Cuenta los viajes agrupándolos por su estado.
SELECT e.nombre AS estado, COUNT(*) AS cantidad
FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id GROUP BY e.nombre ORDER BY cantidad DESC;

-- ##C2|Recaudación total y ticket promedio|Solo viajes finalizados y que no fueron gratis por puntos.
SELECT COUNT(*) AS viajes_cobrados, SUM(v.tarifa) AS recaudacion_total, ROUND(AVG(v.tarifa), 2) AS ticket_promedio
FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id JOIN medio_pago mp ON mp.id = v.medio_pago_id
WHERE e.codigo = 'finalizado' AND mp.nombre <> 'Puntos';

-- ##C3|Recaudación por semana|Agrupa por semana usando la fecha del viaje.
SELECT date_trunc('week', v.finalizado_en)::date AS semana_desde, COUNT(*) AS viajes, SUM(v.tarifa) AS recaudado
FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id JOIN medio_pago mp ON mp.id = v.medio_pago_id
WHERE e.codigo = 'finalizado' AND mp.nombre <> 'Puntos'
GROUP BY 1 ORDER BY 1;

-- ##C4|Ranking de choferes por cantidad de viajes|Usa la vista vw_ranking_choferes (viajes, ganado y calificación).
SELECT nombre, apellido, viajes_finalizados, ganado, calificacion, puntos FROM vw_ranking_choferes;

-- ##C5|Calificación promedio de cada chofer (HAVING)|Solo choferes con al menos 2 calificaciones.
SELECT u.nombre || ' ' || u.apellido AS chofer, ROUND(AVG(k.estrellas), 2) AS promedio, COUNT(*) AS calificaciones
FROM calificacion k
JOIN viaje v ON v.id = k.viaje_id
JOIN conductor c ON c.id = v.conductor_id
JOIN usuario u ON u.id = c.usuario_id
GROUP BY u.nombre, u.apellido HAVING COUNT(*) >= 2 ORDER BY promedio DESC;

-- ##C6|Los 3 pasajeros que más viajan|Cuenta viajes finalizados por pasajero.
SELECT u.nombre || ' ' || u.apellido AS pasajero, COUNT(*) AS viajes
FROM viaje v
JOIN estado_viaje e ON e.id = v.estado_id AND e.codigo = 'finalizado'
JOIN pasajero p ON p.usuario_id = v.solicitante_id
JOIN usuario u ON u.id = p.usuario_id
GROUP BY u.nombre, u.apellido ORDER BY viajes DESC, pasajero LIMIT 3;

-- ##C7|Gasto total de cada pasajero|Suma lo que pagó en viajes (billetera o efectivo); los viajes gratis no suman.
SELECT u.nombre || ' ' || u.apellido AS pasajero, COALESCE(SUM(m.monto), 0) AS gastado, COUNT(m.id) AS viajes
FROM pasajero p
JOIN usuario u ON u.id = p.usuario_id
LEFT JOIN movimiento_billetera m ON m.usuario_id = p.usuario_id AND m.tipo = 'viaje'
GROUP BY u.nombre, u.apellido ORDER BY gastado DESC;

-- ##C8|Viajes finalizados por forma de pago|Cuántos se pagaron con billetera, efectivo o puntos.
SELECT mp.nombre AS forma_de_pago, COUNT(*) AS viajes, SUM(v.tarifa) AS monto_tarifas
FROM viaje v JOIN medio_pago mp ON mp.id = v.medio_pago_id
JOIN estado_viaje e ON e.id = v.estado_id AND e.codigo = 'finalizado'
GROUP BY mp.nombre ORDER BY viajes DESC;

-- ##C9|Distancia total y promedio recorrida|En kilómetros, sobre los viajes finalizados.
SELECT ROUND(SUM(distancia_m) / 1000.0, 1) AS km_totales, ROUND(AVG(distancia_m) / 1000.0, 2) AS km_promedio, MAX(distancia_m) AS viaje_mas_largo_m
FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE e.codigo = 'finalizado';

-- ##C10|Cantidad de usuarios por tipo de cuenta|LEFT JOIN para mostrar también los roles sin usuarios.
SELECT r.nombre AS rol, COUNT(u.id) AS usuarios FROM rol r LEFT JOIN usuario u ON u.rol_id = r.id GROUP BY r.id, r.nombre ORDER BY r.id;

-- ##C11|Pedidos y recaudación por supermercado|Cuánto trae cada comercio.
SELECT co.nombre_local AS comercio, COUNT(*) AS pedidos, SUM(v.tarifa) FILTER (WHERE e.codigo = 'finalizado') AS recaudado
FROM viaje v JOIN comercio co ON co.usuario_id = v.solicitante_id JOIN estado_viaje e ON e.id = v.estado_id
GROUP BY co.nombre_local ORDER BY pedidos DESC;

-- ##C12|Viajes según la hora del día|Sirve para ver los horarios de más demanda.
SELECT EXTRACT(HOUR FROM creado_en)::int AS hora, COUNT(*) AS viajes FROM viaje GROUP BY 1 ORDER BY viajes DESC, hora LIMIT 6;

-- ##C13|Choferes con 6 viajes o más (HAVING)|Filtra el resultado ya agrupado.
SELECT u.nombre || ' ' || u.apellido AS chofer, COUNT(*) AS viajes
FROM viaje v JOIN conductor c ON c.id = v.conductor_id JOIN usuario u ON u.id = c.usuario_id
GROUP BY u.nombre, u.apellido HAVING COUNT(*) >= 6 ORDER BY viajes DESC;

-- ##C14|Resumen general del negocio (panel del super admin)|Una sola fila con los números principales.
SELECT
  (SELECT COUNT(*) FROM viaje) AS viajes_totales,
  (SELECT COUNT(*) FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE e.codigo = 'finalizado') AS finalizados,
  (SELECT COALESCE(SUM(v.tarifa), 0) FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id JOIN medio_pago m ON m.id = v.medio_pago_id
     WHERE e.codigo = 'finalizado' AND m.nombre <> 'Puntos') AS recaudacion,
  (SELECT SUM(saldo) FROM pasajero) AS saldo_en_billeteras,
  (SELECT COUNT(*) FROM conductor WHERE estado_aprobacion = 'pendiente') AS choferes_por_aprobar,
  (SELECT COUNT(*) FROM documento WHERE estado = 'pendiente') AS documentos_por_revisar,
  (SELECT SUM(viajes_gratis) FROM pasajero) AS viajes_gratis_sin_usar;

-- ###SECCION|D. Subconsultas (consultas dentro de consultas)

-- ##D1|Pasajeros con saldo mayor al promedio|Compara cada saldo contra el promedio de todos.
SELECT u.nombre, u.apellido, p.saldo
FROM pasajero p JOIN usuario u ON u.id = p.usuario_id
WHERE p.saldo > (SELECT AVG(saldo) FROM pasajero) ORDER BY p.saldo DESC;

-- ##D2|Viajes con tarifa mayor al promedio|Subconsulta que calcula el promedio general.
SELECT codigo, destino_direccion, tarifa FROM viaje
WHERE tarifa > (SELECT AVG(tarifa) FROM viaje) ORDER BY tarifa DESC;

-- ##D3|Pasajeros que nunca cancelaron un viaje (NOT EXISTS)|Devuelve los pasajeros sin ninguna cancelación.
SELECT u.nombre, u.apellido FROM pasajero p JOIN usuario u ON u.id = p.usuario_id
WHERE NOT EXISTS (SELECT 1 FROM cancelacion c WHERE c.usuario_id = p.usuario_id) ORDER BY u.apellido;

-- ##D4|Chofer que más recaudó (subconsulta con MAX)|Compara el total de cada chofer contra el máximo.
SELECT chofer, recaudado FROM (
  SELECT u.nombre || ' ' || u.apellido AS chofer, SUM(v.tarifa) AS recaudado
  FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id AND e.codigo = 'finalizado'
  JOIN conductor c ON c.id = v.conductor_id JOIN usuario u ON u.id = c.usuario_id GROUP BY u.nombre, u.apellido) t
WHERE recaudado = (SELECT MAX(recaudado) FROM (
  SELECT SUM(v.tarifa) AS recaudado FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id AND e.codigo = 'finalizado'
  WHERE v.conductor_id IS NOT NULL GROUP BY v.conductor_id) x);

-- ##D5|Viajes más caros que el promedio de su propio chofer (subconsulta correlacionada)|Cada fila se compara con el promedio de su chofer.
SELECT v.codigo, v.conductor_id AS chofer_id, v.tarifa
FROM viaje v
WHERE v.conductor_id IS NOT NULL AND v.tarifa > (SELECT AVG(v2.tarifa) FROM viaje v2 WHERE v2.conductor_id = v.conductor_id)
ORDER BY v.conductor_id, v.tarifa DESC LIMIT 10;

-- ##D6|Pasajeros con al menos un viaje cancelado (EXISTS)|Complementa a la consulta D3.
SELECT u.nombre, u.apellido FROM pasajero p JOIN usuario u ON u.id = p.usuario_id
WHERE EXISTS (SELECT 1 FROM cancelacion c WHERE c.usuario_id = p.usuario_id);

-- ##D7|Choferes que recibieron alguna calificación de 5 estrellas (IN)|Subconsulta que devuelve los choferes con 5 estrellas.
SELECT u.nombre, u.apellido FROM conductor c JOIN usuario u ON u.id = c.usuario_id
WHERE c.id IN (SELECT v.conductor_id FROM calificacion k JOIN viaje v ON v.id = k.viaje_id WHERE k.estrellas = 5) ORDER BY u.apellido;

-- ###SECCION|E. Documentación y habilitación de choferes

-- ##E1|Documentos vencidos|Documentos cuya fecha de vencimiento ya pasó.
SELECT u.nombre || ' ' || u.apellido AS chofer, t.nombre AS documento, d.vence_el, current_date - d.vence_el AS dias_vencido
FROM documento d JOIN conductor c ON c.id = d.conductor_id JOIN usuario u ON u.id = c.usuario_id JOIN tipo_documento t ON t.id = d.tipo_documento_id
WHERE t.pide_vencimiento AND d.vence_el < current_date;

-- ##E2|Documentos que vencen en los próximos 30 días|Sirve para avisar a los choferes antes de que queden inhabilitados.
SELECT u.nombre || ' ' || u.apellido AS chofer, t.nombre AS documento, d.vence_el, d.vence_el - current_date AS dias_restantes
FROM documento d JOIN conductor c ON c.id = d.conductor_id JOIN usuario u ON u.id = c.usuario_id JOIN tipo_documento t ON t.id = d.tipo_documento_id
WHERE t.pide_vencimiento AND d.vence_el BETWEEN current_date AND current_date + 30 ORDER BY d.vence_el;

-- ##E3|Documentos pendientes de revisión (cola del super admin)|Lo primero que revisa el dueño.
SELECT u.nombre || ' ' || u.apellido AS chofer, t.nombre AS documento, d.estado, d.observacion
FROM documento d JOIN conductor c ON c.id = d.conductor_id JOIN usuario u ON u.id = c.usuario_id JOIN tipo_documento t ON t.id = d.tipo_documento_id
WHERE d.estado <> 'aprobado' ORDER BY u.nombre, t.id;

-- ##E4|Documentos que le faltan cargar a cada chofer|CROSS JOIN de choferes por tipos obligatorios, y LEFT JOIN para ver cuáles no existen.
SELECT u.nombre || ' ' || u.apellido AS chofer, t.nombre AS documento_faltante
FROM conductor c JOIN usuario u ON u.id = c.usuario_id
CROSS JOIN tipo_documento t
LEFT JOIN documento d ON d.conductor_id = c.id AND d.tipo_documento_id = t.id
WHERE t.obligatorio AND d.id IS NULL ORDER BY u.nombre, t.id;

-- ##E5|Habilitación de los choferes (vista)|Aprobado + documentación obligatoria aprobada y vigente = puede recibir viajes.
SELECT chofer, estado_aprobacion, docs_obligatorios, docs_vigentes, habilitado FROM vw_habilitacion_choferes ORDER BY conductor_id;

-- ##E6|Choferes aprobados pero inhabilitados por documentación|El caso del seguro vencido.
SELECT chofer, docs_obligatorios, docs_vigentes FROM vw_habilitacion_choferes WHERE estado_aprobacion = 'aprobado' AND NOT habilitado;

-- ###SECCION|F. Billetera y puntos

-- ##F1|Control de integridad: saldo guardado contra saldo calculado|La diferencia tiene que ser 0 para todos los pasajeros.
SELECT u.nombre, p.saldo AS saldo_guardado, saldo_calculado(p.usuario_id) AS saldo_segun_movimientos,
       p.saldo - saldo_calculado(p.usuario_id) AS diferencia
FROM pasajero p JOIN usuario u ON u.id = p.usuario_id ORDER BY u.nombre;

-- ##F2|Puntos y viajes gratis de cada pasajero|Cuánto les falta para el próximo viaje gratis (meta: 1000 puntos).
SELECT u.nombre || ' ' || u.apellido AS pasajero, p.puntos, 1000 - p.puntos AS faltan_para_viaje_gratis, p.viajes_gratis
FROM pasajero p JOIN usuario u ON u.id = p.usuario_id ORDER BY p.puntos DESC;

-- ##F3|Historial de puntos de María López|Cada punto ganado y cada canje por un viaje gratis.
SELECT mp.creado_en::date AS fecha, mp.puntos, mp.motivo, v.codigo AS viaje
FROM movimiento_puntos mp JOIN usuario u ON u.id = mp.usuario_id LEFT JOIN viaje v ON v.id = mp.viaje_id
WHERE u.nombre = 'María' AND u.apellido = 'López' ORDER BY mp.creado_en;

-- ##F4|Puntos de los choferes: guardados contra el historial|Verifica que los contadores coinciden con los movimientos.
SELECT u.nombre || ' ' || u.apellido AS chofer, c.puntos AS puntos_guardados,
       COALESCE((SELECT SUM(puntos) FROM movimiento_puntos m WHERE m.usuario_id = c.usuario_id), 0) AS puntos_segun_historial
FROM conductor c JOIN usuario u ON u.id = c.usuario_id ORDER BY c.id;

-- ##F5|Cargas de dinero por medio de pago|Cuánto entró por Mercado Pago, Ualá, transferencia y tarjeta.
SELECT mp.nombre AS medio, COUNT(*) AS cargas, SUM(m.monto) AS total
FROM movimiento_billetera m JOIN medio_pago mp ON mp.id = m.medio_pago_id WHERE m.tipo = 'carga' GROUP BY mp.nombre ORDER BY total DESC;

-- ###SECCION|G. Funciones, disparador, transacciones y restricciones

-- ##G1|Cálculo de tarifa con la función calcular_tarifa()|Cuadras de 100 m x $300, con mínima de $1.200.
SELECT d AS distancia_m, CEIL(d / 100.0) AS cuadras, calcular_tarifa(d) AS tarifa
FROM (VALUES (50), (1000), (4213), (9000), (15200)) AS t(d);

-- ##G2|Finalizar un viaje en curso (transacción)|La función cobra, suma puntos y cierra el viaje. Se hace ROLLBACK para no alterar los datos de ejemplo.
BEGIN;
SELECT v.codigo, v.tarifa, finalizar_viaje(v.id) AS forma_de_pago
FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE e.codigo = 'curso';
SELECT v.codigo, e.nombre AS estado_ahora FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE v.codigo = 'BV-000150';
ROLLBACK;

-- ##G3|Aprobar un chofer y disparador de auditoría (UPDATE + TRIGGER)|Al cambiar el estado, el disparador anota la acción solo.
BEGIN;
UPDATE conductor SET estado_aprobacion = 'rechazado' WHERE id = 4;
SELECT accion, detalle FROM auditoria ORDER BY id DESC LIMIT 1;
ROLLBACK;

-- ##G4|Registrar un pasajero nuevo (INSERT)|Se crea el usuario y su billetera en cero.
BEGIN;
INSERT INTO usuario (id, rol_id, nombre, apellido, telefono, email) VALUES ('00000000-0000-4000-8000-000000000099', 1, 'Valeria', 'Núñez', '381 555 0199', 'valeria.nunez@gmail.com');
INSERT INTO pasajero (usuario_id) VALUES ('00000000-0000-4000-8000-000000000099');
SELECT u.nombre, u.apellido, r.nombre AS rol, p.saldo, p.puntos FROM usuario u JOIN rol r ON r.id = u.rol_id JOIN pasajero p ON p.usuario_id = u.id WHERE u.email = 'valeria.nunez@gmail.com';
ROLLBACK;

-- ##G5|Borrar un viaje cancelado (DELETE)|Al borrar el viaje se borran también sus cancelaciones (ON DELETE CASCADE).
BEGIN;
SELECT (SELECT COUNT(*) FROM cancelacion WHERE viaje_id = v.id) AS cancelaciones_antes, v.codigo FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE e.codigo = 'cancelado' ORDER BY v.id LIMIT 1;
DELETE FROM viaje WHERE id = (SELECT v.id FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE e.codigo = 'cancelado' ORDER BY v.id LIMIT 1);
SELECT COUNT(*) AS viajes_cancelados_ahora FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE e.codigo = 'cancelado';
ROLLBACK;

-- ##G6|Restricciones de la base de datos en acción|Intentos de cargar datos inválidos: la base los rechaza.
DO $$ BEGIN
  BEGIN INSERT INTO tarifa (precio_100m, minima) VALUES (-5, 1200);
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'Tarifa negativa -> RECHAZADA (CHECK): %', SQLERRM; END;
  BEGIN INSERT INTO vehiculo (conductor_id, modelo_id, tipo_patente_id, anio, color, patente) VALUES (1, 1, 1, 2020, 'Azul', 'AB123CD');
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'Patente repetida -> RECHAZADA (UNIQUE): %', SQLERRM; END;
  BEGIN INSERT INTO calificacion (viaje_id, estrellas) VALUES (1, 9);
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'Calificación de 9 estrellas -> RECHAZADA (CHECK): %', SQLERRM; END;
  BEGIN INSERT INTO viaje (codigo, solicitante_id, estado_id, origen_direccion, destino_direccion, tarifa) VALUES ('BV-X', '00000000-0000-4000-8000-000000000777', 1, 'a', 'b', 100);
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'Viaje de un usuario inexistente -> RECHAZADO (FOREIGN KEY): %', SQLERRM; END;
END $$;
