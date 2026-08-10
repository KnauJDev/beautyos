# Tramo D4.1 — Preparación de entorno Supabase conectable

**Fecha:** 20 de julio de 2026
**Estado:** preparado localmente; pendiente de entorno conectable
**Producción modificada:** no
**Base Git:** `ea7f363 Verificar reversibilidad del Tramo D4.0`

## 1. Objetivo

Dejar definida y verificable la puerta para repetir la matriz D4.0 sobre un
entorno Supabase conectable, sin consultar ni modificar producción durante este
micro-paso.

## 2. Fotografía de configuración local

- La CLI disponible es Supabase `2.109.1`.
- El repositorio contiene `supabase/migrations/` y `supabase/sql/`, pero no
  `supabase/config.toml`.
- No existe `.mcp.json` en el repositorio.
- No se encontraron archivos `.env` o `.env.local`; no se inspeccionaron
  valores de secretos.
- Flutter declara `supabase_flutter: ^2.15.0` y Dart `^3.12.2`.
- `supabase status --output json` no pudo inspeccionar una pila CLI porque no
  existe el contenedor `supabase_db_BeautyOS`.
- El contenedor `beautyos-tramo-c-test` usado por D3.2–D4.0 es una restauración
  PostgreSQL aislada, no una pila local completa gestionada por la CLI.

## 3. Matriz que debe repetirse cuando exista el entorno

La ejecución futura será solo de lectura y debe confirmar, para las seis RPC
heredadas y sus seis reemplazos `_v2`:

| Control | Resultado requerido |
| --- | --- |
| Función heredada existe | Sí, mientras dure la ventana reversible |
| `PUBLIC`, `anon`, `authenticated` en heredadas | Sin `EXECUTE` |
| `service_role` en heredadas | `EXECUTE` temporal, si la ventana lo requiere |
| `_v2` para `authenticated` | `EXECUTE` y autorización por sede |
| `_v2` para `anon` | Sin `EXECUTE` |
| Cliente autenticado antiguo | Denegación explícita, sin fallback |
| Tenant A/A1/A2 y Tenant B | Aislamiento y membresía correctos |
| Datos, funciones y triggers | Sin cambios en la fotografía |

La fotografía debe guardar únicamente conteos, firmas, privilegios y resultados
de pruebas; nunca claves, tokens ni datos personales.

## 4. Precondiciones para el siguiente micro-paso

1. Seleccionar un proyecto Supabase no productivo o una restauración conectable.
2. Proveer la conexión mediante el mecanismo seguro de la CLI o MCP, fuera del
   repositorio y sin registrar secretos.
3. Confirmar que la primera sesión será de solo lectura y no aplicará
   migraciones.
4. Ejecutar la matriz anterior y comparar contra D4.0.
5. Detenerse si el destino no puede identificarse inequívocamente como no
   productivo.

## 5. Cierre

D4.1 queda cerrado como preparación local. No se pudo repetir la matriz en un
entorno conectable porque el repositorio no tiene configuración ni credenciales
de conexión, y la pila CLI local no está disponible. El siguiente micro-paso
debe seleccionar explícitamente un entorno no productivo antes de ejecutar
cualquier consulta remota.
