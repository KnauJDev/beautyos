# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-144)

**Bloque documentado:** decisión **D-144** · Paso 3.3: Términos de Servicio y Política de Privacidad / Habeas Data
**Estado:** 113 de 113 pruebas unitarias en verde (`flutter test`), `flutter analyze` 100% limpio (0 errores, 0 advertencias). Contenido legal técnico construido; **falta la revisión de un abogado colombiano antes de tratarlo como vinculante** (el propio Plan Maestro marca el paso 3.3 como trabajo conjunto 👥, no solo técnico).
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-140/D-141/D-142/D-143, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17.md`)

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA (12-ago) — 7 de 7
Fase 3  Poder cobrar                  🔄  ← AQUÍ
        3.1  ePayco admite recurrencia    ✅
        3.5  Precios y límites            ✅ CERRADO (12-ago)
        3.6  Precio por cliente           ✅ CERRADO (12-ago)
        3.7  Filtro de aceptación         ✅ CERRADO (16-ago / D-138)
        3.8  Pantalla pública de planes   ✅ CERRADO (17-ago / D-140)
        3.9  ePayco en servidor (webhook) ✅ CERRADO (17-ago / D-141, D-142)
        3.10 Pagos y suscripciones        ✅ CERRADO (17-ago / D-141, D-142)
        3.11 Avisos por correo y gracia   ✅ CERRADO (17-ago / D-143) — falta montar el disparador diario (pg_cron/externo)
        3.12 Correos de cuenta por Resend ✅
        3.3  Términos y privacidad        🔄 CONTENIDO TÉCNICO LISTO (17-ago / D-144) — falta revisión legal 👥
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
        3.13 Traducir correos de Auth     ⬜ 👥  hallazgo W
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

---

## 2. Qué pasó en este bloque (Paso 3.3 / D-144)

El Plan Maestro exigía Términos de Servicio y Política de Privacidad conformes a la Ley 1581 de 2012 (Habeas Data) antes de poder aceptar clientes reales que registren datos de terceros. Se construyó el contenido y su integración obligatoria en el flujo de registro.

### Lo que se construyó:

1. **`lib/pages/terms_and_privacy_page.dart`** (página nueva): dos pestañas navegables (`TabController`) — Términos de Servicio y Política de Privacidad — con diseño responsivo usando `AppColors`/`AppSpacing`/`AppRadius` del tema (sin colores sueltos; pasa `sin_colores_sueltos_test.dart`).
   - **Términos de Servicio:** aceptación, qué es la plataforma, responsabilidad del negocio (tenant) frente a sus propios clientes, disponibilidad del servicio, planes/precios/pagos, propiedad intelectual, **no reventa de datos**, uso aceptable, terminación, limitación de responsabilidad, ley aplicable (Colombia).
   - **Política de Privacidad / Habeas Data:** responsable del tratamiento, marco legal (Ley 1581 de 2012, Decreto 1377 de 2013), qué datos se recolectan, finalidad, **derechos ARCO** completos (Conocer, Actualizar, Rectificar, Suprimir, Revocar), procedimiento y plazos legales de respuesta (10 días hábiles consultas, 15 días hábiles reclamos), seguridad de la información, y **encargados del tratamiento nombrados explícitamente: Supabase, ePayco y Resend** — los proveedores reales de la plataforma, verificados contra el código, no genéricos.
   - Canal de contacto en ambos documentos: hola@salonymas.com.

2. **`main.dart`:** enrutamiento público sin sesión vía `?terminos=1` / `?terms=1` (pestaña de Términos) y `?privacidad=1` / `?privacy=1` (pestaña de Privacidad), mismo patrón que `?planes=1` de D-140.

3. **`register_page.dart`:** checkbox obligatorio ("Acepto los *Términos de Servicio* y la *Política de Privacidad*") con los dos enlaces tocables abriendo `TermsAndPrivacyPage` en la pestaña correspondiente. `register()` bloquea el alta con un mensaje claro si no está marcado, **antes** de llamar a Supabase. Los `TapGestureRecognizer` de los enlaces se guardan como campos de estado y se liberan en `dispose()` (no se crean sueltos en cada build).

4. **Enlaces discretos** en el pie de página de `LoginPage` y `PublicPlansPage`.

5. **Pruebas — primera suite de widgets del proyecto:** `test/terms_and_privacy_test.dart` (7 pruebas): contenido presente en cada pestaña, cambio de pestaña, el checkbox inicia sin marcar, el registro se bloquea con aviso claro si no se acepta, marcar el checkbox lo confirma, y tocar el enlace abre la vista legal completa (verificado invocando el `recognizer` del `TextSpan`, ya que Flutter envuelve `Text.rich` en un `TextSpan` sintético adicional con el estilo por defecto).

### Detalle técnico encontrado y corregido durante la construcción:
- `AppColors.brand` y `AppColors.brandDeep` son `static Color` **no `const`** (mutables para la marca blanca, D-109) — un primer intento de usar `const TextStyle(color: AppColors.brand)` falló en tiempo de compilación. Se corrigió quitando `const` de esos `TextStyle` puntuales.

---

## 3. Estado técnico

- **Pruebas:** 113 pruebas unitarias y de widgets · `flutter test` y `flutter analyze` 100% limpios
- **Sin migraciones nuevas:** este bloque es 100% Flutter, no toca la base de datos
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 4. Lo que NO se hizo, a propósito

**El contenido legal es un borrador técnico sólido, no una revisión de un abogado colombiano.** El propio Plan Maestro marca el paso 3.3 con 👥 ("obligatorio: se manejan datos de terceros"), es decir, trabajo conjunto, no solo técnico. Antes de tratar estos documentos como vinculantes de verdad:
- Un abogado debe revisar las cláusulas de responsabilidad y limitación de garantías.
- Si se agregan proveedores nuevos que procesen datos personales (encargados del tratamiento), hay que actualizar la lista de la Política de Privacidad en el mismo cambio que se agregue el proveedor.
- **3.11 sigue con un pendiente propio, sin relación con este bloque:** falta montar el disparador diario real (`pg_cron`/externo) de `send-subscription-expiry-alerts`; el código ya exige `CRON_SECRET` pero nadie la llama sola todavía.

---

## 5. Lo siguiente según el Plan Maestro

1. **Revisión legal humana del paso 3.3** (fuera del alcance de este asistente).
2. **3.11 — Montar el disparador diario** (`pg_cron`/externo) para que las alertas de vencimiento corran solas.
3. **3.2 — Contador** (DIAN, IVA) — 👤 pendiente del propietario.
4. **3.4 — Supabase Pro** (~25 USD/mes) — 👤 pendiente del propietario.
5. **3.13 — Traducir plantillas de correo de Auth a español** (hallazgo W).
