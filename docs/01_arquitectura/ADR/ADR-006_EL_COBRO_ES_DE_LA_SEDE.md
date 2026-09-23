# ADR-006 — El cobro es de la sede; el acceso sigue siendo del negocio

**Estado:** aceptada
**Fecha:** 2026-09-23 (recoge D-188, D-190 a D-193, D-239 y D-252)

## Contexto

ADR-004 aplicaba los planes al **negocio**: una suscripción por *tenant*. El
01-sep (D-188) el eje de cobro pasó a ser **cuántas sedes tiene activas** un
negocio, y entre el 02 y el 22-sep se construyó el cobro por sede a trozos. Cada
trozo tuvo su decisión, pero ninguna dejó escrito el modelo estructural: durante
dos semanas convivieron un precio del negocio y un precio de cada sede, **los dos
correctos y ninguno diciendo cuál mandaba** (D-239, hallazgo AG), con dos botones
de pago en la misma pantalla.

## Decisión

1. **Quien paga es la sede.** Cada sede tiene su suscripción
   (`branch_subscriptions`): estado, período y precio propios.
2. **El precio negociado vive solo en la sede**, en pesos. No existe precio de
   negocio que cobre, ni descuento porcentual (D-252).
3. **Quien puede entrar sigue siendo el negocio.** `tenant_subscriptions` decide
   el acceso a la aplicación, la prueba gratis y el aviso de vencimiento (D-068).
4. **La sede principal cose las dos:** pagarla mueve también la suscripción del
   negocio. Pagar una secundaria no (D-192), porque su cobro prorrateado termina
   en la fecha de corte que el negocio ya tiene.
5. **El camino de cobro del negocio se cierra en la entrada, no se borra:** la
   maquinaria que liquida un pago de negocio sigue viva para que un pago rezagado
   se registre bien (D-252).

## Consecuencias

- Una cadena de tres sedes paga tres veces; cada sede se negocia por separado,
  como en la realidad.
- **Hay dos estados que leer**, y confundirlos es el error más probable: una sede
  puede estar al día y el negocio vencido, o al revés.
- Las métricas de la plataforma y las comisiones de partners **tienen que sumar
  sedes** (D-231, D-232).
- El historial de pagos **tiene que decir de qué sede** fue cada cobro (paso 9.40,
  pendiente).
- **Riesgo abierto:** este camino **nunca ha cobrado un peso real** (paso 9.8).

## Alternativas descartadas

- **Seguir cobrando por negocio y repartir hacia las sedes:** no permite negociar
  cada local, y la fecha de corte de una sede nueva no tendría dónde vivir.
- **Que el negocio siga cobrando y además cada sede:** habría subido a un socio de
  diseño de una sola sede de $50.000 a $130.000, rompiendo lo prometido en
  público (D-239).
- **Borrar la función de cobro del negocio:** el webhook la usa para liquidar;
  borrarla habría dejado de registrar pagos confirmados (D-252).

## Relación con otros ADR

**No reemplaza a ADR-004**, lo completa: los entitlements siguen aplicándose en
el servidor. Lo que cambia es **a quién se le cobra**, no cómo se decide qué puede
usar cada uno.
