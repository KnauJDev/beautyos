# HANDOFF Salón y Más — 23 de agosto de 2026 (redes sociales y capacidad operativa real, D-162)

**Bloque documentado:** decisión **D-162** · Refinamiento arquitectónico a pedido del propietario: el salón edita Instagram y Facebook desde su propia Configuración, y el Panel de Plataforma deja de mostrar el "Equipo Estimado"/"Sedes Estimadas" del formulario de registro para mostrar la capacidad operativa REAL en vivo (sedes activas, equipo activo con desglose por rol).

**Estado:** `flutter analyze` 100% limpio (0/0), **156 de 156 pruebas en verde**. Migración `20260823170000` **aplicada en Supabase** por el propietario, Control 182 **en verde contra la base real**. `git push` **pendiente de confirmar en producción al cerrar este documento** — ver abajo.

---

## 1. Dónde estamos

Continuación directa de D-161 (mismo día, misma línea de trabajo del Panel de Plataforma y Configuración, fila 4.11 del `PLAN_MAESTRO.md`, otra vez actualizada). El propietario pidió dos cosas: (1) que el salón pueda mantener sus redes sociales igual que ya mantiene nombre/tipo/teléfono/WhatsApp desde D-161; (2) que el Panel de Plataforma deje de confiar en lo que el negocio declaró al registrarse (`estimated_branches`/`estimated_team_size`) y muestre lo que realmente tiene hoy.

---

## 2. Qué pasó en este bloque

Dos decisiones se confirmaron explícitamente con el propietario antes de construir (`AskUserQuestion`, no se asumió):

1. **Fuente de datos para el equipo real:** `user_profiles` (el directorio real de personas, mismo origen que ya usa `get_tenant_users()`), **no** `tenant_memberships` (que es la tabla de autorización de acceso por sede, un concepto distinto — ver el hallazgo de D-161 sobre estas dos tablas paralelas).
2. **Alcance de "Editar Contacto" en el Panel:** el botón de la plataforma (`platform_update_tenant_contact`) **no** se amplió con teléfono/redes — esos campos se muestran en la Tarjeta 1 en modo **solo lectura** (coherente con D-009: plataforma y negocio son fronteras distintas). Solo se extendió `platform_list_tenants()` para que esos datos, que el propio salón ya mantiene, viajen hasta la UI.

**Lo que se construyó:**
- `supabase/migrations/20260823170000_redes_sociales_y_equipo_real.sql`:
  - `update_tenant_contact_info` pasó de 4 a 6 parámetros (`p_instagram`, `p_facebook`) — **cambiar la firma exige `drop function` explícito primero**; `create or replace` con distinta cantidad de argumentos crea un segundo overload huérfano en vez de reemplazar el existente.
  - `platform_list_tenants()` reescrita con `contact_phone`/`instagram`/`facebook` (solo lectura) y `real_branches_count`/`real_team_count`/`team_breakdown`: un `lateral join` cuenta sedes con `branches.active = true`, y otro agrupa `user_profiles` (`active = true`, rol en `owner`/`admin`/`assistant`/`stylist`) por rol, arma el texto ya pluralizado en español (ej. "1 dueño, 2 admins, 3 estilistas") y omite los roles en cero automáticamente (el `GROUP BY` no produce fila para un rol sin miembros activos).
- `supabase/sql/182_test_redes_y_equipo_real.sql`: control con `ROLLBACK`, tenant con equipo mixto (2 admins activos, 1 asistente **inactivo** que no debe aparecer en el desglose, 3 estilistas activos + 1 **inactivo** que no debe contar) y sedes mixtas (2 activas + 1 **inactiva**), para probar que solo cuenta lo activo.
- `lib/services/business_settings_service.dart`: `updateContactInfo` gana `instagram`/`facebook`.
- `lib/pages/settings_page.dart`: `_ContactInfoEditor` gana los dos campos; se retiraron las dos líneas de solo lectura de Instagram/Facebook que quedaban debajo (redundantes).
- `lib/models/platform_tenant_summary.dart`: nuevos campos `contactPhone`, `instagram`, `facebook`, `realBranchesCount`, `realTeamCount`, `teamBreakdown`.
- `lib/pages/platform_panel_page.dart`: Tarjeta 1 separada en **A. Contacto Administrativo** (negocio, tipo, titular, WhatsApp con botón de chat, correo, teléfono, ciudad, Instagram, Facebook, botón Editar Contacto sin cambios de alcance) y **B. Capacidad Operativa Real — en vivo** (sedes activas, equipo activo con desglose, origen/registro), reemplazando las filas de "Sedes Estimadas"/"Equipo Estimado".

**Verificado:** `flutter analyze` (0/0), `flutter test` (156/156), migración aplicada en Supabase, Control 182 en verde contra la base real.

---

## 3. Qué quedó a medias / fuera de este bloque

- `_TenantCard` (la tarjeta compacta en la lista del panel, no la Ficha Nivel 3) todavía muestra `estimatedBranches`/`estimatedTeamSize` en su subtítulo ("Ciudad: X · Sedes: Y · Equipo: Z") — el pedido era específicamente sobre la Tarjeta 1 de la Ficha Nivel 3, así que no se tocó. Si el propietario lo quiere consistente con los números reales, es un ajuste menor para otro bloque.
- Sigue pendiente (heredado de D-161) que el selector de sedes del header no se refresca solo tras crear una sede desde Configuración.

## Qué NO hacer

- **No** cambies la firma de una función Postgres sin `drop function` explícito primero si cambia la cantidad de parámetros — `create or replace` crea un overload nuevo y deja el viejo huérfano (ver `update_tenant_contact_info` en este mismo bloque).
- **No** uses `tenant_memberships` para contar equipo/personas — es la tabla de autorización de acceso por sede, no el directorio de personas. Usa `user_profiles`, igual que `get_tenant_users()`.
- **No** amplíes `platform_update_tenant_contact` con teléfono/redes sin volver a confirmar con el propietario — se decidió a propósito dejarlos de solo lectura en el Panel.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-162: redes sociales
editables desde Configuración, capacidad operativa real en vivo en el Panel
de Plataforma). Migración 20260823170000 aplicada en Supabase, Control 182
en verde contra la base real, flutter analyze 0/0, flutter test 156/156.

Pendientes conocidos (no bloqueantes): _TenantCard sigue mostrando cifras
estimadas en vez de reales en su subtítulo; el selector de sedes del header
no se refresca solo tras crear una sede desde Configuración (heredado de
D-161).

No uses tenant_memberships para contar equipo — usa user_profiles. No
amplíes platform_update_tenant_contact con teléfono/redes sin confirmar de
nuevo con el propietario.
```
