# HANDOFF Salón y Más — 4 de septiembre de 2026 ("La lista de Tickets vuelve al Tablero", D-204)

**Bloque documentado:** decisión **D-204** · Paso **8.27** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **358 de 358 pruebas en
verde** (8 nuevas). Sin migración SQL ni Edge Function.

> Cierra el pendiente que dejó el hotfix de esta misma mañana (D-203). El
> HANDOFF anterior está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D203.md`.

---

## 1. Qué se recupera

Tres cosas que estaban construidas, desplegadas y **jamás vistas** por nadie,
porque el respaldo `get_tickets_summary_v2` devolvía menos columnas y en
`TicketSummary` todas son opcionales:

| Qué | Depende de | Desde cuándo faltaba |
|---|---|---|
| Chip del número de venta `VTA-0000045` | `sale_number`, `sale_code` | 17-ago (D-150/D-156) |
| Botón de WhatsApp con mensaje pre-armado | `client_phone` | 02-sep (D-195) |
| Búsqueda por teléfono y por número de venta | `client_phone`, `sale_code` | 17-ago |

**Lo que lo desbloqueó** fue el dato que faltaba, no una idea nueva: el
propietario contó en la base y hay **cero** tickets con `scheduled_at` nulo.
Ese era el riesgo que frenó a D-203 esta mañana — la RPC del Tablero filtra
`and tk.scheduled_at is not null`, y si hubiera tickets sin fecha habrían
desaparecido de la lista.

---

## 2. Las dos trampas que aparecieron al comparar columna por columna

Cambiar de RPC parecía un reemplazo directo. No lo era, y **las dos
diferencias fallan en silencio**.

### 2.1 El saldo se llama distinto

| RPC | Columna del saldo |
|---|---|
| `get_tickets_summary_v2` (la que salía) | `balance_amount` |
| `get_ticket_board_list_v2` (la que entra) | `pending_balance` |

Si el modelo hubiera leído solo la clave vieja, **todos los tickets habrían
mostrado saldo cero** — o sea, "está todo pagado" cuando no lo está.

No pasó: `TicketSummary.fromMap` ya leía las dos
(`balance_amount ?? pending_balance`) desde antes de este bloque. Pero **se
comprobó en lugar de darlo por hecho**, y ahora hay una prueba que lo fija.

### 2.2 El orden viene invertido

| RPC | `order by` |
|---|---|
| La que salía | `scheduled_at desc nulls last` → **lo más reciente primero** |
| La que entra | `scheduled_at asc, ticket_number asc` → **lo más viejo primero** |

La del Tablero ordena ascendente porque es la RPC del **Tablero de Agenda**,
que es una línea de tiempo. Esta pantalla es un historial y quiere lo
contrario.

Cambiar sin más habría hecho que **abrir Tickets mostrara los diez tickets más
viejos del salón** — con la paginación de diez en diez de D-199 encima. Un
salón con dos años de historia habría visto 2024 al entrar y habría dicho, con
razón, que la pantalla estaba rota.

**Se reordena en el cliente** (`ordenarTicketsParaLaLista`), no cambiando el
`order by` de la función. Se descartó tocar el SQL porque **esa misma RPC la
usa el Tablero de Agenda** (D-148), donde el orden ascendente sí es el
correcto: arreglar una pantalla habría roto la otra. Y habría sido una
migración, cuando esto se resuelve en el cliente.

---

## 3. El rango de fechas

`inicioDelHistorial` (2000) y `finDelHistorial` (2100) no son fechas con
significado de negocio: son un límite lo bastante ancho como para que "todos"
siga queriendo decir todos.

**El final va al futuro a propósito:** los tickets programados son citas que
todavía no han ocurrido, y un rango que acabara hoy no las enseñaría.

---

## 4. Corrección a lo que este proyecto escribió esta mañana

El paso 8.27, tal y como lo redacté en D-203, decía que este trabajo cerraría
también el tercio pendiente de **TL-09**. **No lo cierra**, y la fila está
corregida.

TL-09 dice que la consulta trae el historial completo, y **sigue trayéndolo**:
el rango es amplio justamente para no cambiar lo que la pantalla enseña.
Acotarlo de verdad exige decidir **qué significa "todos"** para el salón —
últimos 12 meses, último año fiscal, lo que sea — y eso es una decisión de
producto, no de implementación.

---

## 5. El riesgo que queda anotado

`scheduled_at` **admite nulos**: `create_ticket_rpc` lo declara
`p_scheduled_at timestamptz default null`. Hoy hay cero, y por eso se pudo
hacer este cambio.

Pero si algún día se crea un ticket sin fecha programada, **desaparecerá de
esta lista en silencio**, y un ticket que no se ve es un ticket que no se
cobra.

- **Mitigación parcial ya puesta:** hay una prueba que fija que los tickets sin
  fecha, si aparecen, van al final de la lista y no encabezándola.
- **Arreglo durable:** una migración que haga que `get_ticket_board_list_v2`
  deje de excluirlos. No se hizo aquí porque las migraciones las aplica el
  propietario (regla 16) y este paso no las necesitaba.

---

## 6. Las 8 pruebas nuevas

`test/historial_de_tickets_test.dart`, y **ejercitan comportamiento**, que es
la lección que dejó D-203 esta mañana:

- **Orden (5):** lo más reciente primero, los sin fecha al final, desempate por
  número de ticket, no se muta la lista de entrada, lista vacía.
- **Columnas (3):** que una fila con **las 19 columnas reales** de la RPC
  produzca el saldo correcto desde `pending_balance`, y el chip, el teléfono y
  el cliente. La tercera deja escrito lo que devolvía el respaldo, para que se
  entienda qué se perdía mientras tanto.

---

## 7. Qué NO hacer

- **No cambiar el `order by` de `get_ticket_board_list_v2`** para "ahorrarse"
  el reordenado en el cliente. Esa RPC la comparte el Tablero de Agenda
  (D-148), donde el ascendente es el correcto.
- **No dar por intercambiables dos RPC que devuelven "lo mismo".** Aquí una
  llamaba al saldo `pending_balance` y la otra `balance_amount`, y el orden
  venía al revés. Las dos cosas fallan sin excepción y sin aviso.
- **No estrechar el rango de fechas sin decidir antes qué significa "todos"**
  para el salón. Es lo que falta de TL-09 y es decisión de producto.
- **No volver a poner un respaldo con `catch`** en `getTicketsSummary`. Es lo
  que escondió durante 2,5 semanas que la llamada principal no funcionaba
  (D-199 → D-203). Hay dos pruebas que lo impiden.

---

## 8. Lo que sigue abierto

1. **El tercio de TL-09**: la consulta sigue trayendo el historial completo.
   Necesita una decisión de producto sobre qué significa "todos".
2. **Los tickets sin fecha programada** pueden desaparecer de la lista si algún
   día se crea uno. Arreglo durable = migración (apartado 5).
3. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
4. **El armazón de navegación de D-201 sigue sin verificarse con los ojos.**
   Lleva cuatro sesiones esperando, y es el cambio grande más reciente que
   nadie ha ejercitado a mano. Los cinco casos están en el apartado 9 de aquel
   HANDOFF.
5. La otra mitad de **UX-07** (Nequi vs. Daviplata), que **no es interfaz**:
   los métodos de pago son un `CHECK` de base de datos (C-04).
6. Fase 3 con dos casillas de 👤 abiertas (3.2 contador sobre DIAN/IVA, 3.4
   subir Supabase a Pro).
7. Hallazgos **Z** (recuperación de fotos tras restaurar) y **X** (la
   contraseña de la base nunca se ha rotado).

> **Lo que el propietario tiene que ver con los ojos, en cuanto despliegue:**
> 1. Que **Tickets sigue abriendo** y que el primero de la lista es el **más
>    reciente**, no uno de hace dos años. Es la trampa 2.2.
> 2. Que el **saldo de un ticket a medio pagar es correcto**, no cero. Es la
>    trampa 2.1, y es la que costaría dinero.
> 3. Que aparece el **chip `VTA-...`** en un ticket cerrado.
> 4. Que aparece el **botón de WhatsApp** y que buscar por teléfono encuentra.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-204: la lista de Tickets
vuelve a get_ticket_board_list_v2 con rango de fechas, cerrando el paso 8.27
que dejó abierto el hotfix D-203).

flutter analyze 0/0 y 358/358 pruebas en verde. Sin migración SQL.

Lo primero: preguntar si el propietario ya vio en producción que el primer
ticket de la lista es el MÁS RECIENTE y que el saldo de un ticket a medio
pagar no sale en cero. Son las dos trampas que tenía este cambio y las dos
fallan en silencio.

Lo que sigue abierto, por orden de daño:
1. El armazón de navegación de D-201 lleva CUATRO sesiones sin verificarse
   con los ojos. Es el cambio grande más reciente que nadie ha ejercitado a
   mano, y acabamos de ver dos veces lo que cuesta un camino no ejercitado.
2. El tercio de TL-09: la consulta trae el historial completo. Acotarlo
   necesita decidir qué significa "todos" para el salón.
3. Los tickets con scheduled_at nulo desaparecerían de la lista en silencio.
   Hoy hay cero. Arreglo durable = migración.
4. HSTS (paso 8.25), del propietario.
5. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz.

Ojo con lo que NO hay que tocar: el order by de get_ticket_board_list_v2 lo
comparte el Tablero de Agenda (D-148), donde el ascendente es el correcto —
por eso Tickets se reordena en el cliente. Y no volver a poner un respaldo
con catch en getTicketsSummary: es lo que escondió 2,5 semanas que la llamada
principal no funcionaba.
```
