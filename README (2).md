# BellaVista Remis

Aplicación web para pedir **remises en Bella Vista, Tucumán**: el pasajero pide un viaje y el precio se calcula por distancia, el chofer lo acepta desde su celular, y el dueño controla todo desde un panel aparte.

> **Integrantes del grupo:** _(Raul Eduardo Montoya Zamorano)_
> **Materia / Profesor:** _(Facundo Argañaraz)_

## ¿Qué hace?

| Quién | Qué puede hacer |
|---|---|
| **Pasajero** | Registrarse con foto, pedir un remis en 2 pasos (de dónde sale y a dónde va), ver el precio y el recorrido en el mapa, billetera virtual, historial de gastos, puntos y viajes gratis (150 puntos por viaje, 1000 = viaje gratis), calificar al chofer |
| **Supermercado / comercio** | Pantalla fija para que sus clientes pidan remis sin tener cuenta |
| **Chofer** | Registrarse con los datos del auto y la documentación (foto del auto, patente, seguro, VTV, licencia, cédula, habilitación), aceptar viajes, cobrar, juntar puntos y ver el ranking de choferes |
| **Super administrador** | Aprobar o rechazar choferes revisando cada documento, ver la recaudación, manejar administradores, ajustes del sistema y auditoría |

**Precio del viaje:** cuadras de 100 m (redondeando hacia arriba) × $300, con una tarifa mínima. Se puede cambiar desde el panel del super admin.

## Cómo probarla (sin instalar nada)

Abrí `index.html` en el navegador (o la versión publicada en GitHub Pages). Viene en **modo demostración**, con datos de ejemplo guardados en el navegador:

| Rol | Usuario | Contraseña |
|---|---|---|
| Pasajero | `demo@bellavista.com` | `demo123` |
| Chofer | `carlos@bellavista.com` | `demo123` |
| Administrador (demo) | `admin` | `admin123` |

## Estructura del proyecto

| Ubicación | Qué es |
|---|---|
| `index.html`, `estilos.css`, `app.js`, `logo.png` | **Aplicación principal** (pasajeros, choferes y supermercados) |
| [`superadmin/`](superadmin) | **Panel del super administrador:** aprueba choferes revisando su documentación, maneja el equipo, los ajustes y la auditoría. Requiere la base de datos conectada |
| [`base-de-datos/`](base-de-datos) | **Base de datos PostgreSQL:** `base_de_datos_completa.sql` (22 tablas, datos de ejemplo, vistas, funciones, trigger y **58 consultas**, se ejecuta de una vez en una base vacía) y `schema_supabase.sql` (la base real de la aplicación, con login y seguridad por usuario) |
| [`documentacion/`](documentacion) | `BASE-DE-DATOS.md`: tablas, relaciones, normalización (3FN), seguridad y funciones |
| `DER_BellaVista_Remis.pdf`, `DER_general.png` | Diagramas entidad-relación |

## Base de datos

**PostgreSQL**, **22 tablas** normalizadas hasta **3FN**, con claves primarias y foráneas, restricciones, índices, vistas, funciones y un disparador (trigger). El detalle está en `BASE-DE-DATOS.md`.

## Tecnologías

HTML, CSS y JavaScript (sin frameworks) · Supabase (PostgreSQL, login y funciones del servidor) · Google Maps (mapa, ubicación y distancia) · Netlify (publicación).

## Conectarla a una base real (Supabase)

1. Crear un proyecto en [supabase.com](https://supabase.com) y ejecutar `base-de-datos/schema_supabase.sql` en el SQL Editor.
2. En `app.js` (bloque `CONFIG`, al principio) y en `superadmin/index.html` (bloque `CFG`) cargar la dirección del proyecto y la **clave pública (anon)**. Poner `MODO_DEMO: false` y `USAR_BASE_DE_DATOS: true`.
3. Opcional: la clave de Google Maps en `app.js` (`GOOGLE_MAPS_KEY`).
4. **Nunca** subir a GitHub la clave `service_role` de Supabase.
