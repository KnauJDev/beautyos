# Tramo D4.2 — Selección de entorno Supabase no productivo conectable

**Fecha:** 20 de julio de 2026
**Estado:** seleccionado con validación pendiente antes de SQL remoto
**Producción modificada:** no
**Base Git:** `91f1512 Preparar entorno conectable del Tramo D4.1`

## 1. Objetivo

Seleccionar un entorno Supabase conectable y no productivo para repetir, en un
micro-paso posterior, la matriz D4.0 de cliente heredado, privilegios y
aislamiento. D4.2 no ejecuta migraciones ni consultas SQL contra la base de
datos.

## 2. Evidencia revisada

- Las fuentes canónicas mantienen D4.2 como siguiente microcompuerta.
- `git status --short` no reportó cambios al iniciar el tramo.
- `git log -1 --oneline` reportó `91f1512 Preparar entorno conectable del Tramo D4.1`.
- No existe `supabase/config.toml` en el repositorio.
- No existe `.mcp.json` en el repositorio.
- No se encontraron archivos `.env` o `.env.*` dentro del repositorio.
- La CLI disponible es Supabase `2.109.1`.
- El changelog oficial de Supabase fue revisado el 20/07/2026. No se encontró
  un cambio reciente que modifique el criterio de este tramo. Se registran como
  contexto relevante el MCP remoto de Supabase, el cambio de exposición
  automática de tablas a Data/GraphQL API y cambios recientes no aplicables a
  esta selección, como los de self-hosted.

## 3. Resultado de selección

El conector Supabase expuso un único proyecto:

| Campo | Valor |
| --- | --- |
| Proyecto | `beautyos-dev` |
| Ref / ID | `eogppgbdnwxdtcbctaol` |
| Organización | `ffnlzoyeittnjkyiejze` |
| Región | `us-west-2` |
| Estado | `ACTIVE_HEALTHY` |
| Postgres | `17.6.1.127` |

Por nombre, estado y ausencia de otros proyectos en la cuenta conectada,
`beautyos-dev` queda seleccionado como candidato no productivo para D4.3.

## 4. Límites aplicados

- No se ejecutó SQL remoto.
- No se aplicaron migraciones.
- No se consultaron datos de negocio ni datos personales.
- No se leyeron ni registraron secretos.
- No se modificó producción.
- La consulta de ramas de desarrollo falló con error del conector:
  `Project reference is missing when validating permissions`. No se reintentó
  con operaciones alternativas que pudieran ampliar el alcance.

## 5. Condición antes de D4.3

Antes de ejecutar SQL, incluso de solo lectura, el usuario debe validar que
`beautyos-dev` no es producción ni contiene datos productivos sensibles sin
autorización para auditoría.

Si se valida, D4.3 debe limitarse a una fotografía SQL de solo lectura:

1. Confirmar funciones heredadas y `_v2`.
2. Confirmar permisos `PUBLIC`, `anon`, `authenticated` y `service_role`.
3. Confirmar que no se requiere aplicar migraciones.
4. Ejecutar únicamente consultas de conteo, firmas y privilegios.
5. Detenerse ante cualquier señal de entorno productivo o datos inesperados.

## 6. Cierre

D4.2 queda cerrado como selección documental y de metadatos. El entorno candidato
es `beautyos-dev`, pero la primera consulta SQL remota queda bloqueada hasta
validación explícita del usuario sobre su carácter no productivo.
