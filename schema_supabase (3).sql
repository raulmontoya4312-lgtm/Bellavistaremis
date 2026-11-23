-- ============================================================
-- BellaVista Remis — Esquema para Supabase (PostgreSQL 14+)
-- Normalizado hasta 3FN. Ver docs/BASE-DE-DATOS.md
-- USO: pegar COMPLETO en Supabase > SQL Editor y ejecutar una sola vez.
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
  id            UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,  -- mismo id que el login de Supabase
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
-- FUNCIONES AUXILIARES (no se llaman desde la app)
-- ============================================================
CREATE FUNCTION cfg(k text) RETURNS int LANGUAGE sql STABLE SET search_path = public
AS $$ SELECT valor::int FROM configuracion WHERE clave = k $$;

CREATE FUNCTION es_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM usuario u JOIN rol r ON r.id = u.rol_id WHERE u.id = auth.uid() AND r.nombre IN ('admin','superadmin') AND u.estado = 'activo') $$;

CREATE FUNCTION es_superadmin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM usuario u JOIN rol r ON r.id = u.rol_id WHERE u.id = auth.uid() AND r.nombre = 'superadmin' AND u.estado = 'activo') $$;

CREATE FUNCTION auditar(a text, d text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ INSERT INTO auditoria(usuario_id, accion, detalle) VALUES (auth.uid(), a, d) $$;

CREATE FUNCTION mi_rol() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT r.nombre FROM usuario u JOIN rol r ON r.id = u.rol_id WHERE u.id = auth.uid() AND u.estado = 'activo' $$;

-- Habilitado = aprobado por el super admin Y con toda la documentación obligatoria aprobada y no vencida
CREATE FUNCTION conductor_habilitado(c int) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM conductor WHERE id = c AND estado_aprobacion = 'aprobado')
      AND NOT EXISTS (SELECT 1 FROM tipo_documento t WHERE t.obligatorio AND NOT EXISTS (
            SELECT 1 FROM documento d WHERE d.conductor_id = c AND d.tipo_documento_id = t.id AND d.estado = 'aprobado'
              AND (NOT t.pide_vencimiento OR d.vence_el >= current_date))) $$;

CREATE FUNCTION mi_conductor() RETURNS int LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT c.id FROM conductor c JOIN usuario u ON u.id = c.usuario_id
      WHERE c.usuario_id = auth.uid() AND u.estado = 'activo' AND conductor_habilitado(c.id) $$;

CREATE FUNCTION rating_conductor(c int) RETURNS numeric LANGUAGE sql STABLE SET search_path = public
AS $$ SELECT COALESCE((SELECT promedio FROM vw_calificacion_conductor WHERE conductor_id = c), 0) $$;

CREATE FUNCTION vehiculo_json(c int) RETURNS jsonb LANGUAGE sql STABLE SET search_path = public
AS $$ SELECT jsonb_build_object('marca', ma.nombre, 'modelo', mo.nombre, 'color', v.color, 'patente', v.patente)
      FROM vehiculo v JOIN modelo mo ON mo.id = v.modelo_id JOIN marca ma ON ma.id = mo.marca_id
      WHERE v.conductor_id = c LIMIT 1 $$;

CREATE FUNCTION imagen_valida(t text) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = public
AS $$ SELECT t IS NULL OR (length(t) < 3000000 AND t ~ '^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$') $$;

CREATE FUNCTION puntos_pasajero(u uuid, n int, v bigint) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE meta int := cfg('meta_puntos_pasajero'); tot int;
BEGIN
  INSERT INTO movimiento_puntos(usuario_id, viaje_id, puntos, motivo) VALUES (u, v, n, 'viaje');
  UPDATE pasajero SET puntos = puntos + n WHERE usuario_id = u RETURNING puntos INTO tot;
  WHILE tot >= meta LOOP
    tot := tot - meta;
    UPDATE pasajero SET puntos = tot, viajes_gratis = viajes_gratis + 1 WHERE usuario_id = u;
    INSERT INTO movimiento_puntos(usuario_id, viaje_id, puntos, motivo) VALUES (u, v, -meta, 'canje_viaje_gratis');
  END LOOP;
END $$;

CREATE FUNCTION puntos_conductor(c int, n int, v bigint, mot text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE meta int := cfg('meta_puntos_conductor'); tot int; uid_ uuid;
BEGIN
  SELECT usuario_id INTO uid_ FROM conductor WHERE id = c;
  INSERT INTO movimiento_puntos(usuario_id, viaje_id, puntos, motivo) VALUES (uid_, v, n, mot);
  UPDATE conductor SET puntos = puntos + n WHERE id = c RETURNING puntos INTO tot;
  WHILE tot >= meta LOOP
    tot := tot - meta;
    UPDATE conductor SET puntos = tot, bonos = bonos + 1 WHERE id = c;
    INSERT INTO movimiento_puntos(usuario_id, viaje_id, puntos, motivo) VALUES (uid_, v, -meta, 'canje_bono');
  END LOOP;
END $$;

-- ============================================================
-- FUNCIONES DE LA APP (la app solo escribe a través de ellas)
-- ============================================================
CREATE FUNCTION registrar_perfil(p jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t text := p->>'tipo'; me uuid := auth.uid(); mar int; mo int; cond int;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Necesitás iniciar sesión.'; END IF;
  IF t NOT IN ('pasajero','comercio','conductor') THEN RAISE EXCEPTION 'Tipo de cuenta inválido.'; END IF;
  IF NOT imagen_valida(p->>'foto') THEN RAISE EXCEPTION 'La foto no es una imagen válida.'; END IF;
  INSERT INTO usuario(id, rol_id, nombre, apellido, dni, telefono, email, foto)
  VALUES (me, (SELECT id FROM rol WHERE nombre = t), trim(p->>'nombre'), COALESCE(trim(p->>'apellido'), ''),
          p->>'dni', trim(p->>'telefono'), (SELECT email FROM auth.users WHERE id = me), p->>'foto');
  IF t = 'pasajero' THEN
    INSERT INTO pasajero(usuario_id) VALUES (me);
  ELSIF t = 'comercio' THEN
    INSERT INTO comercio(usuario_id, nombre_local, direccion) VALUES (me, trim(p->>'nombre'), trim(p->>'direccion'));
  ELSE
    INSERT INTO conductor(usuario_id, licencia) VALUES (me, trim(p->>'licencia')) RETURNING id INTO cond;
    INSERT INTO marca(nombre) VALUES (initcap(trim(p->>'marca'))) ON CONFLICT (nombre) DO UPDATE SET nombre = EXCLUDED.nombre RETURNING id INTO mar;
    INSERT INTO modelo(marca_id, nombre) VALUES (mar, initcap(trim(p->>'modelo'))) ON CONFLICT (marca_id, nombre) DO UPDATE SET nombre = EXCLUDED.nombre RETURNING id INTO mo;
    INSERT INTO vehiculo(conductor_id, modelo_id, tipo_patente_id, anio, asientos, color, patente)
    VALUES (cond, mo, (p->>'tipo_patente_id')::smallint, (p->>'anio')::smallint, COALESCE((p->>'asientos')::smallint, 4),
            initcap(trim(p->>'color')), upper(replace(trim(p->>'patente'), ' ', '')));
  END IF;
END $$;

CREATE FUNCTION mi_perfil() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('id', u.id, 'rol', r.nombre, 'nombre', u.nombre, 'apellido', u.apellido, 'telefono', u.telefono,
    'email', u.email, 'foto', u.foto, 'estado', u.estado, 'saldo', pa.saldo, 'puntos', pa.puntos, 'viajes_gratis', pa.viajes_gratis,
    'direccion', co.direccion,
    'conductor', CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('id', c.id, 'licencia', c.licencia,
       'estado', c.estado_aprobacion, 'disponible', c.disponible, 'puntos', c.puntos, 'bonos', c.bonos,
       'rating', rating_conductor(c.id), 'vehiculo', vehiculo_json(c.id)) END)
  FROM usuario u JOIN rol r ON r.id = u.rol_id
  LEFT JOIN pasajero pa ON pa.usuario_id = u.id LEFT JOIN comercio co ON co.usuario_id = u.id LEFT JOIN conductor c ON c.usuario_id = u.id
  WHERE u.id = auth.uid() $$;

CREATE FUNCTION tarifa_vigente() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT to_jsonb(t) FROM tarifa t ORDER BY vigente_desde DESC, id DESC LIMIT 1 $$;

CREATE FUNCTION mis_viajes() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(t.j ORDER BY t.creado_en DESC), '[]'::jsonb) FROM (
    SELECT v.creado_en, jsonb_build_object('id', v.id, 'codigo', v.codigo, 'estado', e.codigo,
      'solicitante', jsonb_build_object('id', s.id, 'nombre', s.nombre, 'apellido', s.apellido, 'telefono', s.telefono, 'rol', sr.nombre),
      'cliente_nombre', v.cliente_nombre, 'cliente_telefono', v.cliente_telefono,
      'conductor', CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('id', c.id, 'usuario_id', cu.id, 'nombre', cu.nombre,
         'apellido', cu.apellido, 'foto', cu.foto, 'rating', rating_conductor(c.id), 'vehiculo', vehiculo_json(c.id)) END,
      'origen_direccion', v.origen_direccion, 'origen_lat', v.origen_lat, 'origen_lng', v.origen_lng,
      'destino_direccion', v.destino_direccion, 'destino_lat', v.destino_lat, 'destino_lng', v.destino_lng,
      'distancia_m', v.distancia_m, 'cantidad_pasajeros', v.cantidad_pasajeros, 'observaciones', v.observaciones,
      'tarifa', v.tarifa, 'medio_pago', mp.nombre, 'programado_para', v.programado_para, 'creado_en', v.creado_en,
      'finalizado_en', v.finalizado_en, 'calificado', EXISTS (SELECT 1 FROM calificacion k WHERE k.viaje_id = v.id)) AS j
    FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id
    JOIN usuario s ON s.id = v.solicitante_id JOIN rol sr ON sr.id = s.rol_id
    LEFT JOIN conductor c ON c.id = v.conductor_id LEFT JOIN usuario cu ON cu.id = c.usuario_id
    LEFT JOIN medio_pago mp ON mp.id = v.medio_pago_id
    WHERE es_admin() OR v.solicitante_id = auth.uid() OR v.conductor_id = mi_conductor()
       OR (mi_conductor() IS NOT NULL AND e.codigo = 'buscando'
           AND NOT EXISTS (SELECT 1 FROM viaje_rechazo rr WHERE rr.viaje_id = v.id AND rr.conductor_id = mi_conductor()))
    ORDER BY v.creado_en DESC LIMIT 300) t $$;

CREATE FUNCTION mis_movimientos() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', m.id, 'tipo', m.tipo, 'monto', m.monto, 'detalle', m.detalle,
         'medio', mp.nombre, 'creado_en', m.creado_en) ORDER BY m.id DESC), '[]'::jsonb)
  FROM movimiento_billetera m JOIN medio_pago mp ON mp.id = m.medio_pago_id WHERE m.usuario_id = auth.uid() $$;

CREATE FUNCTION pedir_viaje(p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE rol_ text := mi_rol(); tf tarifa%ROWTYPE; dist int := NULLIF(p->>'distancia_m','')::int; monto numeric;
        gratis boolean := false; prog timestamptz := NULLIF(p->>'programado_para','')::timestamptz; nid bigint; cod text;
BEGIN
  IF rol_ IS NULL OR rol_ NOT IN ('pasajero','comercio') THEN RAISE EXCEPTION 'Solo pasajeros y comercios pueden pedir viajes.'; END IF;
  SELECT * INTO tf FROM tarifa ORDER BY vigente_desde DESC, id DESC LIMIT 1;
  IF dist IS NOT NULL THEN monto := GREATEST(CEIL(dist / 100.0) * tf.precio_100m, tf.minima);        -- el precio lo calcula el servidor
  ELSE monto := LEAST(GREATEST(COALESCE((p->>'tarifa_estimada')::numeric, tf.minima), tf.minima), 30000); END IF;
  IF rol_ = 'pasajero' AND prog IS NULL THEN
    UPDATE pasajero SET viajes_gratis = viajes_gratis - 1 WHERE usuario_id = auth.uid() AND viajes_gratis > 0;
    gratis := FOUND;
  END IF;
  cod := 'BV-' || lpad(nextval('seq_viaje')::text, 6, '0');
  INSERT INTO viaje(codigo, solicitante_id, estado_id, cliente_nombre, cliente_telefono, origen_direccion, origen_lat, origen_lng,
      destino_direccion, destino_lat, destino_lng, distancia_m, cantidad_pasajeros, observaciones, tarifa, medio_pago_id, programado_para)
  VALUES (cod, auth.uid(), (SELECT id FROM estado_viaje WHERE codigo = CASE WHEN prog IS NULL THEN 'buscando' ELSE 'programado' END),
      p->>'cliente_nombre', p->>'cliente_telefono', trim(p->>'origen_direccion'), (p->>'origen_lat')::numeric, (p->>'origen_lng')::numeric,
      trim(p->>'destino_direccion'), (p->>'destino_lat')::numeric, (p->>'destino_lng')::numeric, dist,
      COALESCE((p->>'cantidad_pasajeros')::int, 1), p->>'observaciones', monto,
      CASE WHEN gratis THEN (SELECT id FROM medio_pago WHERE nombre = 'Puntos') END, prog)
  RETURNING id INTO nid;
  RETURN jsonb_build_object('id', nid, 'codigo', cod, 'tarifa', monto, 'gratis', gratis);
END $$;

CREATE FUNCTION aceptar_viaje(vid bigint) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c int := mi_conductor();
BEGIN
  IF c IS NULL THEN RAISE EXCEPTION 'Tu cuenta no está habilitada: falta aprobación o hay documentación vencida.'; END IF;
  IF EXISTS (SELECT 1 FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id WHERE v.conductor_id = c AND e.codigo IN ('asignado','camino','llego','curso'))
    THEN RAISE EXCEPTION 'Terminá tu viaje actual antes de aceptar otro.'; END IF;
  UPDATE viaje SET conductor_id = c, estado_id = (SELECT id FROM estado_viaje WHERE codigo = 'asignado')
  WHERE id = vid AND estado_id = (SELECT id FROM estado_viaje WHERE codigo = 'buscando')
    AND NOT EXISTS (SELECT 1 FROM viaje_rechazo WHERE viaje_id = vid AND conductor_id = c);
  IF NOT FOUND THEN RAISE EXCEPTION 'Esta solicitud ya no está disponible.'; END IF;
END $$;

CREATE FUNCTION rechazar_viaje(vid bigint) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF mi_conductor() IS NULL THEN RAISE EXCEPTION 'Tu cuenta no está habilitada: falta aprobación o hay documentación vencida.'; END IF;
  INSERT INTO viaje_rechazo(viaje_id, conductor_id) VALUES (vid, mi_conductor()) ON CONFLICT DO NOTHING;
END $$;

CREATE FUNCTION avanzar_viaje(vid bigint, nuevo text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v viaje%ROWTYPE; actual text; rol_s text; sal numeric; medio text; mid smallint;
BEGIN
  SELECT * INTO v FROM viaje WHERE id = vid FOR UPDATE;
  IF NOT FOUND OR v.conductor_id IS DISTINCT FROM mi_conductor() THEN RAISE EXCEPTION 'Este viaje no es tuyo.'; END IF;
  SELECT codigo INTO actual FROM estado_viaje WHERE id = v.estado_id;
  IF (actual, nuevo) NOT IN (('asignado','camino'),('camino','llego'),('llego','curso'),('curso','finalizado'))
    THEN RAISE EXCEPTION 'Cambio de estado no permitido (% a %).', actual, nuevo; END IF;
  UPDATE viaje SET estado_id = (SELECT id FROM estado_viaje WHERE codigo = nuevo) WHERE id = vid;
  IF nuevo <> 'finalizado' THEN RETURN jsonb_build_object('pago', NULL); END IF;

  SELECT r.nombre INTO rol_s FROM usuario u JOIN rol r ON r.id = u.rol_id WHERE u.id = v.solicitante_id;
  IF rol_s = 'pasajero' THEN
    SELECT saldo INTO sal FROM pasajero WHERE usuario_id = v.solicitante_id FOR UPDATE;
    IF v.medio_pago_id = (SELECT id FROM medio_pago WHERE nombre = 'Puntos') THEN medio := 'Puntos';
    ELSIF sal >= v.tarifa THEN medio := 'Billetera'; UPDATE pasajero SET saldo = saldo - v.tarifa WHERE usuario_id = v.solicitante_id;
    ELSE medio := 'Efectivo'; END IF;
    SELECT id INTO mid FROM medio_pago WHERE nombre = medio;
    INSERT INTO movimiento_billetera(usuario_id, viaje_id, tipo, monto, detalle, medio_pago_id)
    VALUES (v.solicitante_id, vid, 'viaje', CASE WHEN medio = 'Puntos' THEN 0 ELSE v.tarifa END,
            'Viaje a ' || v.destino_direccion || CASE WHEN medio = 'Puntos' THEN ' (viaje gratis)' ELSE '' END, mid);
    PERFORM puntos_pasajero(v.solicitante_id, cfg('puntos_pasajero_por_viaje'), vid);
  ELSE medio := 'Efectivo'; mid := (SELECT id FROM medio_pago WHERE nombre = medio); END IF;
  UPDATE viaje SET medio_pago_id = mid, finalizado_en = now() WHERE id = vid;
  PERFORM puntos_conductor(v.conductor_id, cfg('puntos_conductor_por_viaje'), vid, 'viaje');
  RETURN jsonb_build_object('pago', medio, 'tarifa', v.tarifa);
END $$;

CREATE FUNCTION cancelar_viaje(vid bigint, motivo_ text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v viaje%ROWTYPE; actual text; es_cond boolean;
BEGIN
  SELECT * INTO v FROM viaje WHERE id = vid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Viaje inexistente.'; END IF;
  SELECT codigo INTO actual FROM estado_viaje WHERE id = v.estado_id;
  es_cond := v.conductor_id IS NOT NULL AND v.conductor_id = mi_conductor();
  IF NOT es_cond AND v.solicitante_id <> auth.uid() THEN RAISE EXCEPTION 'No podés cancelar este viaje.'; END IF;
  INSERT INTO cancelacion(viaje_id, usuario_id, motivo) VALUES (vid, auth.uid(), COALESCE(NULLIF(trim(motivo_), ''), 'Sin motivo'));
  IF es_cond THEN
    IF actual NOT IN ('asignado','camino','llego') THEN RAISE EXCEPTION 'Ya no se puede cancelar.'; END IF;
    INSERT INTO viaje_rechazo(viaje_id, conductor_id) VALUES (vid, v.conductor_id) ON CONFLICT DO NOTHING;
    UPDATE viaje SET conductor_id = NULL, estado_id = (SELECT id FROM estado_viaje WHERE codigo = 'buscando') WHERE id = vid;
  ELSE
    IF actual NOT IN ('buscando','asignado','camino','llego','programado') THEN RAISE EXCEPTION 'Ya no se puede cancelar.'; END IF;
    UPDATE viaje SET estado_id = (SELECT id FROM estado_viaje WHERE codigo = 'cancelado'), medio_pago_id = NULL WHERE id = vid;
    IF v.medio_pago_id = (SELECT id FROM medio_pago WHERE nombre = 'Puntos') THEN       -- se devuelve el viaje gratis
      UPDATE pasajero SET viajes_gratis = viajes_gratis + 1 WHERE usuario_id = v.solicitante_id;
    END IF;
  END IF;
END $$;

CREATE FUNCTION calificar_viaje(vid bigint, estrellas_ int, comentario_ text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v viaje%ROWTYPE;
BEGIN
  SELECT * INTO v FROM viaje WHERE id = vid;
  IF NOT FOUND OR v.solicitante_id <> auth.uid() OR v.conductor_id IS NULL
     OR v.estado_id <> (SELECT id FROM estado_viaje WHERE codigo = 'finalizado') THEN RAISE EXCEPTION 'No podés calificar este viaje.'; END IF;
  INSERT INTO calificacion(viaje_id, estrellas, comentario) VALUES (vid, estrellas_, NULLIF(trim(comentario_), ''));
  IF estrellas_ = 5 THEN PERFORM puntos_conductor(v.conductor_id, cfg('bonus_5_estrellas'), vid, 'calificacion_5'); END IF;
END $$;

CREATE FUNCTION set_foto(p_foto text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_foto IS NULL OR NOT imagen_valida(p_foto) THEN RAISE EXCEPTION 'La foto no es una imagen válida.'; END IF;
  UPDATE usuario SET foto = p_foto WHERE id = auth.uid();
END $$;

CREATE FUNCTION set_disponible(d boolean) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ UPDATE conductor SET disponible = d WHERE id = mi_conductor() $$;

CREATE FUNCTION cargar_saldo(monto_ numeric, medio_ text) RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE nuevo numeric;
BEGIN
  IF (SELECT valor FROM configuracion WHERE clave = 'carga_simulada') <> 'true'
    THEN RAISE EXCEPTION 'Las cargas reales requieren confirmar el pago con Mercado Pago o Ualá.'; END IF;
  IF mi_rol() IS DISTINCT FROM 'pasajero' THEN RAISE EXCEPTION 'Solo los pasajeros tienen billetera.'; END IF;
  IF monto_ < 500 OR monto_ > 100000 THEN RAISE EXCEPTION 'El monto debe estar entre $500 y $100.000.'; END IF;
  IF medio_ NOT IN ('Mercado Pago','Ualá','Transferencia','Tarjeta') THEN RAISE EXCEPTION 'Medio de pago inválido.'; END IF;
  UPDATE pasajero SET saldo = saldo + monto_ WHERE usuario_id = auth.uid() RETURNING saldo INTO nuevo;
  INSERT INTO movimiento_billetera(usuario_id, tipo, monto, detalle, medio_pago_id)
  VALUES (auth.uid(), 'carga', monto_, 'Carga de dinero', (SELECT id FROM medio_pago WHERE nombre = medio_));
  RETURN nuevo;
END $$;

CREATE FUNCTION ranking(periodo text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(x ORDER BY (x->>'viajes')::int DESC, (x->>'rating')::numeric DESC), '[]'::jsonb) FROM (
    SELECT jsonb_build_object('conductor_id', c.id, 'nombre', u.nombre, 'apellido', u.apellido, 'foto', u.foto,
      'viajes', COUNT(v.id), 'rating', rating_conductor(c.id), 'puntos', c.puntos,
      'ganado', CASE WHEN es_admin() THEN COALESCE(SUM(v.tarifa) FILTER (WHERE mp.nombre IS DISTINCT FROM 'Puntos'), 0) END) AS x
    FROM conductor c JOIN usuario u ON u.id = c.usuario_id
    LEFT JOIN viaje v ON v.conductor_id = c.id AND v.estado_id = (SELECT id FROM estado_viaje WHERE codigo = 'finalizado')
       AND CASE periodo WHEN 'hoy' THEN v.finalizado_en::date = current_date
                        WHEN 'semana' THEN v.finalizado_en >= now() - interval '7 days' ELSE true END
    LEFT JOIN medio_pago mp ON mp.id = v.medio_pago_id
    WHERE c.estado_aprobacion = 'aprobado' AND (es_admin() OR mi_conductor() IS NOT NULL)
    GROUP BY c.id, u.nombre, u.apellido, u.foto, c.puntos) t $$;

-- ---------- Solo administrador ----------
CREATE FUNCTION admin_listado() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin() THEN RAISE EXCEPTION 'Solo el administrador.'; END IF;
  RETURN jsonb_build_object(
    'conductores', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', c.id, 'usuario_id', u.id, 'nombre', u.nombre, 'apellido', u.apellido,
        'telefono', u.telefono, 'email', u.email, 'dni', u.dni, 'licencia', c.licencia, 'estado', c.estado_aprobacion, 'bloqueado', u.estado = 'bloqueado',
        'disponible', c.disponible, 'puntos', c.puntos, 'bonos', c.bonos, 'rating', rating_conductor(c.id), 'vehiculo', vehiculo_json(c.id))), '[]'::jsonb)
        FROM conductor c JOIN usuario u ON u.id = c.usuario_id),
    'pasajeros', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', u.id, 'nombre', u.nombre, 'apellido', u.apellido, 'telefono', u.telefono,
        'email', u.email, 'estado', u.estado, 'saldo', pa.saldo, 'puntos', pa.puntos)), '[]'::jsonb)
        FROM usuario u JOIN pasajero pa ON pa.usuario_id = u.id),
    'comercios', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', u.id, 'nombre', co.nombre_local, 'direccion', co.direccion,
        'telefono', u.telefono, 'email', u.email, 'estado', u.estado)), '[]'::jsonb) FROM usuario u JOIN comercio co ON co.usuario_id = u.id));
END $$;

CREATE FUNCTION aprobar_conductor(cid int, aprobar boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE faltan text;
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador puede aprobar choferes.'; END IF;
  IF aprobar THEN
    SELECT string_agg(t.nombre, ', ') INTO faltan FROM tipo_documento t WHERE t.obligatorio AND NOT EXISTS (
      SELECT 1 FROM documento d WHERE d.conductor_id = cid AND d.tipo_documento_id = t.id AND d.estado = 'aprobado'
        AND (NOT t.pide_vencimiento OR d.vence_el >= current_date));
    IF faltan IS NOT NULL THEN RAISE EXCEPTION 'Faltan documentos aprobados y vigentes: %.', faltan; END IF;
  END IF;
  UPDATE conductor SET estado_aprobacion = CASE WHEN aprobar THEN 'aprobado' ELSE 'rechazado' END WHERE id = cid;
  PERFORM auditar('aprobar_conductor', 'conductor ' || cid || (CASE WHEN aprobar THEN ' aprobado' ELSE ' rechazado' END));
END $$;

CREATE FUNCTION bloquear_usuario(uid_ uuid, bloquear boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin() THEN RAISE EXCEPTION 'Solo el administrador.'; END IF;
  UPDATE usuario SET estado = CASE WHEN bloquear THEN 'bloqueado' ELSE 'activo' END WHERE id = uid_ AND id <> auth.uid();
  PERFORM auditar('bloquear_usuario', uid_ || (CASE WHEN bloquear THEN ' bloqueado' ELSE ' desbloqueado' END));
END $$;

CREATE FUNCTION guardar_tarifa(p jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin() THEN RAISE EXCEPTION 'Solo el administrador.'; END IF;
  INSERT INTO tarifa(precio_100m, minima, base, por_km, recargo_nocturno_pct, recargo_rural_pct)
  VALUES ((p->>'precio_100m')::numeric, (p->>'minima')::numeric, COALESCE((p->>'base')::numeric, 0), COALESCE((p->>'por_km')::numeric, 0),
          COALESCE((p->>'recargo_nocturno_pct')::numeric, 0), COALESCE((p->>'recargo_rural_pct')::numeric, 0));
  PERFORM auditar('guardar_tarifa', p::text);
END $$;

-- ---------- Documentación del chofer ----------
CREATE FUNCTION tipos_documento() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.id), '[]'::jsonb) FROM tipo_documento t $$;

CREATE FUNCTION subir_documento(p jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c int; t tipo_documento%ROWTYPE; veh int; venc date := NULLIF(p->>'vence_el','')::date;
BEGIN
  SELECT id INTO c FROM conductor WHERE usuario_id = auth.uid();
  IF c IS NULL THEN RAISE EXCEPTION 'Solo los choferes suben documentación.'; END IF;
  SELECT * INTO t FROM tipo_documento WHERE codigo = p->>'tipo';
  IF NOT FOUND THEN RAISE EXCEPTION 'Tipo de documento inexistente.'; END IF;
  IF COALESCE(p->>'archivo', '') = '' OR NOT imagen_valida(p->>'archivo') THEN RAISE EXCEPTION 'Falta la foto del documento o no es una imagen válida.'; END IF;
  IF t.pide_vencimiento AND (venc IS NULL OR venc < current_date) THEN RAISE EXCEPTION '% vencido o sin fecha de vencimiento.', t.nombre; END IF;
  IF t.aplica_a = 'vehiculo' THEN SELECT id INTO veh FROM vehiculo WHERE conductor_id = c LIMIT 1; END IF;
  INSERT INTO documento(conductor_id, vehiculo_id, tipo_documento_id, numero, entidad, vence_el, archivo)
  VALUES (c, veh, t.id, NULLIF(trim(p->>'numero'), ''), NULLIF(trim(p->>'entidad'), ''), venc, p->>'archivo')
  ON CONFLICT (conductor_id, tipo_documento_id) DO UPDATE SET vehiculo_id = EXCLUDED.vehiculo_id, numero = EXCLUDED.numero,
    entidad = EXCLUDED.entidad, vence_el = EXCLUDED.vence_el, archivo = EXCLUDED.archivo,
    estado = 'pendiente', observacion = NULL, revisado_por = NULL, revisado_en = NULL, creado_en = now();
END $$;

CREATE FUNCTION mis_documentos() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('tipo', t.codigo, 'nombre', t.nombre, 'obligatorio', t.obligatorio, 'cargado', d.id IS NOT NULL,
    'numero', d.numero, 'entidad', d.entidad, 'vence_el', d.vence_el, 'estado', d.estado, 'observacion', d.observacion,
    'vencido', t.pide_vencimiento AND d.vence_el < current_date,
    'dias_para_vencer', CASE WHEN t.pide_vencimiento THEN d.vence_el - current_date END) ORDER BY t.id), '[]'::jsonb)
  FROM tipo_documento t LEFT JOIN documento d ON d.tipo_documento_id = t.id
       AND d.conductor_id = (SELECT id FROM conductor WHERE usuario_id = auth.uid()) $$;

-- ---------- Solo super admin (el dueño) ----------
CREATE FUNCTION superadmin_resumen() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  RETURN jsonb_build_object(
    'recaudacion_total', (SELECT COALESCE(SUM(v.tarifa), 0) FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id LEFT JOIN medio_pago m ON m.id = v.medio_pago_id
                          WHERE e.codigo = 'finalizado' AND m.nombre IS DISTINCT FROM 'Puntos'),
    'recaudacion_mes',   (SELECT COALESCE(SUM(v.tarifa), 0) FROM viaje v JOIN estado_viaje e ON e.id = v.estado_id LEFT JOIN medio_pago m ON m.id = v.medio_pago_id
                          WHERE e.codigo = 'finalizado' AND m.nombre IS DISTINCT FROM 'Puntos' AND date_trunc('month', v.finalizado_en) = date_trunc('month', now())),
    'viajes_total', (SELECT COUNT(*) FROM viaje), 'viajes_hoy', (SELECT COUNT(*) FROM viaje WHERE creado_en::date = current_date),
    'viajes_por_estado', (SELECT COALESCE(jsonb_object_agg(e.codigo, n), '{}'::jsonb) FROM (SELECT estado_id, COUNT(*) n FROM viaje GROUP BY estado_id) q JOIN estado_viaje e ON e.id = q.estado_id),
    'usuarios_por_rol', (SELECT COALESCE(jsonb_object_agg(r.nombre, n), '{}'::jsonb) FROM (SELECT rol_id, COUNT(*) n FROM usuario GROUP BY rol_id) q JOIN rol r ON r.id = q.rol_id),
    'conductores_pendientes', (SELECT COUNT(*) FROM conductor WHERE estado_aprobacion = 'pendiente'),
    'documentos_por_revisar', (SELECT COUNT(*) FROM documento WHERE estado = 'pendiente'),
    'documentos_por_vencer', (SELECT COUNT(*) FROM documento d JOIN tipo_documento t ON t.id = d.tipo_documento_id WHERE t.pide_vencimiento AND d.estado = 'aprobado' AND d.vence_el BETWEEN current_date AND current_date + 30),
    'documentos_vencidos', (SELECT COUNT(*) FROM documento d JOIN tipo_documento t ON t.id = d.tipo_documento_id WHERE t.pide_vencimiento AND d.vence_el < current_date),
    'saldo_en_billeteras', (SELECT COALESCE(SUM(saldo), 0) FROM pasajero),
    'viajes_gratis_pendientes', (SELECT COALESCE(SUM(viajes_gratis), 0) FROM pasajero));
END $$;

CREATE FUNCTION superadmin_conductores() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', c.id, 'nombre', u.nombre, 'apellido', u.apellido, 'telefono', u.telefono,
      'estado', c.estado_aprobacion, 'habilitado', conductor_habilitado(c.id), 'vehiculo', vehiculo_json(c.id),
      'docs_pendientes', (SELECT COUNT(*) FROM documento d WHERE d.conductor_id = c.id AND d.estado = 'pendiente'),
      'docs_aprobados', (SELECT COUNT(*) FROM documento d WHERE d.conductor_id = c.id AND d.estado = 'aprobado'),
      'docs_obligatorios', (SELECT COUNT(*) FROM tipo_documento WHERE obligatorio),
      'docs_vencidos', (SELECT COUNT(*) FROM documento d JOIN tipo_documento t ON t.id = d.tipo_documento_id
                        WHERE d.conductor_id = c.id AND t.pide_vencimiento AND d.vence_el < current_date)
    ) ORDER BY (c.estado_aprobacion = 'pendiente') DESC, c.id DESC), '[]'::jsonb)
    FROM conductor c JOIN usuario u ON u.id = c.usuario_id);
END $$;

CREATE FUNCTION superadmin_conductor(cid int) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  RETURN (SELECT jsonb_build_object('id', c.id, 'nombre', u.nombre, 'apellido', u.apellido, 'dni', u.dni, 'telefono', u.telefono, 'email', u.email,
      'foto', u.foto, 'licencia', c.licencia, 'estado', c.estado_aprobacion, 'habilitado', conductor_habilitado(c.id),
      'vehiculo', (SELECT jsonb_build_object('marca', ma.nombre, 'modelo', mo.nombre, 'anio', v.anio, 'color', v.color, 'asientos', v.asientos,
                   'patente', v.patente, 'tipo_patente', tp.nombre)
                   FROM vehiculo v JOIN modelo mo ON mo.id = v.modelo_id JOIN marca ma ON ma.id = mo.marca_id
                   JOIN tipo_patente tp ON tp.id = v.tipo_patente_id WHERE v.conductor_id = c.id LIMIT 1),
      'documentos', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', d.id, 'tipo', t.codigo, 'nombre', t.nombre, 'obligatorio', t.obligatorio,
                   'numero', d.numero, 'entidad', d.entidad, 'vence_el', d.vence_el, 'archivo', d.archivo, 'estado', d.estado,
                   'observacion', d.observacion, 'vencido', t.pide_vencimiento AND d.vence_el < current_date) ORDER BY t.id), '[]'::jsonb)
                   FROM tipo_documento t JOIN documento d ON d.tipo_documento_id = t.id AND d.conductor_id = c.id),
      'faltan', (SELECT COALESCE(jsonb_agg(t.nombre), '[]'::jsonb) FROM tipo_documento t WHERE t.obligatorio
                 AND NOT EXISTS (SELECT 1 FROM documento d WHERE d.conductor_id = c.id AND d.tipo_documento_id = t.id)))
    FROM conductor c JOIN usuario u ON u.id = c.usuario_id WHERE c.id = cid);
END $$;

CREATE FUNCTION revisar_documento(did int, aprobar boolean, obs text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  IF NOT aprobar AND COALESCE(trim(obs), '') = '' THEN RAISE EXCEPTION 'Escribí el motivo del rechazo.'; END IF;
  UPDATE documento SET estado = CASE WHEN aprobar THEN 'aprobado' ELSE 'rechazado' END, observacion = NULLIF(trim(obs), ''),
         revisado_por = auth.uid(), revisado_en = now() WHERE id = did;
  IF NOT FOUND THEN RAISE EXCEPTION 'Documento inexistente.'; END IF;
  PERFORM auditar('revisar_documento', 'documento ' || did || (CASE WHEN aprobar THEN ' aprobado' ELSE ' rechazado: ' || obs END));
END $$;

CREATE FUNCTION guardar_tipo_documento(tid int, obligatorio_ boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  UPDATE tipo_documento SET obligatorio = obligatorio_ WHERE id = tid;
  PERFORM auditar('guardar_tipo_documento', 'tipo ' || tid || ' obligatorio=' || obligatorio_);
END $$;

CREATE FUNCTION superadmin_admins() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', u.id, 'nombre', u.nombre, 'apellido', u.apellido, 'email', u.email,
          'rol', r.nombre, 'estado', u.estado) ORDER BY r.id DESC, u.nombre), '[]'::jsonb)
          FROM usuario u JOIN rol r ON r.id = u.rol_id WHERE r.nombre IN ('admin','superadmin'));
END $$;

-- La persona primero se registra como pasajero; el super admin la convierte en administrador
CREATE FUNCTION ascender_admin(p_email text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE u usuario%ROWTYPE;
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  SELECT * INTO u FROM usuario WHERE lower(email) = lower(trim(p_email));
  IF NOT FOUND THEN RAISE EXCEPTION 'Ese mail no está registrado. Pedile que primero cree su cuenta como pasajero.'; END IF;
  IF u.rol_id <> (SELECT id FROM rol WHERE nombre = 'pasajero') THEN RAISE EXCEPTION 'Solo se puede ascender a una cuenta de pasajero.'; END IF;
  UPDATE usuario SET rol_id = (SELECT id FROM rol WHERE nombre = 'admin') WHERE id = u.id;
  PERFORM auditar('ascender_admin', u.email);
END $$;

CREATE FUNCTION quitar_admin(uid_ uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  UPDATE usuario SET rol_id = (SELECT id FROM rol WHERE nombre = 'pasajero')
  WHERE id = uid_ AND rol_id = (SELECT id FROM rol WHERE nombre = 'admin');
  IF NOT FOUND THEN RAISE EXCEPTION 'Solo se puede quitar a un administrador común.'; END IF;
  INSERT INTO pasajero(usuario_id) VALUES (uid_) ON CONFLICT DO NOTHING;
  PERFORM auditar('quitar_admin', uid_::text);
END $$;

CREATE FUNCTION ver_ajustes() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  RETURN (SELECT COALESCE(jsonb_object_agg(clave, valor), '{}'::jsonb) FROM configuracion);
END $$;

CREATE FUNCTION guardar_ajuste(k text, v text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM configuracion WHERE clave = k) THEN RAISE EXCEPTION 'Ajuste inexistente.'; END IF;
  IF k = 'carga_simulada' AND v NOT IN ('true','false') THEN RAISE EXCEPTION 'Debe ser true o false.'; END IF;
  IF k <> 'carga_simulada' AND (v !~ '^[0-9]{1,6}$' OR v::int < 1) THEN RAISE EXCEPTION 'Debe ser un número entero mayor a cero.'; END IF;
  UPDATE configuracion SET valor = v WHERE clave = k;
  PERFORM auditar('guardar_ajuste', k || ' = ' || v);
END $$;

CREATE FUNCTION ver_auditoria(lim int DEFAULT 100) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_superadmin() THEN RAISE EXCEPTION 'Solo el super administrador.'; END IF;
  RETURN (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', t.id, 'quien', t.email, 'accion', t.accion, 'detalle', t.detalle, 'creado_en', t.creado_en) ORDER BY t.id DESC), '[]'::jsonb)
          FROM (SELECT a.*, u.email FROM auditoria a LEFT JOIN usuario u ON u.id = a.usuario_id ORDER BY a.id DESC LIMIT LEAST(lim, 500)) t);
END $$;

-- ============================================================
-- SEGURIDAD (RLS): cada usuario ve solo lo suyo; nadie escribe directo
-- ============================================================
ALTER TABLE usuario              ENABLE ROW LEVEL SECURITY;
ALTER TABLE pasajero             ENABLE ROW LEVEL SECURITY;
ALTER TABLE comercio             ENABLE ROW LEVEL SECURITY;
ALTER TABLE conductor            ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehiculo             ENABLE ROW LEVEL SECURITY;
ALTER TABLE viaje                ENABLE ROW LEVEL SECURITY;
ALTER TABLE viaje_rechazo        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cancelacion          ENABLE ROW LEVEL SECURITY;
ALTER TABLE calificacion         ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimiento_billetera ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimiento_puntos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracion        ENABLE ROW LEVEL SECURITY;
ALTER TABLE rol ENABLE ROW LEVEL SECURITY; ALTER TABLE estado_viaje ENABLE ROW LEVEL SECURITY; ALTER TABLE medio_pago ENABLE ROW LEVEL SECURITY;
ALTER TABLE marca ENABLE ROW LEVEL SECURITY; ALTER TABLE modelo ENABLE ROW LEVEL SECURITY; ALTER TABLE tarifa ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipo_patente ENABLE ROW LEVEL SECURITY; ALTER TABLE tipo_documento ENABLE ROW LEVEL SECURITY;
ALTER TABLE documento            ENABLE ROW LEVEL SECURITY;   -- sin política: se lee con mis_documentos() / superadmin_conductor()
ALTER TABLE auditoria            ENABLE ROW LEVEL SECURITY;   -- sin política: solo se lee con ver_auditoria()

CREATE POLICY ver_usuario   ON usuario   FOR SELECT TO authenticated USING (id = auth.uid() OR es_admin());
CREATE POLICY ver_pasajero  ON pasajero  FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR es_admin());
CREATE POLICY ver_comercio  ON comercio  FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR es_admin());
CREATE POLICY ver_conductor ON conductor FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR es_admin());
CREATE POLICY ver_vehiculo  ON vehiculo  FOR SELECT TO authenticated USING (conductor_id = mi_conductor() OR es_admin());
CREATE POLICY ver_viaje     ON viaje     FOR SELECT TO authenticated
  USING (solicitante_id = auth.uid() OR conductor_id = mi_conductor() OR es_admin());
CREATE POLICY ver_mov_bill  ON movimiento_billetera FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR es_admin());
CREATE POLICY ver_mov_pts   ON movimiento_puntos    FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR es_admin());
CREATE POLICY ver_config    ON configuracion        FOR SELECT TO authenticated USING (es_superadmin());
CREATE POLICY ver_catalogo ON rol FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON estado_viaje FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON medio_pago FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON marca FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON modelo FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON tarifa FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON tipo_patente FOR SELECT TO authenticated USING (true);
CREATE POLICY ver_catalogo ON tipo_documento FOR SELECT TO authenticated USING (true);
-- viaje_rechazo, cancelacion y calificacion: sin política = solo se leen a través de las funciones

-- Permisos: los clientes solo pueden leer (con RLS) y llamar a las funciones públicas de la lista
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT SELECT ON usuario, pasajero, comercio, conductor, vehiculo, viaje, movimiento_billetera, movimiento_puntos, configuracion TO authenticated;
GRANT SELECT ON rol, estado_viaje, medio_pago, marca, modelo, tarifa, tipo_patente, tipo_documento TO authenticated;
GRANT EXECUTE ON FUNCTION es_admin(), es_superadmin(), mi_conductor(), mi_rol() TO authenticated;
GRANT EXECUTE ON FUNCTION registrar_perfil(jsonb), mi_perfil(), tarifa_vigente(), mis_viajes(), mis_movimientos(),
  pedir_viaje(jsonb), aceptar_viaje(bigint), rechazar_viaje(bigint), avanzar_viaje(bigint, text), cancelar_viaje(bigint, text),
  calificar_viaje(bigint, int, text), set_foto(text), set_disponible(boolean), cargar_saldo(numeric, text), ranking(text),
  admin_listado(), aprobar_conductor(int, boolean), bloquear_usuario(uuid, boolean), guardar_tarifa(jsonb),
  tipos_documento(), subir_documento(jsonb), mis_documentos(),
  superadmin_conductores(), superadmin_conductor(int), revisar_documento(int, boolean, text), guardar_tipo_documento(int, boolean),
  superadmin_resumen(), superadmin_admins(), ascender_admin(text), quitar_admin(uuid), ver_ajustes(), guardar_ajuste(text, text), ver_auditoria(int) TO authenticated;
