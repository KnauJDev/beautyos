# Salón y Más — contexto de arranque

> Este archivo lo carga Claude Code **automáticamente** al abrir cualquier chat
> nuevo en este repositorio. No hay que pegar nada a mano.
> Su único trabajo es apuntar a la fuente de verdad: **aquí no se documenta
> nada, solo se enruta.**

## Reglas permanentes

@AGENTS.md

## Mapa de la documentación

@docs/README.md

---

## Antes de proponer o escribir nada

Lee, en este orden:

1. **El HANDOFF más reciente por fecha** en `docs/HANDOFF/` — dónde quedamos y
   qué quedó a medias. Solo vale el último.
2. **`docs/00_producto/PLAN_MAESTRO.md`** — **el único documento que manda
   sobre qué falta y en qué orden.** Trae la visión del producto, los planes y
   precios, el estado de los 16 módulos, las 8 fases con sus pasos, el buzón de
   ideas y las reglas de trabajo.
3. `docs/00_producto/REGISTRO_DE_DECISIONES.md` — **las últimas 15 entradas.**
   Muchas dudas ya tienen respuesta ahí, con lo que se descartó y por qué.

**No hay un cuarto documento con opinión sobre el plan.** Si encuentras uno,
está mal: siete se fundieron en el Plan Maestro el 09-ago (D-126) y lo anterior
vive en `docs/_archivo/`, que no manda sobre nada.

**No empieces por el código.** Este proyecto tiene más de 129 decisiones
registradas con su porqué; leer el código sin ellas es reconstruir a ciegas
razonamientos que ya están escritos.

**Si el HANDOFF más reciente es más viejo que el último commit**, dilo antes de
empezar: hay trabajo hecho que no está documentado y el contexto está
incompleto. Revisa el `git log` para cerrar el hueco.

---

## Cómo se trabaja

**Las reglas de trabajo están en `docs/00_producto/PLAN_MAESTRO.md`, apartado 8.
Léelas ahí. Aquí no se copian.**

Estaban escritas en seis sitios y ya se contradecían entre ellas (D-131). Una
regla copiada en seis sitios no está reforzada: está a punto de divergir.

**Si alguna vez este archivo vuelve a listar las reglas, está mal.**

---

## Al cerrar la sesión

Antes de terminar un bloque de trabajo, dejar el estado escrito en disco:

1. Revisar el `git log` desde el último HANDOFF y listar lo que se hizo.
2. Registrar como `D-XXX` solo lo que cambió el porqué, citando la decisión que
   corrige si aplica. El registro **solo crece**: nunca se borra una fila.
   **Y añadir su línea al índice del principio, en el mismo cambio.** Un índice
   incompleto es peor que no tenerlo: nadie va a buscar lo que el índice dice
   que no existe (D-129, D-131).
3. Actualizar **`PLAN_MAESTRO.md`**: marcar lo cerrado y anotar lo que salió
   sin fase asignada. *(`PLAN_DE_LANZAMIENTO` fue archivado el 09-ago, D-126.)*
4. Escribir un **HANDOFF nuevo** que reemplace al anterior, con: dónde quedamos,
   qué quedó a medias, qué NO hacer, y el prompt exacto para retomar.
5. Señalar contradicciones o duplicados encontrados, sin resolverlos por
   iniciativa propia.
6. **Verificar que lo escrito quedó escrito**, releyendo el archivo. Una
   edición que falla en silencio y un commit que afirma lo contrario es peor
   que no haberla hecho: nadie va a buscar lo que el documento dice que ya
   existe (D-129).

La continuidad entre chats no depende de que la IA "recuerde": depende de que el
estado quede escrito antes de cerrar.
