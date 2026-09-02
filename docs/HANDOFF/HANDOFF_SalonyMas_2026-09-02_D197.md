# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Pipeline de Integración Continua", D-197)

**Bloque documentado:** decisión **D-197** · Paso **8.19** de la **FASE 8**.

**Estado:** `.github/workflows/ci.yml` escrito y revisado. `flutter analyze`
0/0 y **297 de 297 pruebas en verde** en local, con exactamente los mismos
comandos que el workflow va a correr. **No hace falta ningún paso manual
adicional** (a diferencia de D-196): un workflow de GitHub Actions se activa
solo al llegar a `main`, sin contraseñas ni CLI de por medio. Falta el push
para que quede vivo.

> El bloque anterior (D-196, "Pulido Multi-Sede y Alertas de Suscripción")
> está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D196.md`.

---

## 1. Lo que cambió: cierra TL-07

La auditoría técnica del 01-sep (`AUDITORIA_4_REVISIONES_2026-09-01.md`)
tenía TL-07 con dos mitades: **"no existe `.github/workflows`"**, verificada
y cierta; y **"credenciales quemadas"**, verificada y **falsa** — la
`publishableKey` de Supabase en `main.dart:53` es pública por diseño, va
protegida por RLS, y no debe ir en `--dart-define`. Este bloque cierra la
mitad real.

**`.github/workflows/ci.yml`**, un solo job en `ubuntu-latest`:

```yaml
on:
  push:
    branches: [main]
  pull_request:

jobs:
  analyze-and-test:
    steps:
      - actions/checkout@v4
      - subosito/flutter-action@v2 (flutter-version: 3.44.2, channel: stable)
      - flutter pub get
      - flutter analyze
      - flutter test
```

### Decisiones concretas, y por qué

- **Flutter fijado en `3.44.2`/`stable`**, la misma versión que corre en la
  máquina de desarrollo (`sdk: ^3.12.2` de `pubspec.yaml`), en vez de dejar
  que el runner resuelva "la última estable". Una actualización silenciosa
  de Flutter en CI podría fallar por algo que no tiene nada que ver con el
  código que se está revisando ese día.
- **Sin secretos.** `flutter analyze` no toca la red, y las pruebas usan
  servicios falsos (`Fake*Service` — mismo patrón que `FakeAgendaBoardService`
  y `FakeTicketsService` que ya usa la suite) en vez de la base real. Nunca
  hay una llamada a Supabase durante `flutter test`.
- **`flutter analyze` sin `--fatal-infos`.** Hoy hay 2 infos preexistentes
  y ajenas a este cambio (`use_null_aware_elements` en
  `reportes_consolidados_test.dart`). Con `--fatal-infos` el primer run de
  CI habría fallado sin que nadie tocara nada ese día, lo que enseña
  exactamente lo contrario de lo que un pipeline nuevo debe enseñar.
- **Un solo job, sin matriz de sistemas operativos.** No hay código nativo
  por plataforma que analizar ni probar: una matriz solo encarecería cada
  corrida sin encontrar nada nuevo.
- **Solo lo que se pidió.** No se agregó `dart format --set-exit-if-changed`
  ni cobertura: nadie lo pidió, y habría podido fallar sobre código ya
  escrito sin ningún estándar de formato acordado hasta ahora. Si se quiere
  después, es su propia decisión.

---

## 2. Verificación

Los mismos tres comandos que corre el workflow (`flutter pub get`,
`flutter analyze`, `flutter test`) se corrieron en local antes de escribir
este HANDOFF: 0/0 en `analyze` y **297 de 297** en `test`. **Lo que no se
pudo verificar desde esta sesión** es el run real dentro de GitHub Actions
—necesita el push para existir—, pero al usar exactamente los mismos
comandos y la misma versión de Flutter que ya se corrieron en local, el
riesgo de sorpresa es bajo.

---

## 3. Qué NO hacer

- **No subir la versión de Flutter del workflow sin subir también la de
  desarrollo**, o al revés: que diverjan es la forma más común de que "en mi
  máquina funciona" dejé de ser cierto en CI.
- **No agregar `--fatal-infos` sin antes limpiar los 2 infos existentes**
  de `reportes_consolidados_test.dart` (ninguno de este bloque; son
  preexistentes). Si se agrega antes, el primer commit de cualquiera
  rompe CI por algo que no tocó.
- **No usar este pipeline como excusa para relajar la disciplina actual**
  de correr `flutter analyze`/`flutter test` antes de avisar que un bloque
  está listo. CI es una red, no un sustituto de comprobar antes de decir
  "está en verde".

---

## 4. Lo que sigue abierto (heredado, nadie lo tocó en este bloque)

1. La pantalla pública de planes, la tarjeta de sedes y el desglose de
   reportes por sede siguen sin verse con los ojos (HANDOFF de D-195,
   apartado 3.3).
2. El candado 2 de D-181 sigue sin ejercitarse contra un pago real de
   ePayco.
3. Del Plan Maestro: Fase 3 con dos casillas de 👤 abiertas (3.2 contador
   sobre DIAN/IVA, 3.4 subir Supabase a Pro).
4. Del resto de TL-07: nada más queda de este hallazgo — la mitad de
   "credenciales quemadas" ya estaba desmentida por la auditoría, no
   requiere trabajo.

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-197: Bloque 3 "Pipeline de
Integracion Continua" -- .github/workflows/ci.yml corriendo flutter analyze
y flutter test en cada push a main y cada pull request, cierra TL-07).

Este bloque quedo cerrado sin pasos manuales pendientes: a diferencia de
D-196, un workflow de GitHub Actions se activa solo al llegar a main. Si el
propietario ya hizo push, lo primero es preguntar si el primer run de CI en
GitHub salio en verde -- eso es lo unico que esta sesion no pudo verificar
(no hay forma de ver Actions desde aqui).

Lo que sigue abierto, heredado de bloques anteriores, por orden de daño:
1. Pantalla publica de planes, tarjeta de sedes y desglose de reportes por
   sede sin verificar visualmente.
2. El candado 2 de D-181 sin ejercitar contra un pago real.

Ojo con lo que NO hay que tocar: no agregar --fatal-infos a flutter analyze
en el workflow sin limpiar antes los 2 infos preexistentes de
reportes_consolidados_test.dart, o el primer commit de cualquiera rompe CI
por algo que no toco.
```
