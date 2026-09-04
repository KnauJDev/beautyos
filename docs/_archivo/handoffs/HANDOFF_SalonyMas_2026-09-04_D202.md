# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Blindaje de cabeceras web de seguridad", D-202)

**Bloque documentado:** decisión **D-202** · Paso **8.24** de la **FASE 8**.

**Estado:** ✅ **CERRADO**, `flutter analyze` 0/0 y **347 de 347 pruebas en
verde** (6 nuevas). Sin migración SQL ni Edge Function.

> ⚠️ **Pero TL-03 no queda cerrado del todo, y no es un descuido.** Falta
> **HSTS**, que en Cloudflare se activa desde el panel y no desde este
> repositorio. Quedó escrito como **paso 8.25**, pendiente del propietario. Ver
> el apartado 3.

> El bloque anterior (D-201, "Ciclo de vida reactivo de pestañas") está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-03_D201.md`.

---

## 1. Qué se añadió

`web/_headers`, en la regla `/*` que cubre toda la aplicación:

| Cabecera | Para qué |
|---|---|
| `X-Frame-Options: DENY` | Que nadie pueda meter Salón y Más en un iframe suyo |
| `Content-Security-Policy: frame-ancestors 'none';` | Lo mismo, en la forma moderna que sí respetan los navegadores actuales |
| `Permissions-Policy: camera=(), microphone=(), geolocation=()` | Que el navegador tenga prohibido pedir esas tres cosas en nuestro nombre |

Las tres que ya estaban siguen intactas: `nosniff`, `Referrer-Policy` y el
`Cache-Control` de D-096.

**El ataque que esto cierra**, en concreto: alguien monta una página, mete
Salón y Más dentro en un iframe invisible y pone sus propios botones encima.
El dueño cree que pulsa una cosa y pulsa otra, ya con su sesión abierta. Se
llama clickjacking y no necesita robar ninguna contraseña.

---

## 2. Lo que se comprobó antes de escribir

La guía de seguridad del catálogo local pide dos cosas antes de poner estas
cabeceras, y las dos se hicieron:

1. **¿Quién nos enmarca?** `grep` de `iframe` y `embed` sobre `web/` y `lib/`
   no devuelve **ni uno**. Por eso `DENY` y no `SAMEORIGIN`: la opción
   estricta no cuesta nada porque la aplicación no se enmarca a sí misma en
   ningún sitio.
2. **¿Qué funciones de navegador se usan?** Ni `getUserMedia`, ni
   `geolocation`, ni `ImageSource.camera`. `image_picker` abre la galería
   (D-199), no la cámara. Apagar las tres no quita nada que exista hoy.

**Y una tercera que no estaba en la lista pero era la que podía costar
dinero:** que `Permissions-Policy` no tocara WebAuthn. No lo toca — la lista
no incluye `publickey-credentials-get` ni `publickey-credentials-create`, así
que `passkeys_bundle.js` sigue igual.

---

## 3. Lo que este bloque NO pudo cerrar: HSTS

TL-03 dice que faltan tres cosas: CSP, protección contra clickjacking y
**HSTS**. Las dos primeras están hechas. La tercera **no se puede hacer desde
aquí**:

> En Cloudflare, HSTS se activa en **SSL/TLS → Edge Certificates → HSTS**.
> Escribir `Strict-Transport-Security` a mano en `web/_headers` **no lo
> activa**: solo deja una línea que aparenta proteger.

Eso lo advertía la propia auditoría, y por eso no se escribió. Quedó como
**paso 8.25 del Plan Maestro**, marcado 👤. Además, la regla 12 pide permiso
antes de tocar Cloudflare, así que no es trabajo del asistente.

**Se separó en su propio paso en vez de darlo por hecho dentro del 8.24**, para
que TL-03 no figure como cerrado mientras le falta un tercio.

---

## 4. La trampa: por qué la CSP lleva SOLO `frame-ancestors`

**Esto es lo más importante que deja escrito este bloque.**

CSP es opt-in por directiva: lo que no se nombra, no se restringe. Por eso una
`Content-Security-Policy` con solo `frame-ancestors` es segura hoy.

Pero ahora **la cabecera existe**, y lo natural es que el siguiente que pase
por ahí la quiera "completar". En cuanto aparezca `default-src`, `script-src`
o `frame-src` en esa línea, se rompen dos cosas a la vez:

1. **`https://checkout.epayco.co/checkout-v2.js`** (`web/index.html:52`) — la
   pasarela de pago. **Se cae el cobro de suscripciones para todos los
   negocios.**
2. **`passkeys_bundle.js`**, que usa WebAuthn.

**Y no se ve en `flutter test` ni en `flutter analyze`.** Solo aparece cuando
un negocio real intenta pagar. Por eso:

- Hay una prueba que **falla** si alguien añade una de esas tres directivas.
- El aviso está escrito además **dentro del propio `web/_headers`**, que es el
  archivo que abre quien vaya a tocarlo — no esta prueba, ni este documento.

### La confusión que había que evitar

`frame-ancestors 'none'` **no rompe la pasarela**, y conviene entender por qué:
restringe **quién puede enmarcarnos a nosotros**, no **lo que nosotros
enmarcamos**. El modal de ePayco es un iframe que insertamos en nuestra propia
página: le da exactamente igual.

Confundir esas dos direcciones es el error que habría roto los cobros.

---

## 5. Las 6 pruebas nuevas

`test/web_headers_security_test.dart`. Cuatro comprueban que las cabeceras
están (incluidas las tres que ya existían, que este bloque no podía llevarse
por delante) y dos vigilan la trampa del apartado 4.

**Por qué hacen falta:** `web/_headers` es un archivo de texto que nadie
compila y que ninguna prueba de Flutter tocaba. Se podía borrar media línea y
todo seguiría en verde hasta que alguien mirase la respuesta HTTP en
producción.

**El guardián se probó contra sí mismo:** añadiéndole `default-src 'self'` a
la CSP, la prueba falla con el mensaje correcto. Después se restauró el
archivo.

**Lo que las pruebas NO pueden comprobar:** que Cloudflare las sirva de verdad.
Esto lee el repositorio, no la respuesta del servidor.

---

## 6. Qué NO hacer

- **No añadir `default-src`, `script-src` ni `frame-src` a la CSP** sin
  permitir explícitamente `https://checkout.epayco.co` y probar **un pago
  real** antes de desplegar. Ver el apartado 4.
- **No escribir `Strict-Transport-Security` en `web/_headers`.** No activa
  HSTS y deja la sensación de que está puesto. Va en el panel de Cloudflare.
- **No cambiar `DENY` por `SAMEORIGIN`** "por si acaso". Se eligió `DENY`
  porque no hay un solo iframe propio en el repositorio; si algún día lo hay,
  entonces sí se revisa.
- **No borrar el comentario largo de `web/_headers`.** Ahí está el aviso de la
  pasarela, y hay una prueba que comprueba que sigue escrito.
- **No quitar el `Cache-Control` de D-096** al reordenar el archivo. Sin él,
  un despliegue tarda hasta cuatro horas en llegar; si el arreglo era de
  cobros, se cobra mal durante cuatro horas.

---

## 7. Lo que sigue abierto

1. **Nuevo de este bloque — paso 8.25:** activar **HSTS** en el panel de
   Cloudflare. 👤 Propietario.
2. **Anotado, no resuelto (regla 20):** `frame-ancestors 'none'` impide que un
   salón incruste su propia página pública (`salonymas.com/<slug>`, D-164) en
   su sitio web. Hoy nadie lo hace ni lo ha pedido. Si se pide, `_headers`
   admite reglas por ruta: se le puede dar `frame-ancestors *` solo a las
   páginas públicas dejando la aplicación en `'none'`.
3. **Heredado de D-201, y sigue sin verse con los ojos:** el armazón de
   navegación. Los cinco casos están en el apartado 9 de aquel HANDOFF; el
   decisivo es cobrar un ticket, pasar a Reportes y ver el dinero sin F5.
4. El otro tercio de **TL-09**: la consulta de Tickets sigue trayendo el
   historial completo.
5. La otra mitad de **UX-07** (Nequi vs. Daviplata), que **no es interfaz**:
   los métodos de pago son un `CHECK` de base de datos (C-04).
6. Fase 3 con dos casillas de 👤 abiertas (3.2 contador sobre DIAN/IVA, 3.4
   subir Supabase a Pro).
7. Hallazgos **Z** (recuperación de fotos tras restaurar) y **X** (la
   contraseña de la base nunca se ha rotado).

> **Lo que el propietario tiene que hacer y ver en este bloque:**
> 1. **Activar HSTS** en Cloudflare (paso 8.25).
> 2. Después de desplegar, comprobar que las cabeceras **llegan de verdad**:
>    `curl -I https://salonymas.com` o la pestaña Red de las herramientas del
>    navegador. Las pruebas leen el repositorio, no el servidor.
> 3. **Hacer un pago de prueba con ePayco.** Es el único camino que la CSP
>    podría haber roto, y aunque el análisis dice que no lo toca, esto se
>    confirma pagando, no leyendo.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-202: Bloque 8 "Blindaje de
cabeceras web de seguridad" -- X-Frame-Options, frame-ancestors y
Permissions-Policy en web/_headers).

flutter analyze 0/0 y 347/347 pruebas en verde. Sin migración SQL.

OJO: TL-03 NO quedó cerrado del todo. Falta HSTS, que se activa en el panel
de Cloudflare y no desde el repositorio; quedó como paso 8.25, pendiente del
propietario. Antes de darlo por cerrado, preguntar si ya lo activó.

Lo que sigue abierto, por orden de daño:
1. HSTS (paso 8.25), del propietario.
2. El armazón de navegación de D-201 sigue sin verificarse con los ojos.
3. El otro tercio de TL-09: la consulta de Tickets trae el historial completo.
4. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz: los
   métodos de pago son un CHECK de base de datos y necesita migración.
5. Hallazgos Z y X de la Fase 8.

Ojo con lo que NO hay que tocar: la Content-Security-Policy de web/_headers
lleva SOLO frame-ancestors, y es deliberado. Añadirle default-src, script-src
o frame-src bloquea checkout.epayco.co -- la pasarela -- y passkeys_bundle.js,
y ese fallo no se ve en las pruebas: solo cuando un negocio real intenta
pagar. Hay una prueba que lo impide y el aviso está dentro del propio archivo.
```
