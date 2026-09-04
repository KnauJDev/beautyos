# HANDOFF Salón y Más — 4 de septiembre de 2026 ("El token vencido que no dejaba cobrar", D-207)

**Bloque documentado:** decisión **D-207** · Paso **8.30** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **375 de 375 pruebas en
verde** (8 nuevas). Sin migración SQL y **sin desplegar Edge Functions**: el
arreglo es enteramente de Flutter, así que llega con el despliegue normal.

> El bloque anterior (D-206) está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D206.md`.

---

## 1. El síntoma y la causa

Al darle a *«Renovar suscripción con ePayco»* o al pagar una sede:

```
FunctionException(status: 401, details: {error: Se requiere una sesión
autenticada para generar la sesión de pago.})
```

Los tokens de Supabase **caducan a la hora**. La Edge Function los valida con
`auth.getUser(token)` y responde 401 si vencieron.

### La causa es más honda que «no se refrescaba en `iniciarPago`»

`SupabaseClient` arma la cabecera de autorización con
`auth.currentSession?.accessToken` y **la guarda**, actualizándola solo cuando
*ocurre* un refresco (`_handleTokenChanged`). Si el token vence **sin que el
refresco dispare** —una pestaña de fondo en web, donde los temporizadores se
estrangulan— la cabecera guardada queda igual de vieja.

O sea: leer `currentSession` a mano, como hacía `epayco_checkout_service`, **no
era peor que confiar en el SDK — era exactamente lo mismo.** El problema real
es que **nadie fuerza el refresco antes de llamar**.

---

## 2. Por eso el fallo estaba en cuatro sitios, no en uno

Cuatro Edge Functions tienen `verify_jwt = true`, y las cuatro se llaman desde
Flutter con un token que podía estar vencido:

| Sitio | Función | Qué pasaba |
|---|---|---|
| `epayco_checkout_service` | `create-epayco-session` | **401 a la cara: no se podía pagar** ← lo reportado |
| `team_invitations_service` | `send-invitation-email` | Devuelve `false`: la invitación se crea y **el correo no sale** |
| `main.dart` (vuelta de la pasarela) | `verify-epayco-transaction` | D-200 lo suaviza a «estamos validando»: el dueño se queda sin confirmación |
| `low_stock_alert_service` | `send-low-stock-alert` | `catch (_)` por diseño: **la alerta no sale y nadie lo nota** |

**En dos de los cuatro el 401 era invisible**, porque el error ya se traga por
diseño. Un token vencido era indistinguible de «no pasó nada». El alcance —
cerrarlos los cuatro — lo aprobó el propietario.

---

## 3. El arreglo

`lib/services/sesion_supabase.dart`:

- `necesitaRefresco(Session?)` — la decisión, pura y probada.
- `sesionFresca()` — refresca si hace falta; lanza si no hay forma.
- `cabecerasParaEdgeFunction()` — la cabecera con el token ya vigente.

Las cuatro llamadas quedan **idénticas**:

```dart
headers: await cabecerasParaEdgeFunction(),
```

Es la lección de D-198 aplicada antes de que duela: arreglarlo solo donde se
notó habría dejado tres vivos, dos de ellos mudos.

### El margen de 30 segundos no es un detalle

`Session.isExpired` usa `Constants.expiryMargin`, que son **30 s**: un token al
que le quedan 10 ya cuenta como vencido. Sin ese margen, la llamada podría
salir con un token que caduca **en vuelo**, y el 401 llegaría igual — pero
sería mucho más raro de reproducir.

> El comentario del propio `gotrue` dice *«10 seconds»* y está desactualizado
> respecto a su constante. **Manda la constante.**

---

## 4. Un hueco conocido, escrito y con prueba

`isExpired` devuelve **`false`** cuando **no puede leer** la caducidad, o sea
cuando el token no es un JWT decodificable. Es lo correcto —no se puede afirmar
que algo venció si no se sabe cuándo vence— pero significa que **un token con
forma rara pasa de largo** y será el servidor quien lo rechace.

Hay una prueba que lo fija, para que si algún día cambia sea deliberado y no
una sorpresa.

---

## 5. La prueba que evita un quinto sitio

`test/sesion_fresca_test.dart` lee **`supabase/config.toml` y `lib/` a la vez**:
saca qué funciones exigen JWT y comprueba que ninguna se llama sin
`cabecerasParaEdgeFunction()`.

El contrato estaba escrito en dos archivos que **ninguna prueba leía juntos**,
que es justo lo que dejó pasar el fallo en cuatro sitios a la vez. Misma
especie que `contrato_rpc_fechas_test.dart` (D-203).

> **Se ganó el sitio antes de subirse:** cazó que `epayco_checkout_service`
> calculaba la cabecera en una variable en vez de en la llamada — o sea que los
> cuatro sitios no eran idénticos. Se unificó.

**El archivo no se llama `epayco_checkout_service_test.dart`**, como pedía el
encargo, porque el arreglo dejó de vivir en ese servicio: un nombre atado a uno
de los cuatro haría creer que el problema era de él.

**Lo que no queda cubierto:** `sesionFresca()` en sí, que llama a Supabase para
refrescar y necesita sesión real. Lo que sí se prueba es la decisión de la que
todo cuelga.

---

## 6. Qué NO hacer

- **No volver a leer `currentSession` a mano** para armar una cabecera. Ese es
  el fallo, no la solución.
- **No confiar en la cabecera que guarda el SDK** para una función que exige
  sesión. Solo se actualiza cuando ocurre un refresco, y el caso malo es
  justamente que no ocurra.
- **No añadir una llamada nueva a una Edge Function con `verify_jwt = true`
  sin `cabecerasParaEdgeFunction()`.** Hay una prueba que lo detecta y dice
  qué archivo y qué función.
- **No cambiar `necesitaRefresco` para que refresque siempre.** Sería una
  llamada de más en cada pago, cada invitación y cada alerta de stock.

---

## 7. Lo que sigue abierto

> ✅ **CERRADO el 04-sep: el armazón de navegación de D-201 queda certificado
> por el propietario.** Estuvo siete sesiones en esta lista. Recorrió a mano
> los 16 módulos en producción: el cambio de sede actualiza los datos sin
> fallos, el selector segmentado del Dashboard (D-205) responde con las cifras
> reales y consolidadas, y el flujo Agenda → Tickets → Cobro → Reportes va
> limpio. **Cero pantallas rojas.**
>
> Es la regla 21 haciendo su trabajo: ninguna de las 375 pruebas podía ver
> eso, porque ninguna monta la aplicación real con sesión. Con esto quedan
> ejercitados a mano los tres cambios grandes de la semana — el armazón
> (D-201), el ámbito del Dashboard (D-205) y la limpieza de cabeceras (D-206).

1. Siete descripciones de error nombran funciones internas de la base al salón
   (D-206).
2. El tercio de **TL-09**: la consulta de Tickets trae el historial completo.
3. Los tickets con `scheduled_at` nulo desaparecerían de la lista. Hoy hay cero
   (D-204).
4. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
5. La otra mitad de **UX-07** (Nequi vs. Daviplata), que **no es interfaz**.
6. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).
7. Hallazgos **Z** y **X**.

> **Lo que el propietario tiene que probar en cuanto despliegue, y esta vez hay
> una forma de provocar el fallo a propósito:**
> 1. **Dejar la pestaña abierta más de una hora sin tocarla** y entonces darle
>    a «Renovar suscripción con ePayco». Antes daba 401; ahora tiene que abrir
>    la pasarela.
> 2. Que **invitar a un colaborador** siga mandando el correo.
> 3. Que un **pago normal** siga funcionando (que el refresco no rompa el
>    camino que ya iba bien).

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-207: el token vencido llegaba
a la Edge Function y esta respondía 401, así que no se podía pagar. Nadie
forzaba el refresco antes de llamar, y el mismo fallo estaba en los cuatro
sitios que llaman Edge Functions).

flutter analyze 0/0 y 375/375 pruebas en verde. Sin migración SQL y sin
desplegar Edge Functions: es enteramente Flutter.

Preguntar primero si el propietario ya pudo cobrar en producción, y si probó
el caso que provoca el fallo a propósito: dejar la pestaña más de una hora sin
tocar y entonces darle a renovar.

El armazón de navegación de D-201 quedó CERTIFICADO por el propietario el
04-sep: recorrió a mano los 16 módulos en producción, cero pantallas rojas.
Estuvo siete sesiones pendiente y ya NO hay que volver a sacarlo.

Lo que sigue abierto, por orden de daño:
1. Siete descripciones de error nombran funciones internas de la base (D-206).
2. El tercio de TL-09: la consulta de Tickets trae el historial completo.
3. HSTS (paso 8.25), del propietario.
4. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz.

Ojo con lo que NO hay que tocar: no volver a leer currentSession a mano para
armar una cabecera -- ese es el fallo, no la solución. Y no confiar en la
cabecera que guarda el SDK: solo se actualiza cuando ocurre un refresco, y el
caso malo es justamente que no ocurra.
```
