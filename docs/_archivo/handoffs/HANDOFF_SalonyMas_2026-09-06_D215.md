# HANDOFF Salón y Más — 6 de septiembre de 2026 ("El cobro vuelve a funcionar: claves modernas, wrappers `public` y `calc` fuera de ámbito", D-215)

**Bloque documentado:** decisiones **D-214** y **D-215** · Paso **8.37** de la **FASE 8**.

**Estado:** ✅ **CERRADO Y VERIFICADO EN PRODUCCIÓN.** `flutter analyze` 0/0, **387 de 387 pruebas en verde**, migración aplicada, cuatro Edge Functions desplegadas, secret key creada y **checkout probado hasta que la pasarela de ePayco abre**.

> El bloque anterior (D-214, misma fecha) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-06_D214.md`. Lo reemplaza este
> porque el desenlace cambió: D-214 se dio por cerrado en código, y al probarlo
> resultó que faltaban una decisión de panel y un arreglo de una línea.

---

## 1. El titular

**El cobro llevaba 26 días roto.** Las claves heredadas de Supabase se desactivaron el **10-ago a las 19:04**, y desde entonces ninguna Edge Function del cobro podía hablar con la base. Nadie se enteró porque nadie intentó cobrar. Lo dijo Supabase en su propio mensaje de error:

> *Your legacy API keys (anon, service_role) were disabled on 2026-08-11T00:04:08Z.*

---

## 2. Qué hizo falta, en orden

1. **Aplicar la migración `20260905180000`** (wrappers `public.*` para las seis RPC del cobro, que viven en `private` desde D-176). Seis `CREATE FUNCTION` y `COMMIT` limpio, con respaldo previo en `Backup_2026-09-06_08-17-20`.
2. **Desplegar las cuatro Edge Functions.** Versiones verificadas una a una: 17→18, 14→15, 13→14, 6→7. La CLI sube `_shared/supabase_keys.ts` como asset junto a cada una.
3. **Crear la secret key.** Este es el paso que faltaba y no estaba en el código. D-214 hizo que las funciones prefirieran `SUPABASE_SECRET_KEYS`, pero esa variable valía literalmente `{}` — Supabase inyecta el diccionario vacío cuando el proyecto no tiene ninguna secret key creada, y este no tenía. **El arreglo era inerte.** Se creó `edge_functions` (`sb_secret_…`) en el panel.
4. **Corregir `calc` fuera de ámbito.** El primer checkout murió con `ReferenceError: calc is not defined`: la reestructuración de D-214 movió `const calc` dentro del `if` del cálculo y dejó dos referencias en el `return` final.

---

## 3. La verificación, que fue un experimento de tres corridas

| Hora | Estado | Qué dijeron los registros |
|---|---|---|
| 08:25 | clave legacy | fallback en el cálculo, fallback en la intención, `Legacy API keys are disabled` |
| 08:49 | con secret key, sin el arreglo | **clave moderna desde `SUPABASE_SECRET_KEYS(json)`**, **ningún aviso de fallback**, sesión enviada, `ReferenceError` |
| 08:54 | con ambos | limpio, sin excepción, y la pasarela abrió |

**La desaparición de los dos avisos de fallback entre la primera corrida y las siguientes es la prueba directa de que los wrappers de D-214 funcionan**, y no de que los salvara el fallback. Era exactamente la duda del hallazgo **W**.

---

## 4. Qué NO está probado

- **El webhook y `verify-epayco-transaction`.** Necesitan un pago completado. `EPAYCO_TEST_MODE` está en `false` (comprobado por hash), así que sería dinero real. **Decisión del propietario, no del bloque.**
- La tarifa de **10.000 COP** con la que se probó es una tarifa personalizada que el propietario asignó a propósito a *Prueba Barbería Elite* (D-212). No es un error de cálculo.

---

## 5. Lo que sigue abierto

1. **Paso 8.38 (nuevo):** un `deno check` sobre `supabase/functions/**` en el CI. Hallazgo **AB**: un `ReferenceError` trivial llegó a producción porque nadie mira esa carpeta.
2. Hallazgo **W**: el fallback del cargo devuelve `150000` escrito a mano en el borde, contra D-193. Ahora sabemos detectarlo por los registros; sigue sin decidirse.
3. Hallazgo **AA**: duplicación de la cascada de claves en tres sitios. Sin urgencia.
4. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
5. El tercio de **TL-09**: acotar la consulta histórica de Tickets.
6. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
7. Fase 3 con dos casillas 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).

---

## 6. Lo que NO hay que hacer

- **No reactivar las claves heredadas.** El panel ofrece el botón *«Re-enable JWT-based API keys»* y arreglaría cualquier susto en un clic, pero deshace el trabajo de D-214 y devuelve el proyecto a claves que Supabase desaconseja. Es palanca de emergencia, no solución.
- **No fiarse del mensaje de error de `create-epayco-session` para localizar un fallo.** La variable `paso` no se actualiza después de *"registrar la intención de pago (D-182)"*, así que cualquier excepción posterior culpa a ese paso. Nos costó una hipótesis equivocada. Es de la familia de D-208.
- **No asumir que una variable de entorno con buen nombre tiene contenido.** `SUPABASE_SECRET_KEYS` existía, se llamaba bien, y estaba vacía. El digest de `secrets list` lo delata: `44136fa355b3678a…` es `sha256("{}")`.

---

## 7. Contradicciones y duplicados encontrados (señalados, no resueltos)

- **El índice del registro se había quedado sin la línea de D-213.** Repuesta. El índice vuelve a estar completo: 215 de 215.
- **Dos caracteres de control BEL** se colaron en `PLAN_MAESTRO.md` y `REGISTRO_DE_DECISIONES.md` al escribirlos desde un heredoc, donde debía ir `\a` de `scripts\aplicar_sql.ps1`. **Es el mismo fallo que la migración con los `$$` escapados, en otro archivo.** Reparado solo el carácter; el texto de D-214 no se reescribe, porque el registro no se corrige hacia atrás: lo supersede D-215.
- **Documentación duplicada fuera del repositorio:** 51 `.txt` numerados por "pasos" en OneDrive frente a 61 `.md` en `docs/_archivo/handoffs/`. El externo se quedó en el commit `4dd461c` del 04-sep.
- **`.agents/` es una copia vendorizada de `modern-web-guidance`** (141 `.md`, 928 KB, versionados) que duplica el plugin instalado en `~/.claude/plugins`.
- **`C:\Proyectos\.claude\launch.json` apunta a `C:\Proyectos\BeautyOS`, que no existe.** Config de máquina, fuera del repositorio.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-215: el cobro vuelve a funcionar
tras 26 días, con claves modernas, wrappers public y el arreglo de calc).

El cobro está verificado hasta que la pasarela abre. Lo que NO está probado es el
webhook ni verify-epayco-transaction: necesitan un pago completado y EPAYCO_TEST_MODE
está en false, o sea dinero real.

Próximo paso según Plan Maestro: paso 8.38, añadir un deno check sobre
supabase/functions/** al CI. Sale del hallazgo AB.
```
