# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Un solo plan por sede", D-188 a D-192)

**Bloque documentado:** decisiones **D-188 a D-192** · Pasos **8.15 y 8.16** de la **FASE 8**.

**Estado:** `flutter analyze` limpio (0/0) y **282 de 282 pruebas en verde**. Etapas 1, 2 y 3a **aplicadas y verificadas en producción**. Etapa 3b: **el servidor está hecho y pendiente de aplicar; falta la pantalla**.

> El bloque anterior (D-181 a D-187, la auditoría de 4 revisiones y sus seis
> bloqueadores) está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-01_D182.md`.
> Sigue siendo la referencia de por qué el perímetro de pagos está como está.

---

## 1. Lo que cambió: el modelo de negocio

Se retiró la escalera de tres planes y quedó **un solo plan, "Todo Incluido",
cobrado por sede activa**. El eje de monetización dejó de ser *qué módulos te
dejo usar* y pasó a ser *cuántas sedes tienes*.

**Esto resolvió la Idea I-14 sin decidirla:** llevaba desde el 12-ago esperando
cinco visitas a salones reales para repartir 15 casillas, y ya no hay casillas.

| | |
|---|---|
| **Precio de lista** | **$150.000 por sede al mes** — el argumento es *"$5.000 al día"* |
| **Descuento de lanzamiento** | **No se publica.** Ni cifra ni cupo. Se negocia uno a uno y se fija como precio pactado desde el panel |
| **Equipo** | **10 personas por salón**: el dueño + 9 cuentas |
| **Sin tope** | Clientas, citas, tickets y fotos |

### Las tres cuentas que no cuadraban, y que quedaron corregidas

1. **$80.000 sobre $120.000 no era el 50%, era el 33%** (D-188). Y modelarlo
   como porcentaje daba **$80.004** por redondeo, que `beautyos_procesar_evento_epayco`
   habría comparado contra el pago (D-159). Por eso el descuento se fija como
   **precio pactado, nunca como porcentaje**.
2. **El tope de equipo va en 9, no en 10** (D-189), porque **el propietario no
   cuenta contra el límite** — D-136: *"su cuenta no es de equipo, es el
   negocio"*. Poner 10 habría dado once personas.
3. **$150.000 / 30 = $5.000 exactos.** Hay una prueba que lo comprueba: si el
   precio dejara de ser divisible por 30, la frase de venta se volvería mentira
   y nadie se enteraría.

---

## 2. Dónde va cada etapa

| Etapa | Qué | Estado |
|---|---|---|
| **1** | Catálogo de un solo plan, capacidades abiertas, pantalla pública | ✅ **Aplicada y verificada** (D-188, D-189) |
| **2** | Suscripción por sede: `branch_subscriptions` | ✅ **Aplicada y verificada** (D-190) |
| **3a** | `branch_id` en las intenciones de pago + cálculo del cargo por sede | ✅ **Aplicada y verificada** (D-191) |
| **3b** | Checkout, webhook, alertas y pantalla de pago | 🔄 **Servidor hecho** (D-192), pendiente de aplicar. Faltan pantalla y alertas |

### 🔴 Hasta que la 3b esté hecha no se puede vender la segunda sede

Hoy un negocio paga **una** suscripción. Una sede nueva nace `pending` y **la
activa a mano el dueño de la plataforma** con `platform_set_branch_subscription`,
que es como se va a vender en la práctica las primeras semanas: hablando por
WhatsApp y cobrando aparte.

---

## 3. Lo que quedó a medias

### 3.1 D-192 sin aplicar, y esta vez SI hay que desplegar

Aqui ya no vale aplicar solo el SQL: las dos Edge Functions cambiaron. En este
orden exacto -- primero la base de datos, y las funciones solo cuando la
funcion que llaman ya exista:

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260902160000_pago_de_sede_etapa3b_d192.sql"
```

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\204_test_pago_de_sede_etapa3b.sql"
```

```bash
npx supabase functions deploy create-epayco-session
```

```bash
npx supabase functions deploy epayco-webhook
```

### 3.2 🔴 El checkout de la aplicacion quedo obsoleto con D-188

`epayco_checkout_service.dart` sigue ofreciendo un desplegable con **los tres
planes retirados y sus precios viejos** ($160.000 / $200.000 / $240.000), y por
defecto elige `profesional`, que ya no existe.

**El cobro sale bien** -- el servidor calcula el monto y el plan retirado cae al
plan real (D-159, D-160) -- **pero al dueno se le ensena un precio que no es el
suyo**. Encontrado el 02-sep al construir D-192. Se arregla junto con la
pantalla de sedes.

### 3.3 La pantalla pública nunca se vio renderizada

`public_plans_page.dart` se rediseñó entera para el plan único y **compila y
pasa las pruebas, pero nadie la ha visto con los ojos**: no se pudo levantar el
servidor web en esas sesiones. Para una página comercial, eso es justo lo que el
analizador no dice.

### 3.4 El tope de equipo es por NEGOCIO, no por sede

`create_team_invitation` cuenta las cuentas del tenant entero. La promesa de
*"10 por sede"* (D-189) **no es cierta para multi-sede** hasta que se arregle.
Va con la 3b. Hoy no perjudica a nadie porque la segunda sede tampoco se puede
vender.

### 3.5 El candado 2 de D-181 sigue sin ejercitarse

La comparación de `x_cust_id_cliente` no se ha probado contra una transacción
real. En el próximo pago:

```bash
curl -s https://secure.epayco.co/validation/v1/reference/REF_PAYCO_REAL | python -m json.tool | grep -i cust
```

---

## 4. Qué NO hacer

- **No borrar los candados de plan de D-184 y D-187.** Con el plan único dejaron
  de dispararse solos, pero son **el mecanismo que necesita la sede impaga** en
  la 3b. Parecen código muerto y no lo son.
- **No tocar `get_my_entitlements` para forzar `true`.** El plan trae todo
  dentro, así que ya devuelve todo en `true` sola. Forzarlo rompería el único
  sitio donde vive la verdad de qué cubre un plan y los overrides por cliente
  del panel (D-172).
- **No borrar los tres planes viejos.** Están `retired`, y `tenant_subscriptions`
  y el histórico de pagos los referencian.
- **No darle a cada sede su propia fecha de corte.** Un salón, una fecha de
  cobro (D-191). Tres locales con tres cobros en tres días distintos es cómo se
  pierde la confianza del dueño.
- **No poner `verify_jwt = true` en `epayco-webhook`.** Lo llama ePayco
  servidor-a-servidor y se autentica con la firma SHA-256 (D-177).

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-188 a D-192: un solo plan
"Todo Incluido" cobrado por sede, $150.000 de lista).

Etapas 1, 2 y 3a aplicadas y verificadas. De la 3b, el SERVIDOR está hecho
(D-192) y sin aplicar: migración 20260902160000, control 204 y las dos Edge
Functions. Ver apartado 3.1, que esta vez SÍ lleva despliegue y tiene orden.

Lo que falta de la 3b:
1. Arreglar `epayco_checkout_service.dart`, que quedó obsoleto con D-188: ofrece
   los tres planes retirados con sus precios viejos. Ver apartado 3.2.
2. Pantalla en Configuración: lista de sedes con su estado y botón de pago,
   consumiendo `get_branch_subscriptions()`, que ya existe y no la llama nadie.
   El botón manda `branchId` a `create-epayco-session`, que ya lo acepta.
3. Alertas de vencimiento por sede (hoy son por negocio, D-143).
4. El tope de equipo pasa a contarse por sede (D-189 lo prometió "por sede" y
   `create_team_invitation` cuenta el tenant entero).

Ojo con lo que NO hay que tocar: `beautyos_procesar_evento_epayco` se dejó
intacta a propósito (D-192). El cobro por sede vive en
`beautyos_procesar_pago_de_sede`, aparte, porque las reglas de monto son
distintas: un prorrateo puede estar por debajo del piso de $10.000 que aquella
exige.
```
