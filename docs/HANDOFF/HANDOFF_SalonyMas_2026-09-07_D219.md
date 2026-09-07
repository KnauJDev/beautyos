# HANDOFF Salón y Más — 7 de septiembre de 2026 ("Salón y Más sale a la calle, un solo editor, y la dirección de producto", D-217 a D-219)

**Bloque documentado:** decisiones **D-217**, **D-218** y **D-219** · Fase **9**.

**Estado:** ✅ Documentación al día. ⚠️ **Dos casillas del propietario bloquean lo siguiente** (pasos 9.22 y 9.24).

> Los dos bloques anteriores están archivados en `docs/_archivo/handoffs/`:
> `..._2026-09-06_D216.md` y `..._2026-09-07_REDES_SOCIALES.md`. El segundo se
> escribió como HANDOFF y no lo era: sus hechos operativos viven ahora en
> `02_operacion/REDES_SOCIALES.md`, y su porqué en D-217.

---

## 1. Lo primero: `supabase/` había desaparecido del árbol de trabajo

Al abrir la sesión, `git status` mostraba **331 archivos borrados**: las 118 migraciones, los 198 scripts de verificación, las 7 Edge Functions y `config.toml`. La carpeta entera estaba **dentro de `windows/`**, que es el proyecto de escritorio de Flutter y no tiene nada que ver.

**No se perdió nada.** Los 331 archivos resultaron **byte a byte idénticos** a los de `HEAD`, comprobados uno a uno contra `git hash-object`. Se devolvieron a su sitio y el árbol quedó limpio.

Lo grave no fue el riesgo —era cero, estaba todo commiteado y publicado— sino que **nadie había decidido ese movimiento y ningún documento lo explicaba**. De ahí sale D-218.

---

## 2. Qué se decidió

**D-217 — Salón y Más existe en público.** Página de Facebook y cuenta de empresa en Instagram (`@salon_y_mas`; `@salonymas` estaba tomado por un tercero), ambas con botón a WhatsApp, más la convocatoria orgánica de los 10 salones piloto en el grupo "Peluquerías Bogotá".

Los **21 días de prueba** prometidos en público **sí coinciden con el producto**: `register_tenant` crea la suscripción con `now() + interval '21 days'`. Verificado.

**Pero la tarifa preferencial prometida no tiene cifra.** Ver paso 9.22.

**D-218 — Un solo editor.** Antigravity pasa a solo lectura: revisa, opina y sugiere aprovechando su ventana de 2 millones de tokens, pero no escribe ni mueve archivos. Claude Code queda como único editor. Se descartó repartir áreas entre las dos herramientas: la frontera se cruza sola, y mover `supabase/` lo demuestra.

**D-219 — La dirección de producto.** De 15 módulos a **5 lugares** (HOY, CLIENTAS, MI DINERO, MI VITRINA, AJUSTES), los 6 roles como **3 aplicaciones**, y la competencia se disputa **por Colombia y WhatsApp**, no por cantidad de funciones. La dirección está aprobada; **la estructura concreta no se implementa hasta observar un día real de trabajo**.

---

## 3. Dónde quedó cada cosa

| Qué | Dónde |
|---|---|
| Los hechos de las cuentas: usuarios, biografías, contacto, qué no tocar | `02_operacion/REDES_SOCIALES.md` — documento **vivo** |
| Los activos de marca (`perfil`, `portada`, `post_instagram_1`) | `docs/00_producto/marca/` — **versionados**. Estaban sueltos en la raíz y sin commitear |
| El porqué de todo | `REGISTRO_DE_DECISIONES.md`, D-217 a D-219 |
| Lo que falta | `PLAN_MAESTRO.md`, Fase 9, pasos 9.22 a 9.26 |
| La regla del editor único | `PLAN_MAESTRO.md`, apartado 8, regla **16-bis** |

---

## 4. Lo que sigue, por orden

**Bloquean todo lo demás, y son del propietario:**

1. **Paso 9.22 — 🔴 Fijar la cifra de la tarifa preferencial.** Hay diez personas que pueden escribir mañana esperando un descuento que nadie ha decidido. Es lo más urgente del proyecto ahora mismo.
2. **Paso 9.24 — 🔴 Observar un día entero en el salón piloto.** Sin demostrar nada. Mirar y contar. De ahí sale la validación de D-219, y sin eso el paso 9.25 no se toca.

**Se puede avanzar en paralelo, sin esperar:**

3. Bloque B de la Fase 9: el `deno check` en el CI (9.6), verificar TL-01 contra transacción real (9.7), el ciclo completo de cobro (9.8) y las pruebas del Panel de Plataforma (9.9).
4. Paso 9.26: arrancar la verificación con Meta. Son semanas de espera, no de trabajo.
5. Pasos 9.15 a 9.18: Supabase a Pro, el contador, HSTS y rotar la contraseña.

---

## 5. Lo que NO hay que hacer

- **No implementar los 5 lugares antes del paso 9.24.** La estructura de D-219 es una hipótesis razonada, no un hallazgo de campo. Implementarla sin haber visto un salón trabajando es adivinar caro.
- **No pagar publicidad en Meta** hasta validar la respuesta orgánica (D-217).
- **No cambiar `@salon_y_mas`**: ya está indexado.
- **No dejar que Antigravity escriba** (D-218, regla 16-bis). Sus hallazgos entran como texto.
- **No guardar activos ni documentos sueltos en la raíz sin commitear.** Un documento que dice "no borrar estos archivos" no protege nada si git no los conoce.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-217 a D-219: redes sociales,
editor único y la dirección de producto).

Dos casillas del propietario bloquean lo siguiente: fijar la cifra de la tarifa
preferencial (9.22) y observar un día en el salón piloto (9.24). Sin la segunda,
NO se implementa la reestructuración de 5 lugares.

Mientras tanto se puede avanzar con el bloque B de la Fase 9: deno check en el
CI, verificar TL-01, el ciclo completo de cobro y las pruebas del Panel de
Plataforma.
```
