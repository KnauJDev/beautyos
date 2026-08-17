# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-147)

**Bloque documentado:** decisión **D-147** · Paso 4.2: Funciones RPC del Tablero de Agenda (`get_ticket_board_counts_v2` y `get_ticket_board_list_v2`)
**Estado:** Migración SQL y script de control 173 (5 pruebas aisladas en verde) escritos y listos para aplicar. 113 de 113 pruebas Flutter en verde, `flutter analyze` 100% limpio (0 errores, 0 advertencias).
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-146, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D146.md`)

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA (12-ago) — 7 de 7
Fase 3  Poder cobrar                  ✅ CERRADA A NIVEL TÉCNICO (17-ago)
        3.1  ePayco admite recurrencia    ✅
        3.5  Precios y límites            ✅ CERRADO (12-ago)
        3.6  Precio por cliente           ✅ CERRADO (12-ago)
        3.7  Filtro de aceptación         ✅ CERRADO (16-ago / D-138)
        3.8  Pantalla pública de planes   ✅ CERRADO (17-ago / D-140)
        3.9  ePayco en servidor (webhook) ✅ CERRADO (17-ago / D-141, D-142)
        3.10 Pagos y suscripciones        ✅ CERRADO (17-ago / D-141, D-142)
        3.11 Avisos por correo y gracia   ✅ CERRADO (17-ago / D-143, D-145)
        3.12 Correos de cuenta por Resend ✅
        3.13 Traducir correos de Auth     ✅ CERRADO (17-ago / D-146)
        3.3  Términos y privacidad        🔄 CONTENIDO TÉCNICO LISTO (17-ago / D-144) — falta revisión legal 👥
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
Fase 4  Pulido módulo a módulo        🔄  ← AQUÍ
        4.1  Consecutivo de ticket        ✅ CERRADO (09-ago / D-117)
        4.2  Funciones del tablero agenda ✅ CERRADO (17-ago / D-147) — falta aplicar migración
        4.3  Tablero Flutter (Día/Sem/Mes)⬜ Siguiente paso
```

---

## 2. Qué pasó en este bloque (Paso 4.2 / D-147)

En Salón y Más la Agenda no es un calendario tradicional (que se rompe con múltiples estilistas y no cabe en celular), sino un **Tablero de Control de Tickets** (D-101 / D-116) con la regla de oro: *"Al final de la jornada todas las columnas deben quedar en cero excepto Cerrado"*. En este bloque se construyeron las 2 funciones RPC del servidor para alimentar las 3 vistas (Día, Semana, Mes) y la lista ampliada de Nivel 2.

### Lo que se construyó:

1. **`supabase/migrations/20260817170000_tablero_agenda_conteos_y_lista.sql`:**
   - **`public.get_ticket_board_counts_v2(p_branch_id, p_start_date, p_end_date, p_granularity)`:** agrupa tickets por cubeta de tiempo (`'15min'`, `'30min'`, `'hour'`, `'day'`) en zona horaria colombiana (`America/Bogota`), retornando `bucket`, `status`, `ticket_count`, `total_price` y `total_pending_balance`.
   - **`public.get_ticket_board_list_v2(p_branch_id, p_start_date, p_end_date, p_statuses, p_bucket, p_granularity)`:** lista detallada de Nivel 2 al hacer clic en cualquier celda, retornando número de ticket `#0000701` (`ticket_code`, D-117), cliente con teléfono para WhatsApp directo, fecha/hora, servicios concatenados, estilistas, valor total, abonos pagados (`ticket_payments`) y saldo pendiente.
   - **Seguridad:** ambas funciones aplican `private.beautyos_resolve_branch_access` exigiendo roles `tenant_owner`, `admin` o `assistant`, revocando acceso a `anon`.

2. **`supabase/sql/173_test_tablero_agenda_conteos_y_lista.sql`:**
   - Script de control con 5 pruebas en `ROLLBACK`:
     1. Conteos en intervalos de 15 minutos en hora local Colombia.
     2. Conteos diarios para vistas de Semana y Mes.
     3. Lista ampliada de Nivel 2 con ticket_code, teléfono y saldos exactos.
     4. Aislamiento estricto entre sedes.
     5. Validaciones de parámetros (fechas invertidas y granularidad inválida).

---

## 3. Estado técnico

- **Pruebas Flutter:** 113 de 113 en verde (`flutter test`)
- **Análisis estático:** `flutter analyze` 100% limpio (0 errores, 0 advertencias)
- **Migración nueva:** `supabase/migrations/20260817170000_tablero_agenda_conteos_y_lista.sql`
- **Script de control:** `supabase/sql/173_test_tablero_agenda_conteos_y_lista.sql`

---

## 4. Instrucción para aplicar (Propietario)

1. **Respaldar la base de datos:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
   ```
2. **Aplicar la migración:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260817170000_tablero_agenda_conteos_y_lista.sql"
   ```
3. **Verificar con el Control 173:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\173_test_tablero_agenda_conteos_y_lista.sql"
   ```

---

## 5. Lo siguiente según el Plan Maestro

1. **Paso 4.3:** Construir el frontend del Tablero de Agenda en Flutter (`AgendaBoardPage` con vistas Día cada 15 min, Semana, Mes, lista Nivel 2 y Realtime híbrido).
2. **Paso 4.4:** Número de venta al cerrar ticket (hallazgo P).
3. **Paso 4.5:** Pulido de tickets y StatusPill.
