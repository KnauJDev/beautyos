# HANDOFF Salón y Más — 7 de septiembre de 2026 ("La marca de negocio de prueba, y D-221 estrena control", D-225)

**Bloque documentado:** decisión **D-225** · Fase **9**, paso **9.29** (backend).

**Estado:** ✅ Escrito y verificado. ⚠️ **Una migración y un control pendientes de correr.**

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-07_D224.md`.

---

## 1. Lo que se cerró antes, y ya está en producción

| Qué | Estado |
|---|---|
| **D-224** — el P0: una sede pagada ya se activa | ✅ Desplegado, `verify-epayco-transaction` v17 |
| **D-221** — el pionero sin 50% | ✅ Migración aplicada y comprobada (`asigna_el_50 = false`) |
| **D-222** — la tarifa: 50.000 fijos | ✅ Decidida |
| **D-223** — el guardián de documentación | ✅ En el CI, en verde |

---

## 2. Lo de este bloque (D-225)

**La marca `is_demo` existía desde agosto y nunca se pudo poner.** D-120 la creó con un `update` escrito a mano dentro de una migración, contra el único negocio que existía entonces, y no dejó ni RPC ni botón.

Al consultar producción:

```
Naguara de Uñas          is_demo = false    creado 24-jul
Prueba Barbería Elite    is_demo = false    creado 16-ago
Exportadora              is_demo = false    creado 21-ago
```

Los tres contaban como salones reales en las métricas del SaaS, con sus tickets sembrados.

**Vale la pena notar de dónde salió esto.** La auditoría de Antigravity (D-220) culpó al script de ensayo de ePayco de contaminar las métricas. Era **un tercio** del problema: ese script solo tocó a Naguara. La causa real —que nadie podía marcar nada— apareció al **consultar la base**, no al leer el código.

**El arreglo:** `platform_set_tenant_demo(tenant, es_prueba)`, solo para el dueño de plataforma, con rastro en `subscription_events`. Y la migración marca los tres.

**Es reversible a propósito:** un negocio marcado sale de las métricas **y deja de recibir los avisos de vencimiento**. Para probar esos correos hay que poder desmarcarlo, probar y volver a marcarlo — que es justo lo que hasta hoy no se podía.

**Y D-221 estrena su control:** `supabase/sql/207_test_pionero_sin_porcentaje.sql`. Salió sin él y se notó el mismo día: para saber si la migración había aplicado se buscó "50.00" en el texto de la función, y aparecía — en un comentario que explica qué se quitó. **El 207 no mira texto, mira comportamiento**, y deja probada la trampa de D-222: precio y descuento se acumulan.

---

## 3. ✅ Aplicado y verificado el 07-sep

Migración `20260907140000` aplicada **desde el SQL Editor**, y control 207 corrido en verde.

| Comprobación | Resultado |
|---|---|
| Los tres negocios de ensayo | `is_demo = true` los tres |
| `anon` alcanza `platform_set_tenant_demo` | `false` |
| `authenticated` la alcanza | `true` — correcto: la función comprueba por dentro que quien llama sea el dueño de plataforma |
| **Control 207** | **7 de 7.** Sin excepción y con `rollback` limpio |

El control 6 del 207 es el que más vale: si el precio pactado y el descuento porcentual **no** se acumularan, habría reventado. **La trampa de D-222 queda demostrada contra la base real**, no solo advertida en un documento.

### Una nota de operación que costó dos intentos

`aplicar_sql.ps1` falló dos veces con *"password authentication failed"*. **No era el guion:** se comparó línea por línea con `respaldo_supabase.ps1` —que había funcionado un minuto antes— y manejan la contraseña con el mismo código exacto. Eran 13 asteriscos cuando funcionaba y 12 cuando fallaba: la contraseña llegaba incompleta.

**Se aplicó por el SQL Editor, que no pide contraseña.** Es una vía válida para cualquier migración con su propio `begin`/`commit`, y también para los controles: sus fallos son `raise exception`, así que un «Success» significa que pasaron todos. Lo único que se pierde son los `raise notice`.

**Queda pendiente rotar la contraseña de la base** (hallazgo X, paso 9.17): resuelve esto y cierra una casilla de seguridad que ya estaba abierta.

## 4. Lo que sigue

- **Paso 9.29, la otra mitad:** el botón en el Panel de Plataforma para marcar un negocio sin escribir SQL.
- **Paso 9.19:** decidir qué pasa con los tres negocios de ensayo ahora que están marcados.
- **Paso 9.15:** Supabase a Pro.
- **Turno 2:** 9.10 (fallar cerrado en vez de cobrar 150.000 a ciegas), 9.7 y 9.8 — este último **incluye probar el cobro de una segunda sede**, que es lo único que verifica D-224 de verdad.

---

## 5. Lo que NO hay que hacer

- **No dar por probado el arreglo de las sedes (D-224).** Está desplegado y verificado estructuralmente, no contra un pago real.
- **No poner `price_cop` y `discount_percent` a la vez** (D-222). El control 207 lo deja demostrado.
- **No correr dos comandos a la vez** en la misma ventana de PowerShell.
- **No aceptar un hallazgo sin verificarlo contra la fuente** — ni de Antigravity (D-220), ni míos: en este bloque una comprobación mal diseñada dio un falso positivo sobre una migración que estaba perfecta.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-225: la marca de negocio de
prueba y el control 207).

Antes de tocar documentación: python scripts/verificar_documentos.py

Pendiente de correr: la migración 20260907140000 y el control 207 (que termina
en ROLLBACK). Después, la otra mitad del 9.29: el botón en el Panel.
```
