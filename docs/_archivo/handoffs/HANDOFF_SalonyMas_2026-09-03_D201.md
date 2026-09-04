# HANDOFF Salón y Más — 3 de septiembre de 2026 ("Ciclo de vida reactivo de pestañas", D-201)

**Bloque documentado:** decisión **D-201** · Paso **8.23** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **341 de 341 pruebas en
verde** (8 nuevas). Sin migración SQL ni Edge Function: el bloque es
enteramente de Flutter, así que no queda ningún paso manual pendiente y no
hace falta desplegar nada aparte del push.

> El bloque anterior (D-200, "Velocidad de Caja y Feedback de Pasarela") está
> en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D200.md`.

---

## 1. Lo que se cerró: el Hallazgo Q, después de tres semanas y media

**Q es el hallazgo más viejo que quedaba abierto.** Nació el 09-ago como *"que
el administrador se entere cuando el estilista finaliza"*, y ese mismo día se
comprobó que era general: **entrar a un módulo no recargaba sus datos.** Había
que pulsar Actualizar o F5. Se vio con las fotos y aplicaba igual a Tickets,
Clientes y el resto.

**Estuvo abierto sin causa raíz identificada hasta el 01-sep**, cuando la
auditoría técnica lo explicó en TL-10:

> `IndexedStack` construye **todos** sus hijos, no solo el visible.

O sea: los 16 módulos corrían su `initState` al abrir sesión —16 consultas a
Supabase de golpe— y no volvían a correrlo nunca más. **Volver a una pestaña no
recargaba nada porque nunca se había ido.** Q y TL-10 no eran dos problemas:
eran el síntoma y la causa.

---

## 2. El mecanismo ya estaba en el proyecto

Esto es lo que más ahorra tiempo saber: **no hizo falta inventar un sistema de
refresco.** Ya había uno.

17 de los 19 módulos llevan `ValueKey('...-${branch.branchId}')` desde antes de
este bloque. Cuando cambias de sede, la llave cambia, Flutter remonta el
subárbol, `initState` vuelve a correr y la página recarga. **El remontaje por
llave ya era la forma de refrescar de esta aplicación**, solo que atada a la
sede.

D-201 le añade un contador de visitas por módulo. Misma idea, un disparador
más.

### Lo que se descartó, y por qué

Una interfaz `Recargable` con un `GlobalKey` por página, de forma que el
armazón llamara a `recargar()` sin desmontar nada. **Habría conservado los
filtros y el scroll**, que es la ventaja real.

Se descartó porque obligaba a tocar **las 16 páginas**, con 16 oportunidades de
olvidar una y dejar el hallazgo medio cerrado, contra un solo cambio central de
unas 40 líneas. Un bloque a la vez.

---

## 3. Las cuatro piezas

### 3.1 Carga perezosa

Un módulo que nadie ha abierto ocupa su hueco en la pila con un
`SizedBox.shrink()`.

`IndexedStack` **exige que la lista tenga el mismo largo que los módulos** —su
`index` es una posición, no una identidad— pero nada le obliga a que esos
huecos sean la página de verdad. Al abrir sesión se pasa de 16 `initState` a
**uno**.

### 3.2 El embudo, que es la parte que no se ve

Había **cuatro sitios** escribiendo `selectedIndex` por su cuenta: los dos
menús, el salto de Agenda a Tickets (D-163 y D-195) y `_irAModulo` (D-168).

Con carga perezosa eso deja de valer: **un camino que no marque el módulo como
abierto deja la pantalla en blanco.** Los cuatro pasan ahora por `_irAIndice`,
y hay una prueba que falla si aparece un quinto.

### 3.3 La red contra el peor final

`pilaDeModulos` construye **siempre** el módulo visible, esté o no marcado como
abierto.

No es un adorno. Sin eso, cualquier fallo de marcado se manifiesta como
**pantalla en blanco sin salida**, que es el peor resultado posible de este
cambio. Con esa línea es imposible por construcción, sin tener que razonar
sobre si todos los caminos marcaron bien. Hay prueba.

### 3.4 Reiniciar al cambiar de sede

**El detalle que se escapa.** Al cambiar de sede, todos los módulos cambian su
llave de sede y se remontan. Si los ya visitados siguieran en la pila, se
recargarían **los 16 de golpe sin que nadie los mire** — justo el problema que
este bloque quita, entrando por otra puerta.

Se vuelve a empezar por el módulo que se está viendo.

---

## 4. La excepción, y lo que cuesta

Recargar significa **remontar**, y remontar **borra lo que la persona tuviera
escrito o filtrado**.

Se le devolvió la decisión al propietario con tres opciones (todos los módulos,
todos menos Configuración, o solo los de dinero y agenda). Eligió **todos menos
Configuración**, que tiene siete campos de texto en la propia página: nombre de
contacto, teléfono, WhatsApp, dirección, Instagram y Facebook. Perder lo
escrito por ir a mirar la Agenda es peor que ver un dato viejo en un formulario
que se está editando de todas formas.

`BeautyModule.recargaAlEntrar` es `true` por defecto **a propósito**: no
recargar es la excepción, y una excepción se escribe a mano.

> **Coste aceptado, y hay que decirlo claro:** en Tickets se pierden los
> filtros y el *"Ver 10 más"* de D-199 al volver de otra pestaña. Es el precio
> de que los datos estén frescos, y el propietario lo eligió sabiéndolo.

---

## 5. La prueba de C-03 falló, y esa era su razón de existir

D-199 dejó un guardián que exigía la cadena `selectedIndex = selectedIndex + 1`
en `main.dart`. Al pasar el salto por el embudo, esa cadena desapareció y **la
prueba se cayó**, obligando a decidir a conciencia si C-03 seguía vivo.

**Sigue vivo:** `_irAIndice(selectedIndex + 1)` se apoya en la adyacencia
Agenda→Tickets exactamente igual que antes. Cambió la forma, no la dependencia.
Se actualizó la expresión que vigila; el guardián se queda.

---

## 6. C-05, y lo que se comprobó antes de tocarlo

Los desplegables *"Sedes"* y *"Equipo"* del registro quedaron sin uso desde
D-162, cuando el Panel de Plataforma pasó a calcular la capacidad **real** en
vivo.

Antes de quitarlos se verificó:

1. **Ninguna pantalla los muestra** — `grep` sobre `lib/pages/` y
   `lib/widgets/` solo encuentra el modelo parseándolos.
2. La RPC `register_tenant` los tiene con `default 1` y las columnas son
   `not null default 1`.

Por eso se dejan de mandar sin que el registro cambie. **Si se hubieran quitado
del formulario mientras el panel todavía los enseñaba**, cada negocio nuevo
habría reportado "1 sede, 1 persona" — peor que no enseñar nada.

---

## 7. Las 8 pruebas nuevas cuentan montajes, no leen código

| Grupo | Qué prueba |
|---|---|
| TL-10 (4) | Lo no abierto no se monta · la pila conserva el largo · el módulo visible se monta aunque nadie lo marcara · entrar monta uno solo |
| Hallazgo Q (3) | Una visita nueva remonta · `recargaAlEntrar: false` conserva el estado · el defecto es recargar |
| Embudo (1) | Nadie escribe `selectedIndex` fuera de `_irAIndice` |

**A diferencia de las de D-199, estas ejercitan el comportamiento.** Se pudo
porque `pilaDeModulos` se dejó como **función de nivel superior y pura**: entra
una lista de módulos con sus contadores, sale la lista de hijos. Lo que miden
es **cuántas veces corre `initState`** — que es donde cada página consulta a
Supabase, así que contar montajes es contar consultas.

La única que lee la fuente es la del embudo, porque vigila que no aparezca un
quinto camino.

**No queda cubierto** el cableado dentro de `_BeautyOSHomeState` (que el menú
llame al embudo, que el cambio de sede reinicie): necesita sesión de Supabase.

---

## 8. Qué NO hacer

- **No añadir un camino nuevo que escriba `selectedIndex` directamente.** Tiene
  que pasar por `_irAIndice`, y hay una prueba que lo detecta. Un camino suelto
  no marca el módulo como abierto ni cuenta la visita.
- **No poner `recargaAlEntrar: false` en un módulo sin comprobar que guarda
  algo escrito a mano *en la página*.** Un diálogo es una ruta encima y no se
  pierde al cambiar de pestaña; eso no justifica la excepción.
- **No quitar la red del módulo visible** (`i != indiceActual` en
  `pilaDeModulos`). Parece redundante y no lo es: sin ella, un fallo de marcado
  es una pantalla en blanco sin salida.
- **No quitar el reinicio de `_modulosAbiertos` al cambiar de sede.** Sin él,
  cambiar de sede recarga los 16 módulos de golpe: el problema de TL-10
  volviendo por otra puerta.
- **No volver a meter los campos de sedes/equipo en el registro** sin que algo
  los lea. Si algún día hacen falta, el Panel de Plataforma ya calcula los
  reales (D-162).

---

## 9. Lo que sigue abierto

1. **Nuevo de este bloque:** volver a una pestaña pierde sus filtros y su
   paginación. Si molesta en el uso diario, la salida es la interfaz
   `Recargable` con `GlobalKey` que se descartó aquí — está descrita en el
   apartado 2.
2. El otro tercio de **TL-09**: la consulta de Tickets sigue trayendo el
   historial completo (`p_start_date: null`). D-199 acotó lo que se pinta, no
   lo que se trae.
3. La otra mitad de **UX-07**: distinguir Nequi de Daviplata **no es interfaz**
   — los métodos de pago son un `CHECK` de base de datos (C-04). Necesita
   migración, control SQL y recálculo del desglose de Reportes.
4. Del Plan Maestro: Fase 3 con dos casillas de 👤 abiertas (3.2 contador sobre
   DIAN/IVA, 3.4 subir Supabase a Pro).
5. Hallazgos **Z** (procedimiento de recuperación de fotos tras restaurar) y
   **X** (la contraseña de la base nunca se ha rotado), los dos en Fase 8.

> **Lo que el propietario tiene que ver con los ojos en este bloque (regla 21),
> y esta vez importa más que de costumbre porque se tocó el armazón de
> navegación:**
> 1. Que al abrir sesión **todo siga en su sitio** y la primera pantalla cargue.
> 2. Que **entrar a cada uno de los 16 módulos** los abra bien — sobre todo los
>    que nunca se visitan.
> 3. Que **cambiar de sede** siga funcionando y no deje ninguna pestaña rara.
> 4. Que **cobrar un ticket y pasar a Reportes** ya enseñe ese dinero sin F5:
>    eso es el Hallazgo Q cerrado, y es la prueba de fuego del bloque.
> 5. Que **Configuración conserve lo escrito** al ir y volver de otra pestaña.

---

## 10. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-201: Bloque 7 "Ciclo de vida
reactivo de pestañas" -- cierra TL-10 y con él el Hallazgo Q, que llevaba
abierto desde el 09-ago).

Este bloque quedó cerrado sin pasos manuales pendientes: es enteramente
Flutter, sin migración SQL ni Edge Function. flutter analyze 0/0 y
341/341 pruebas en verde.

Se tocó el armazón de navegación de la aplicación, así que lo primero es
saber si el propietario ya lo probó con los ojos (apartado 9 del HANDOFF).

Lo que sigue abierto, por orden de daño:
1. Volver a una pestaña ahora pierde sus filtros y su paginación. Es el
   coste aceptado de D-201; si molesta, la salida es la interfaz Recargable
   con GlobalKey que se descartó, descrita en el apartado 2 del HANDOFF.
2. El otro tercio de TL-09: la consulta de Tickets trae el historial
   completo.
3. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz: los
   métodos de pago son un CHECK de base de datos y necesita migración.
4. Hallazgos Z y X de la Fase 8.

Ojo con lo que NO hay que tocar: nada puede escribir selectedIndex sin pasar
por _irAIndice (hay prueba), y no quitar la red que construye siempre el
módulo visible en pilaDeModulos -- parece redundante y es lo que impide una
pantalla en blanco sin salida.
```
