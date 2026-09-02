# HANDOFF Salón y Más — 1 de septiembre de 2026 ("Auditoría de 4 revisiones y cierre del perímetro de pagos", D-181 y D-182)

**Bloque documentado:** decisiones **D-181 y D-182** · Pasos **8.9 y 8.10** de la **FASE 8**.

**Estado:** `flutter analyze` limpio (0/0), **262 de 262 pruebas en verde**. **D-181 y D-182 desplegados y verificados en producción.** El perímetro de pagos de ePayco queda cerrado por los dos lados: la ruta de verificación inmediata y el webhook.

---

## 1. Lo que pasó en este bloque

### 1.1 La auditoría de 4 revisiones

El propietario contrató **Antigravity** (ventana de 2M tokens) para auditar el
repositorio completo antes de lanzar, en cuatro revisiones: **técnica**, **UX
Lead**, **Product Manager** y **crítica brutal con foco en seguridad**. Claude
Code verificó cada hallazgo contra el código real antes de convertirlo en trabajo.

Todo está en
**`docs/01_arquitectura/auditorias/AUDITORIA_4_REVISIONES_2026-09-01.md`**, que
es un **expediente de evidencia y no manda sobre el Plan Maestro**.

**Lo que hay que saber de esa auditoría, en tres frases:**

1. **La revisión técnica encontró dos fallos críticos reales de pagos** (TL-01 y
   TL-02) que tres semanas de Fase 8 no habían visto.
2. **La revisión de UX falló**: cuatro de sus doce hallazgos describían la
   aplicación de antes del 22-ago (pedían lo que ya hicieron D-157 y D-163), y
   uno (UX-05) estaba directamente mal leído — confundía callbacks del
   constructor con botones dibujados.
3. **La causa es siempre la misma:** 2M de tokens leen `lib/`, no leen las 182
   decisiones. Por eso a partir de la tercera revisión se le exigió en el prompt
   **citar el `D-XXX` que contradice** cada vez que propusiera cambiar algo.

**Hallazgo lateral valioso:** TL-10 dio la causa raíz del **Hallazgo Q**
("ningún módulo se actualiza solo"), abierto desde el 09-ago sin diagnóstico:
`main.dart:896` usa `IndexedStack`, que construye todas las páginas de golpe, así
que los `initState` ya corrieron y volver a la pestaña no recarga nada.

### 1.2 Paso 8.9 — TL-01 cerrado y verificado (D-181)

`verify-epayco-transaction` era pública, aceptaba cualquier `ref_payco` y sacaba
el negocio del `x_extra1` del payload. **Nunca comprobaba que la transacción
fuera del comercio de Salón y Más.**

Ahora tiene tres candados: `verify_jwt = true`, comparación de
`x_cust_id_cliente` contra `EPAYCO_P_CUST_ID`, y el negocio resuelto desde las
membresías activas de quien llama. **Desplegada y verificada en producción por
el propietario:** la petición anónima responde `401 UNAUTHORIZED_NO_AUTH_HEADER`.

### 1.3 Paso 8.10 — TL-02 cerrado y verificado (D-182)

La firma SHA-256 de ePayco no cubre `x_extra1` ni `x_extra2`, así que una
confirmación legítima se podía reenviar con el negocio cambiado. Se creó la
tabla `subscription_payment_intents` y las dos funciones que la escriben y la
resuelven; `create-epayco-session` registra la intención **antes** del checkout y
`epayco-webhook` resuelve por `x_id_invoice` y falla cerrado.

**Verificado en producción el 01-sep:** migración aplicada, **Control 197 en
verde (9 de 9 casos contra la base real)** con el ataque de TL-02 rechazado y
`ROLLBACK` limpio, y las dos Edge Functions desplegadas **en el orden correcto**
— primero la que escribe intenciones, luego la que las exige.

---

## 2. Lo que quedó a medias

### 2.1 El candado 2 de D-181 nunca se ha ejercitado

El `401` verifica el **primer** candado (la sesión). La comparación de
`x_cust_id_cliente` **no se ha probado contra una transacción real**, y está
escrita fallando cerrado. Si ePayco devolviera ese campo con otro nombre, la
confirmación instantánea empezaría a responder `403`. **No se pierde ningún
pago** —el webhook activa igual— pero el dueño no vería el aviso al volver.

Cómo salir de dudas con el próximo pago real:

```bash
curl -s https://secure.epayco.co/validation/v1/reference/REF_PAYCO_REAL | python -m json.tool | grep -i cust
```

### 2.2 Paso 8.8 sigue pendiente

El onboarding guiado "Primeros pasos" sigue reservado como el último del todo.
Las cuatro revisiones coincidieron en que hace falta antes de vender.

---

## 3. Qué NO hacer

- **No tocar `go_router` (TL-17), ni reorganizar a `lib/features/` (TL-18), ni
  partir los 4 archivos grandes (TL-11).** Es deuda real, pero son refactores
  sobre 50.840 líneas que funcionan con 262 pruebas en verde, a días de vender.
  Lo dijeron las dos últimas revisiones y se está de acuerdo. Post-lanzamiento.
- **No poner `verify_jwt = true` en `epayco-webhook`.** Lo llama ePayco
  servidor-a-servidor, sin sesión: se autentica con la firma SHA-256 (D-177). Si
  alguien lo "arregla", se caen todos los cobros.
- **No implementar el hallazgo UX-04 como fricción a eliminar.** Esa pantalla es
  el filtro de aceptación de D-125/D-138 ("nadie entra solo"), no un onboarding.
- **No creerle a una revisión de Antigravity sin verificarla**, especialmente en
  auth, RPC y pagos. En la última entrega inventó dos objetos que no existen
  (`platform_users`, `is_platform_admin()` — lo real es `platform_operators` y
  `private.beautyos_current_platform_role()`) y un script de restauración
  (`scripts/restaurar_archivos_storage.ps1`) que puso dentro de un runbook de
  recuperación de desastres como si fuera ejecutable.

---

## 4. Contradicciones encontradas y no resueltas por iniciativa propia

- **El índice del Registro se había quedado en D-173:** las siete decisiones de
  la Fase 8 (D-174 a D-180) estaban en la tabla pero no en el índice, que es lo
  que D-129 y D-131 advierten que no puede pasar. **Corregido a petición
  explícita del propietario**, junto con la cabecera, que decía "las 130
  decisiones" cuando van 182.
- **El control SQL de diagnóstico de perímetro que propuso Antigravity no corre**
  (referencia `n.nspname` fuera del alcance del bucle) y, por cómo está escrito,
  fallaría **exactamente** en el caso que existe para detectar. No se ha
  arreglado: no se pidió.
- **La otra mitad del hallazgo Z sigue abierta.** Ninguno de los 7 guiones de
  `scripts/` vuelve a subir los archivos de Storage tras una restauración.

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-181 y D-182: pasos 8.9 y
8.10 de la Fase 8, cierre del perímetro de pagos de ePayco).

D-181 (TL-01) y D-182 (TL-02) están desplegados y verificados en producción:
el perímetro de pagos de ePayco queda cerrado por los dos lados (la ruta de
verificación inmediata y el webhook). Control 197 en verde, 9 de 9 casos.

El contexto completo de la auditoría de 4 revisiones, con cada hallazgo
verificado contra el código, está en
docs/01_arquitectura/auditorias/AUDITORIA_4_REVISIONES_2026-09-01.md.
Ese documento NO manda sobre el Plan Maestro: es el expediente de evidencia.

Lo siguiente en la cola, por orden de daño:
1. TL-04 y TL-05 juntos (una migración pequeña): el portal de clientas devuelve
   cuatro errores distinguibles y permite enumerar qué celulares son clientas de
   un salón, sin tope. Ley 1581.
2. TL-19: la interfaz nunca consulta get_my_entitlements(), así que un salón en
   plan Básico ve módulos que no tiene, entra, y recibe una excepción de
   PostgreSQL en crudo. Es bug, es UX y es venta perdida a la vez.
3. Paso 8.8: onboarding guiado "Primeros pasos".
```
