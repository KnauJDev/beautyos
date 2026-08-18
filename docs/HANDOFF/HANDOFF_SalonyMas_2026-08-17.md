# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-149)

**Bloque documentado:** decisión **D-149** · Corrección post-auditoría del Paso 4.3 (D-148): días pasados atenuados en Semana/Mes (D-101) y WhatsApp sin "+"
**Estado:** Corregido y verificado. **123 de 123 pruebas Flutter en verde**, `flutter analyze` 100% limpio (0 errores, 0 advertencias).
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-148, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D148.md`)

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
        4.4  Número de venta al cerrar    ⬜ Siguiente paso (hallazgo P)
```

---

## 2. Qué pasó en este bloque (D-149)

La auditoría técnica del bloque anterior (D-148) encontró dos vacíos reales, no de estilo, y se corrigieron ambos en este bloque.

### Lo que se corrigió:

1. **Días pasados sin atenuar en Semana y Mes.** D-101 lo pide explícito: *"el día de hoy se marca; los días pasados se atenúan"* (sección 4), y en Mes el mecanismo de lectura "de un vistazo" depende de eso: *"días pasados casi todo gris = mes sano... en días futuros no hay gris, y está bien"* (sección 5). El código no tenía ninguna lógica de fecha para esto — se confirmó buscando `isBefore`/`atenua`/`pasado` en todo `agenda_page.dart` sin resultados.
   - **Corrección:** en `_buildWeekView` y `_buildMonthView` se calcula `isPast` (estrictamente antes de hoy) por cada día, y se envuelve la celda completa en `Opacity(opacity: isPast ? 0.55 : 1.0, ...)`. Se atenúa el día entero (borde, número, franja de colores) sin recolorear estado por estado; hoy y los días futuros quedan sin tocar.

2. **El enlace de WhatsApp conservaba el "+" del teléfono.** `_abrirWhatsApp` limpiaba el número con `[^0-9+]`, dejando pasar el `+` — inconsistente con el resto del proyecto (`public_plans_page.dart`, soporte de Configuración, alertas de suscripción), que siempre usa solo dígitos para `wa.me`. Verificado que los teléfonos de cliente sí se guardan con `+` en este proyecto.
   - **Corrección:** se extrajo la construcción del enlace a una función de nivel superior `buildWhatsAppUri(phone)` (mismo patrón que `buildCheckoutUri` del checkout de ePayco), que descarta todo lo que no sea dígito.

3. **Pruebas nuevas en `test/ticket_board_test.dart`:**
   - `buildWhatsAppUri` contra un teléfono con `+` y espacios, verificando que el resultado no contenga `+`.
   - Prueba de widgets que cuenta cuántos `Opacity` de la vista Semana quedan en `0.55` frente a `1.0`, calculado dinámicamente contra `DateTime.now()` (no depender de qué día de la semana corra la prueba).

---

## 3. Estado técnico

- **Pruebas Flutter:** **123 de 123 en verde** (`flutter test`) — 121 + 2 nuevas
- **Análisis estático:** 0 errores, 0 advertencias (`flutter analyze`)
- **Decisiones registradas:** **149 decisiones** (D-001 al D-149)
- **Sin migraciones nuevas:** este bloque es 100% Flutter

---

## 4. Próximos pasos inmediatos

1. **Paso 4.4:** **Número de venta** al cerrar el ticket (hallazgo P).
2. **Paso 4.5:** Tickets: pulido del nivel 2 y 3 + cambiar `TicketStatusBadge` por `StatusPill` (hallazgo N).
