# Tramo D4.5 — mecanismo versionado para alinear `beautyos-dev`

**Fecha:** 20 de julio de 2026
**Estado:** preparado; pendiente de autorización de ejecución
**Proyecto objetivo:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Base Git:** `6447b7f Decidir alineacion de BeautyOS dev`

## 1. Objetivo

Preparar el mecanismo seguro para alinear el entorno Supabase no productivo
`beautyos-dev` con las migraciones locales D3.2 y D3.4, preservando
trazabilidad de migración y sin aplicar todavía cambios remotos.

## 2. Evidencia revisada

Se verificó el contexto canónico del repositorio:

- `git status --short`: limpio al inicio del micro-paso.
- `git log -1 --oneline`: `6447b7f Decidir alineacion de BeautyOS dev`.
- Documentos rectores: expediente técnico, registro de decisiones, impacto
  multisede y auditoría D0.

Se revisó Supabase CLI `2.109.1` mediante ayuda oficial local:

- `supabase link` permite vincular un proyecto por `--project-ref`, pero exige
  contraseña remota o perfil configurado.
- `supabase db push` permite `--linked`, `--db-url`, `--dry-run` y `--password`.
- `supabase migration list` y `supabase migration repair` operan contra proyecto
  vinculado o `--db-url`.

También se consultó el changelog oficial de Supabase el 20/07/2026. No se
detectó una alerta reciente que cambie el criterio de D4.5 para `db push`,
migraciones o reparación de historial; los cambios relevantes observados se
concentran en plataforma, Postgres, Data API, GraphQL, Auth y self-hosted.

## 3. Estado remoto confirmado

La consulta remota de solo lectura al historial de migraciones de
`beautyos-dev` confirmó que el proyecto llega hasta:

- `20260720152000_tramo_c3_caja_reportes_inventario_por_sede`

No aparecen registradas:

- `20260720183122_tramo_d3_2_reemplazos_lectura_por_sede`
- `20260720190528_tramo_d3_4_revocar_rpc_heredadas`

No se ejecutó DDL, DML, `GRANT`, `REVOKE`, `db push`, `repair` ni SQL directo.

## 4. Mecanismos evaluados

### 4.1 Supabase CLI

La CLI es una ruta válida si se dispone de una conexión segura fuera del
repositorio. En este repositorio no existe `supabase/config.toml` ni una
configuración enlazada, y no se deben solicitar ni persistir secretos en
archivos versionados.

Ruta CLI posible en una ejecución futura:

1. vincular o conectar `beautyos-dev` sin exponer secretos;
2. ejecutar vista previa (`db push --dry-run`) si la conexión lo permite;
3. aplicar únicamente las migraciones D3.2 y D3.4 en orden;
4. verificar con `migration list`, fotografía D4.3 y pruebas D3.2/D3.4.

### 4.2 MCP Supabase de migraciones

El conector Supabase disponible expone un mecanismo específico de migración
remota: `apply_migration`, además de `list_migrations` y `execute_sql`.

Para D4.5 se usó solo `list_migrations`. La ruta MCP queda seleccionada como
preferida para el siguiente micro-paso porque:

- no requiere guardar credenciales en el repositorio;
- diferencia una migración de SQL directo;
- permite verificar después el historial remoto con `list_migrations`;
- respeta la decisión D4.4 de evitar SQL directo si existe mecanismo versionado.

### 4.3 SQL directo

`execute_sql` queda descartado para D4.6 como primera opción. Solo podrá usarse
si el usuario autoriza explícitamente un fallback directo y una microdecisión
separada sobre trazabilidad de historial.

## 5. Decisión D4.5

El siguiente paso ejecutable será aplicar en `beautyos-dev`, no en producción,
estas dos migraciones mediante mecanismo de migración MCP, en orden:

1. `20260720183122_tramo_d3_2_reemplazos_lectura_por_sede.sql`
2. `20260720190528_tramo_d3_4_revocar_rpc_heredadas.sql`

Cada migración debe ejecutarse como una operación separada y verificarse después
con historial remoto, fotografía D4.3 y pruebas de acceso heredado/_v2.

## 6. Criterios de salida para D4.6

D4.6 deberá detenerse si cualquiera de estas condiciones falla:

- el destino no es inequívocamente `beautyos-dev` (`eogppgbdnwxdtcbctaol`);
- D3.2 no se aplica correctamente antes de D3.4;
- el historial remoto no muestra ambas migraciones;
- la fotografía posterior no confirma los seis RPC `_v2`;
- `authenticated` conserva acceso a alguna de las seis firmas heredadas;
- aparecen errores de asesores que impliquen riesgo de seguridad no documentado.

## 7. Cierre

D4.5 queda cerrado como preparación del mecanismo versionado. No se modificó
producción ni el entorno remoto. La ejecución queda pendiente de autorización
explícita del usuario para D4.6.
