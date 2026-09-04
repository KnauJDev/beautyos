# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Los errores dejan de hablar en técnico", D-208)

**Bloque documentado:** decisión **D-208** · Paso **8.31** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **376 de 376 pruebas en
verde** (1 nueva). Sin migración SQL ni Edge Function.

> El bloque anterior (D-207) está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D207.md`.

---

## 1. Qué cambió

Seis descripciones de error —cinco en Configuración, una en Inventario— decían
cosas como:

> *«Revisa la conexión con Supabase o la función `get_business_settings`.»*

A un salón eso **no le sirve de nada**: no puede hacer nada con ese dato, y lo
único que aprende es que la aplicación está rota por dentro. Ahora dicen:

> *«Revisa tu conexión a internet o intenta nuevamente más tarde.»*

Que sí le dice qué puede hacer él.

### Eran seis, no siete — y el número lo escribí yo

D-206 dejó anotado que eran **siete** y lo repetí en cada handoff desde
entonces. Son **seis**. El recuento salió de mezclar los dos textos de carga
—*«Cargando clientes/tickets desde Supabase…»*— que **ya se habían arreglado en
el propio D-206**.

Se corrige aquí en vez de dejarlo correr: un documento que afirma un número
equivocado envejece peor que uno que no lo dice (D-129).

---

## 2. El guardián de excepciones muertas funcionó una sesión después de escribirse

D-206 dejó en `sin_jerga_tecnica_test.dart` una lista de sitios donde nombrar a
Supabase es correcto, **cada uno con su porqué**, y una segunda prueba que
comprueba que esas excepciones **siguen haciendo falta**.

Al reescribir los seis textos, esa prueba **falló sola**:

> *«`settings_page.dart` ya no nombra a Supabase en ningún texto, así que su
> excepción sobra y se puede quitar de esta prueba. Motivo que tenía: …»*

Citando el motivo original, para que la decisión de quitarla fuera informada.
La lista baja de **tres entradas a una**: solo queda la declaración legal de la
Ley 1581 en Términos, que no se toca.

**Es exactamente para lo que se escribió**: una excepción muerta hace creer que
el texto sigue ahí cuando puede haberse borrado hace meses.

---

## 3. El guardián nuevo cubre 219 funciones, no dos

El encargo pedía vigilar que no aparecieran `get_business_settings` ni
`get_commission_policy`. Se hizo distinto, y a propósito.

`sin_jerga_tecnica_test.dart` ahora **lee los dos lados y los compara** —igual
que `contrato_rpc_fechas_test.dart` (D-203) y `sesion_fresca_test.dart`
(D-207)—: saca de las migraciones **todas** las funciones declaradas (219) y
comprueba que ninguna aparece en un texto de `lib/pages/`.

**Una lista escrita a mano solo vigila lo que ya se rompió una vez**, y este
proyecto tiene 219 funciones y mañana tendrá más.

- **Se excluyen las líneas de `import`:** una ruta de archivo es una cadena
  pero no es texto de pantalla, y hay un `create_branch_dialog.dart` que
  chocaba con la función `create_branch`.
- **Verificado mutándolo:** metiendo `get_business_settings` en una
  descripción, falla y señala archivo, línea y función.

> **De propina vigila algo que nadie pidió:** si una pantalla llamara a una RPC
> directamente, su nombre aparecería en una cadena y el guardián saltaría. El
> sitio de esa llamada es un servicio de `lib/services/`, que es como está
> montado el proyecto. El mensaje de fallo lo dice.

---

## 4. Lo que este bloque NO arregla, y es lo que de verdad importa

**Los seis paneles son `const InfoPanel(...)`: descartan `snapshot.error` por
completo.**

El error existe —el `if (snapshot.hasError)` lo mira— pero **no se enseña, no
se guarda y no se reporta**: ninguna de las dos páginas usa `MonitoreoService`
(D-115).

Antes de este cambio el salón veía una pista inútil. Después ve un mensaje
útil. **En los dos casos, nadie averigua nunca qué falló de verdad.**

Reportar `snapshot.error` a monitoreo lo arreglaría, pero **no es una línea**:
llamar a `reportarError` dentro del `builder` de un `FutureBuilder` dispararía
**en cada reconstrucción**, así que hace falta pensar dónde va. Queda como
trabajo propio.

---

## 5. Qué NO hacer

- **No volver a poner el nombre de una función en un texto de pantalla.** Hay
  un guardián que cubre las 219 y dice archivo, línea y función.
- **No añadir excepciones a `permitidos` sin escribir el porqué.** La lista
  está en una entrada por una razón: si crece, la pregunta no es cómo añadir
  una excepción.
- **No quitar la mención a Supabase de `terms_and_privacy_page.dart`.** Es la
  declaración de encargado del tratamiento (Ley 1581, D-144).
- **No meter `MonitoreoService.reportarError` dentro de un `builder`** para
  cerrar el punto 4 en una línea. Dispararía en cada reconstrucción.

---

## 6. Lo que sigue abierto

1. **Nuevo de este bloque:** los paneles de error descartan `snapshot.error` y
   no lo reportan. Nadie sabe qué falló cuando aparecen. Ver apartado 4.
2. El tercio de **TL-09**: la consulta de Tickets trae el historial completo.
3. Los tickets con `scheduled_at` nulo desaparecerían de la lista. Hoy hay cero
   (D-204).
4. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
5. La otra mitad de **UX-07** (Nequi vs. Daviplata), que **no es interfaz**:
   los métodos de pago son un `CHECK` de base de datos (C-04).
6. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).
7. Hallazgos **Z** y **X**.
8. **De D-207, sin comprobar todavía:** dejar la pestaña más de una hora sin
   tocar y darle a renovar. Es la única forma de provocar el 401 a propósito, y
   hasta que pase, ese arreglo está verificado por análisis y por pruebas, pero
   no por el caso real.

> **Lo que el propietario puede ver con los ojos:** provocar un error de red
> (modo avión, o cortar el wifi un momento) y abrir Configuración. La tarjeta
> tiene que decir *«Revisa tu conexión a internet…»* y **no** nombrar ninguna
> función.

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-208: las tarjetas de error
dejan de nombrarle funciones de la base al salón, y el guardián pasa a cubrir
las 219 funciones del proyecto leyendo las migraciones).

flutter analyze 0/0 y 376/376 pruebas en verde. Sin migración SQL.

Lo que sigue abierto, por orden de daño:
1. Los paneles de error descartan snapshot.error y no lo reportan a
   MonitoreoService: el salón ya ve un mensaje útil, pero nadie sabe qué
   falló. NO es una línea: reportarError dentro de un builder dispararía en
   cada reconstrucción, hay que pensar dónde va.
2. El tercio de TL-09: la consulta de Tickets trae el historial completo.
3. HSTS (paso 8.25), del propietario.
4. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz.
5. De D-207: sigue sin probarse el caso real -- dejar la pestaña más de una
   hora sin tocar y darle a renovar.

Ojo con lo que NO hay que tocar: la mención a Supabase en
terms_and_privacy_page.dart es la declaración legal de encargado del
tratamiento (Ley 1581). Es la única excepción que queda en el guardián, y
tiene el motivo escrito dentro.
```
