# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-150)

**Bloque documentado:** decisión **D-150** · Paso 4.4: Número de venta consecutivo e inmutable por sede (`sale_number` / `sale_code`) con soporte para Resolución DIAN (Hallazgo P)
**Estado:** Migración SQL `20260817210000_numero_de_venta_por_sede.sql` y script de control `174_test_numero_de_venta_por_sede.sql` creados. Frontend Flutter con modelo `BranchSaleNumbering` y renderizado dual de chips en Nivel 2. **128 de 128 pruebas Flutter en verde**, `flutter analyze` 100% limpio (0 errores, 0 advertencias).
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-149, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D149.md`)

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
        4.2  Funciones del tablero agenda ✅ CERRADO Y APLICADO EN BD (17-ago / D-147)
        4.3  Tablero Flutter (Día/Sem/Mes)✅ CERRADO SIN RESERVAS (17-ago / D-148, D-149)
        4.4  Número de venta al cerrar    ✅ CERRADO (17-ago / D-150 / Hallazgo P)
        4.5  Tickets: Nivel 2 y StatusPill⬜ Siguiente paso (hallazgo N)
```

---

## 2. Qué pasó en este bloque (Paso 4.4 / D-150 / Hallazgo P)

Se resolvió la discrepancia entre el consecutivo operativo de agenda y la numeración contable/fiscal:
- `ticket_code` (ej. `#0000701`, D-117) es el consecutivo operativo del centro que nace al crear la cita.
- `sale_code` (ej. `VTA-0000001` o `FJ-020000`) es el **número contable correlativo de venta** asignado de forma atómica únicamente al pasar a estado `cerrado`.

### Lo que se construyó:

1. **`supabase/migrations/20260817210000_numero_de_venta_por_sede.sql`:**
   - Tabla `branch_sale_numbering` con prefijo configurable por sede, próximo número, relleno de ceros y campos de **Resolución DIAN** (`resolution_number`, `resolution_date`, `range_from`, `range_to`, `valid_until`).
   - Columnas `sale_number`, `sale_code` y `closed_at` en `public.tickets`.
   - Trigger `private.beautyos_assign_sale_number_on_close()`: genera el número de venta correlativo atómico en `cerrado`.
   - Trigger `private.beautyos_protect_immutable_sale_number()`: protege la inmutabilidad contable estricta bloqueando modificaciones posteriores.
   - RPCs `get_branch_sale_numbering` y `set_branch_sale_numbering` con validación de roles y reglas de negocio.
   - Backfill que asignó números correlativos históricos a los tickets cerrados existentes.
   - Actualización de `get_ticket_board_list_v2` para devolver `sale_number`, `sale_code` y `closed_at`.

2. **`supabase/sql/174_test_numero_de_venta_por_sede.sql`:**
   - Script de control con 6 pruebas aisladas en `ROLLBACK`:
     1. Asignación automática en `cerrado`.
     2. Citas abiertas o canceladas no queman números de venta.
     3. Consecutivos contables independientes por sede.
     4. Inmutabilidad contable estricta ante intentos de UPDATE.
     5. Configuración de Resolución DIAN y validación de `next_number`.
     6. Devolución de campos contables en `get_ticket_board_list_v2`.

3. **Frontend en Flutter:**
   - Modelo `BranchSaleNumbering` en `lib/models/sale_numbering.dart`.
   - Campos de venta integrados en `TicketBoardItem` (`lib/models/ticket_board.dart`).
   - Renderizado de chips duales en `_TicketCardNivel2` (`lib/pages/agenda_page.dart`): Chip Cita `#0000701` + Chip Venta `VTA-0000045` (en verde esmeralda con icono de recibo).
   - Suite `test/sale_numbering_test.dart` con 5 pruebas unitarias y de widgets.

---

## 3. Estado técnico

- **Pruebas Flutter:** **128 de 128 en verde** (`flutter test`)
- **Análisis estático:** 0 errores, 0 advertencias (`flutter analyze`)
- **Decisiones registradas:** **150 decisiones** (D-001 al D-150)
- **Base de datos:** Migración `20260817210000` y Control 174 listos para ejecutar.

---

## 4. Próximos pasos inmediatos

1. Aplicar la migración `20260817210000_numero_de_venta_por_sede.sql` en `beautyos-dev` y verificar con el script de Control 174.
2. Paso 4.5: Tickets: pulido del nivel 2 y 3 + cambiar `TicketStatusBadge` por `StatusPill` (hallazgo N).
