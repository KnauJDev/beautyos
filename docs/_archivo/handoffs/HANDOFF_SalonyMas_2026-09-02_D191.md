# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Un solo plan por sede", D-188 a D-194)

**Bloque documentado:** decisiones **D-188 a D-194** · Pasos **8.15 y 8.16** de la **FASE 8**.

**Estado:** `flutter analyze` limpio (0/0) y **292 de 292 pruebas en verde**. **Las tres etapas de D-188 están cerradas y verificadas en producción.** El cobro por sede funciona de extremo a extremo: catálogo, suscripción por sede, cobro con prorrateo y pantalla.

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
| **3b** | Checkout y webhook por sede, y la pantalla de pago | ✅ **Cerrada** (D-192, D-193) |

### Ya se puede vender la segunda sede

Una sede nueva nace `pending`, aparece en Configuración con su estado y su
botón, y al pagarla se activa sola con el prorrateo hasta la fecha de corte del
negocio. El dueño de la plataforma **sigue pudiendo activarla a mano** con
`platform_set_branch_subscription` para casos negociados, igual que los
overrides de D-172.

---

## 2-bis. Reportes consolidados, y quién ve qué (D-194)

El dueño con dos locales ya puede ver su negocio entero: Reportes gana un
selector *Esta sede / Todas las sedes*, con el desglose de cuánto puso cada una.

**`get_tenant_reports_v3` llama a `get_branch_reports_v3` sede por sede y suma**,
en vez de duplicar sus 250 líneas. La lógica de qué es una venta vive en un solo
sitio. El precio de esa decisión es que **las dos funciones quedan acopladas por
el nombre de cada columna**: si alguien renombra una en la de una sede, la
consolidada sumaría **cero en silencio**. El Control 205 compara las dos listas
de columnas justamente para cazar eso — **no lo quites**.

### Y una corrección que conviene tener escrita

**Solo el `tenant_owner` ve todas las sedes sin que nadie se las asigne.**
`beautyos_resolve_branch_access` lo exceptúa por rol; **el `admin` no** — necesita
su fila en `branch_memberships`, gestionable desde Usuarios desde D-179. Así que
un admin recibe el consolidado de **sus** sedes, no del negocio entero.

**El estado de pago no influye en el acceso ni en los reportes.** Una sede en
mora sigue apareciendo: sus ventas ocurrieron. Cobrar y reportar son dos cosas
distintas.

---

## 3. Lo que quedó a medias

### 3.1 Las alertas de vencimiento siguen siendo por negocio

`send-subscription-expiry-alerts` (D-143) avisa a los 10, 5 y 3 días mirando
`tenant_subscriptions`. Una sede secundaria que se atrase **no genera aviso**.
No es urgente mientras no haya salones con dos sedes pagando, pero el día que
los haya, el primero se enterará tarde.

### 3.2 El tope de equipo sigue siendo por NEGOCIO, no por sede

`create_team_invitation` cuenta las cuentas del tenant entero. La promesa de
*"10 por sede"* (D-189) **no es cierta para multi-sede**. Hoy juega a favor del
cliente —tiene menos de lo que se le prometió, no más— pero es una promesa
comercial que el código no cumple.

### 3.3 La pantalla pública nunca se vio renderizada

`public_plans_page.dart` se rediseñó entera para el plan único y **compila y
pasa las pruebas, pero nadie la ha visto con los ojos**: no se pudo levantar el
servidor web en esas sesiones. Para una página comercial, eso es justo lo que el
analizador no dice. Lo mismo vale para la tarjeta de sedes de D-193 y para el
desglose por sede de D-194.

### 3.4 El candado 2 de D-181 sigue sin ejercitarse

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
- **No quitar el caso 2 del Control 205.** Es lo único que impide que un
  cambio de nombre de columna deje el consolidado sumando cero en silencio.
- **No poner `verify_jwt = true` en `epayco-webhook`.** Lo llama ePayco
  servidor-a-servidor y se autentica con la firma SHA-256 (D-177).

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-188 a D-193: un solo plan
"Todo Incluido" cobrado por sede, $150.000 de lista).

Las TRES etapas de D-188 están cerradas y verificadas en producción. El cobro
por sede funciona de extremo a extremo: catálogo, branch_subscriptions, cobro
con prorrateo hasta la fecha de corte del negocio, y la pantalla en
Configuración. D-194 añadió los reportes consolidados de todas las sedes.

Lo que queda, por orden de daño:
1. Alertas de vencimiento por sede (apartado 3.1). Hoy una sede secundaria que
   se atrase no avisa a nadie.
2. El tope de equipo por sede (apartado 3.2). D-189 lo prometió "por sede" y
   create_team_invitation cuenta el tenant entero.
3. Mirar con los ojos la pantalla pública de planes y la tarjeta de sedes
   (apartado 3.3). Compilan y pasan pruebas; nadie las ha visto.

Y fuera de esto, del Plan Maestro: la Fase 3 tiene dos casillas de 👤 abiertas
(3.2 consultar a un contador sobre DIAN e IVA, y 3.4 subir Supabase a Pro).

Ojo con lo que NO hay que tocar: beautyos_procesar_evento_epayco se dejó intacta
a propósito (D-192). El cobro por sede vive aparte, en
beautyos_procesar_pago_de_sede, porque las reglas de monto son distintas: un
prorrateo puede estar por debajo del piso de $10.000 que aquella exige.
```
