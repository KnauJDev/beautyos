# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-148)

**Bloque documentado:** decisión **D-148** · Paso 4.3: Frontend del Tablero de Agenda en Flutter (`AgendaPage` con vistas Día, Semana, Mes, lista Nivel 2 y WhatsApp directo)
**Estado:** `AgendaPage` 100% implementada y conectada a las RPCs `get_ticket_board_counts_v2` y `get_ticket_board_list_v2`. **121 de 121 pruebas Flutter en verde**, `flutter analyze` 100% limpio (0 errores, 0 advertencias).
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-147, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D147.md`)

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
        4.3  Tablero Flutter (Día/Sem/Mes)✅ CERRADO (17-ago / D-148)
        4.4  Número de venta al cerrar    ⬜ Siguiente paso (hallazgo P)
```

---

## 2. Qué pasó en este bloque (Paso 4.3 / D-148)

Se construyó la interfaz de usuario completa del **Tablero de Agenda de Salón y Más** (D-101 / D-116 / D-147 / D-148) conforme a la regla de oro: *"Al final de la jornada todas las columnas deben quedar en cero excepto Cerrado"*.

### Lo que se construyó:

1. **`lib/models/ticket_board.dart`:**
   - Modelos de datos `TicketBoardCount` (Nivel 1) y `TicketBoardItem` (Nivel 2) con deserialización JSON desde las RPCs.
   - Formateador de moneda colombiana `formatCOP()` para montos y saldos en pesos (`$ 50.000`).
   - Agrupaciones semánticas de columnas:
     * `DayBoardColumn`: 5 columnas (Por confirmar, Confirmado, En proceso, Por cobrar, Cerrado).
     * `WeekBoardColumn`: 6 columnas discriminadas (Solicitado, Cotizado, Apartado, Confirmado, Por cobrar, Cerrado).

2. **`lib/services/agenda_board_service.dart`:**
   - Invocación tipada a las RPCs `get_ticket_board_counts_v2` y `get_ticket_board_list_v2`.
   - Soporte para canal Realtime en la tabla `public.tickets` (`agenda_board_<branch_id>`) para actualización automática en vivo.

3. **`lib/pages/agenda_page.dart`:**
   - **Barra de Controles:** Selector de vista (**Día** | **Semana** | **Mes**), navegación temporal ("Hoy", "Esta semana", "Este mes", flechas y `DatePicker` de calendario), selector de granularidad para la vista Día (`15 min`, `30 min`, `1 hora`), y botón de refresco manual.
   - **Banner de Resumen Superior:**
     * Indicador de estado de la regla del cero (*"Jornada al día — Todas las columnas en cero salvo Cerrado"* en verde, o *"X tickets pendientes de cierre comercial"* en ámbar).
     * Badge independiente de **Canceladas / No asistió** (*"2 canceladas · 1 no asistió"*, D-101) que abre la lista de citas sin efecto al tocarlo sin ensuciar la cuadrícula de trabajo.
   - **Vista DÍA:** Filas por intervalo horario (de 08:00 a 20:00 o según citas), ceros atenuados (`·`) y conteos en badges de color.
   - **Vista SEMANA:** 7 filas de Lunes a Domingo con día actual resaltado y 6 columnas discriminadas.
   - **Vista MES:** Cuadrícula de 35 casillas con total por día y barra horizontal de proporciones de color (Gris, Verde, Azul, Coral, Ámbar). Tocar un día salta directamente a la vista Día de esa fecha.
   - **Modal de Nivel 2 (`_Level2Sheet`):** Al tocar cualquier celda se despliega la lista con consecutivo `#0000701` (`ticket_code`, D-117), `StatusPill`, cliente, **botón interactivo de WhatsApp (`wa.me`)**, servicios, estilistas, y desglose de dinero (total, abonado y saldo en coral).

4. **Pruebas y Análisis:**
   - Suite `test/ticket_board_test.dart` con 8 pruebas unitarias y de widgets.
   - **121 de 121 pruebas automáticas en verde** (`flutter test`).
   - `flutter analyze` 100% limpio (0 errores, 0 advertencias).

---

## 3. Estado técnico

- **Pruebas Flutter:** **121 de 121 en verde** (`flutter test`)
- **Análisis estático:** 0 errores, 0 advertencias (`flutter analyze`)
- **Decisiones registradas:** **148 decisiones** (D-001 al D-148)
- **Base de datos:** Migración 20260817170000 aplicada en `beautyos-dev` y verificada con Control 173 (5 de 5 en verde)

---

## 4. Próximos pasos inmediatos

1. **Paso 4.4:** **Número de venta** al cerrar el ticket (hallazgo P).
2. **Paso 4.5:** Tickets: pulido del nivel 2 y 3 + cambiar `TicketStatusBadge` por `StatusPill` (hallazgo N).
