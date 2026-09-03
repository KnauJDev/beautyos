# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Función canónica de moneda", D-198)

**Bloque documentado:** decisión **D-198** · Paso **8.20** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **301 de 301 pruebas en
verde** (4 nuevas). Sin migración SQL ni Edge Function: el bloque es
enteramente de Flutter, así que no queda ningún paso manual pendiente —a
diferencia de D-196— y no hace falta desplegar nada aparte del push.

> El bloque anterior (D-197, "Pipeline de Integración Continua") está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D197.md`.

---

## 1. Lo que cambió: cierra TL-12, y más de lo que TL-12 pedía

El encargo era cerrar TL-12: `_formatCop` duplicado en 7 archivos, con un
bug conocido en números negativos (`$-.100` en vez de `-$100`).

**Antes de tocar código** se buscó el mismo patrón de bug más allá de los 7
archivos citados, porque un bug de formato de dinero duplicado rara vez
tiene una sola copia. Aparecieron **6 copias más**, bajo un nombre distinto
(`formatMoney`/`_formatMoney`) pero con el **mismo algoritmo y el mismo
defecto exacto** — y tocando, además, los diálogos de pago de Tickets y el
resultado neto del Panel de Plataforma, que sí puede ser negativo. Se le
devolvió la decisión de alcance al propietario (`AskUserQuestion`) en vez de
ampliarlo por iniciativa propia: aprobó incluir las 6 copias adicionales.

**13 archivos en total**, no 7.

### El bug, en una línea

Las 13 copias agrupaban por miles recorriendo el string completo del
número, **incluido el signo `-` cuando lo había**. Con `-100`, el `-` cae
justo en la posición que dispara el separador de miles, y el resultado era
`$-.100` en vez de `-$100`. La corrección saca el signo ANTES de agrupar:

```dart
String formatCOP(num amount) {
  final rounded = amount.round();
  final isNegative = rounded < 0;
  final digits = rounded.abs().toString();
  // ... agrupa `digits` (sin signo) igual que siempre ...
  return isNegative ? '-\$$buffer' : '\$$buffer';
}
```

### Dónde quedó la función canónica, y por qué ahí

`formatCOP` se quedó en `lib/models/ticket_board.dart` — no en un
`lib/utils/` nuevo, porque el proyecto no tiene esa carpeta y crear una
convención de directorio nueva para una sola función es más cambio
arquitectónico del que pide un bug de formato. Ya era la de mayor adopción
(3 importadores externos antes de este bloque) y la única con prueba
unitaria previa, así que ganó por arraigo, no por el nombre.

### Se migró de verdad, no se dejó un alias

Ninguna de las 13 copias quedó como envoltorio "por compatibilidad": cada
`formattedX` pasó a llamar a `formatCOP` directo, y las funciones viejas se
borraron enteras. **Dos archivos sí conservan un envoltorio propio, y es
intencional:** `platform_partner.dart` (`_formatCopConSufijo`) y el método
`_formatCop` de `platform_panel_page.dart`, porque varias líneas de esos
archivos llevan el sufijo `" COP"` que `formatCOP` no incluye — envolver ahí
evita repetir `'${formatCOP(x)} COP'` seis y cuatro veces respectivamente.

### Un efecto colateral que valía la pena corregir de paso

El `_formatCop` viejo de `PlatformSaasMetrics` devolvía los dígitos **sin**
el signo `$`, y `platform_panel_page.dart` se lo anteponía a mano
(`'\$${m.formattedMrr}'`). Al migrar a `formatCOP` (que sí incluye el `$`)
esa concatenación habría dejado `$$1.240.000`. Se corrigió el sitio de la UI
en el mismo cambio y se actualizó la prueba que probaba el formato viejo
(`platform_fase7_test.dart`).

---

## 2. Los 13 archivos

**Familia `_formatCop` (los 7 de TL-12):**

1. `lib/models/expense_management_item.dart`
2. `lib/models/platform_saas_metrics.dart`
3. `lib/models/platform_tenant_summary.dart`
4. `lib/models/product_management_item.dart`
5. `lib/models/purchase_management_item.dart`
6. `lib/models/platform_partner.dart`
7. `lib/pages/platform_panel_page.dart`

**Familia hermana `formatMoney`/`_formatMoney` (encontrada antes de escribir código):**

8. `lib/models/ticket_payment.dart` (pública, consumida por 4 archivos más)
9. `lib/models/ticket_summary.dart`
10. `lib/models/my_commission_summary_item.dart`
11. `lib/pages/my_commission_summary_page.dart`
12. `lib/pages/my_stylist_agenda_page.dart`
13. `lib/pages/platform_tenant_detail_page.dart`

**Consumidores de `formatMoney` migrados a `formatCOP`** (no tenían copia
propia, solo importaban la de `ticket_payment.dart`): `branch_report_v3.dart`,
`client_summary.dart`, `reports_page.dart`, `tickets_page.dart`.

---

## 3. Verificación

- `flutter analyze`: **0 issues** (los 2 infos preexistentes de
  `reportes_consolidados_test.dart` tampoco aparecieron en esta corrida).
- `flutter test`: **301 de 301 en verde.** 4 pruebas nuevas en
  `ticket_board_test.dart`: millones/cifras grandes, decimales redondeados
  positivos, negativos (`-$1`, `-$100`, `-$999`, `-$1.000`, `-$50.000`,
  `-$1.250.000`), y el caso límite `-0.4` → `$0` (no `-$0`, porque redondea
  a un entero que ya no es negativo).
- Se actualizó `test/platform_fase7_test.dart` para reflejar que
  `formattedMrr`/`formattedTotalCollected` ahora incluyen el `$` (antes lo
  ponía la UI a mano, dos veces desde este cambio si no se corregía).
- Búsqueda final antes de cerrar: `grep -rniE "String _format(Cop|Money|Currency|Cash|Pesos)"`
  sobre todo `lib/` no devuelve ninguna copia suelta.

---

## 4. Qué NO hacer

- **No crear una nueva copia de `formatCOP` "solo para este archivo".**
  Es exactamente cómo llegamos a 13. Importar
  `'../models/ticket_board.dart' show formatCOP;` cuesta una línea.
- **No mover `formatCOP` a un `lib/utils/` nuevo sin que alguien lo pida.**
  Fue una decisión deliberada de este bloque, no un descuido: el proyecto no
  tiene esa carpeta y no hacía falta inventarla para una función.
- **No envolver `formatCOP` con `" COP"` en un tercer sitio.** Ya hay dos
  envoltorios (`platform_partner.dart`, `platform_panel_page.dart`); si
  aparece un tercero, es señal de que el sufijo debería ser un parámetro de
  `formatCOP` (`formatCOP(x, sufijo: 'COP')`), no una tercera copia del
  patrón envoltorio.

---

## 5. Lo que sigue abierto (heredado, nadie lo tocó en este bloque)

1. La pantalla pública de planes, la tarjeta de sedes y el desglose de
   reportes por sede siguen sin verse con los ojos (HANDOFF de D-195,
   apartado 3.3).
2. El candado 2 de D-181 sigue sin ejercitarse contra un pago real de
   ePayco.
3. Del Plan Maestro: Fase 3 con dos casillas de 👤 abiertas (3.2 contador
   sobre DIAN/IVA, 3.4 subir Supabase a Pro).
4. Del resto de la auditoría técnica: TL-09 (historial de tickets sin
   `ListView.builder` ni límite de fechas), TL-16 (`catch (_)` ciego en
   `tickets_service.dart:34`) y TL-20 (fotos sin compresión, hasta 10 MB en
   vez de ~300 KB) siguen confirmados y sin paso asignado.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-198: Bloque 4 "Función
canónica de moneda" -- formatCOP corregida para negativos, reemplaza 13
copias duplicadas del mismo bug, no solo las 7 que citaba TL-12).

Este bloque quedo cerrado sin pasos manuales pendientes: es enteramente
Flutter, sin migracion SQL ni Edge Function. flutter analyze 0/0 y
301/301 pruebas en verde.

Lo que sigue abierto, heredado de bloques anteriores, por orden de daño:
1. Pantalla publica de planes, tarjeta de sedes y desglose de reportes por
   sede sin verificar visualmente.
2. El candado 2 de D-181 sin ejercitar contra un pago real.
3. TL-09 (rendimiento del historial de tickets), TL-16 (catch ciego en
   tickets_service.dart) y TL-20 (fotos sin comprimir) siguen confirmados
   por la auditoria y sin paso asignado en el Plan Maestro.

Ojo con lo que NO hay que tocar: no crear una nueva copia de formatCOP en
ningun archivo -- import '../models/ticket_board.dart' show formatCOP;
cuesta una linea. Y no mover formatCOP a un lib/utils/ nuevo sin que
alguien lo pida: fue decision deliberada dejarla en ticket_board.dart.
```
