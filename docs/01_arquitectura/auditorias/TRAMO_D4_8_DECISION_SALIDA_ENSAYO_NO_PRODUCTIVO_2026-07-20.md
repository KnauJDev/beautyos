# Tramo D4.8 — decisión de salida del ensayo no productivo

**Fecha:** 20 de julio de 2026
**Estado:** decidido; sin cambios remotos
**Proyecto objetivo:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Base Git:** `09a27ff Documentar reversibilidad remota del Tramo D4.7`

## 1. Objetivo

Decidir si, después de D4.6 y D4.7, BeautyOS puede preparar D5 directamente o si
antes debe consolidar una fotografía completa final del entorno no productivo.

## 2. Evidencia revisada

Se revisaron las fuentes canónicas del tramo, el estado de Git y las auditorías
D4.6/D4.7:

- `git status --short`: limpio al inicio.
- `git log -1 --oneline`: `09a27ff Documentar reversibilidad remota del Tramo D4.7`.
- D4.6 alineó `beautyos-dev` con D3.2 y D3.4 mediante migraciones MCP.
- D4.7 demostró reversibilidad de las seis firmas heredadas y dejó el estado
  endurecido reaplicado.
- El changelog oficial de Supabase fue consultado el 20/07/2026; no se detectó
  un cambio reciente que modifique el criterio de permisos, `SECURITY DEFINER` o
  migraciones para esta decisión.

Se confirmó además que el historial remoto de `beautyos-dev` conserva:

- `20260720200109_tramo_d3_2_20260720183122_reemplazos_lectura_por_sede`
- `20260720200141_tramo_d3_4_20260720190528_revocar_rpc_heredadas`

D4.7 no creó migración nueva, como correspondía para una prueba de
reversibilidad.

## 3. Decisión

No se debe saltar directamente a D5 con la evidencia fragmentada D4.6/D4.7.

Antes de cualquier acción productiva, el siguiente micro-paso debe ser D4.9:
una fotografía completa de salida no productiva, read-only, en `beautyos-dev`.

## 4. Razón

D4.6 y D4.7 prueban piezas críticas:

- migraciones D3.2/D3.4 aplicadas y registradas;
- permisos heredados cerrados;
- RPC `_v2` presentes e intactas;
- reversibilidad operativa de las seis firmas heredadas;
- cero `branch_id` nulos en las 15 tablas operativas revisadas.

Sin embargo, antes de preparar D5 conviene tener una evidencia única, fechada y
posterior a todas las pruebas remotas, que consolide:

1. identidad inequívoca del entorno;
2. historial remoto de migraciones;
3. matriz final de permisos heredadas/_v2;
4. conteos agregados y cero `branch_id` nulos;
5. asesores Supabase vigentes;
6. lista de deuda conocida que no bloquea D5;
7. decisión explícita de no tocar producción sin respaldo, vista previa exacta y
   autorización separada.

Esto reduce el riesgo de llevar a D5 evidencia parcial o tomada antes de la
prueba de reversibilidad.

## 5. Alcance propuesto para D4.9

D4.9 debe ser solo lectura y no debe crear migraciones ni ejecutar DDL/DML.

Criterios mínimos:

- confirmar proyecto `beautyos-dev` (`eogppgbdnwxdtcbctaol`);
- listar migraciones remotas y confirmar D3.2/D3.4;
- repetir fotografía estructural de RPC heredadas y `_v2`;
- confirmar estado final de permisos:
  - heredadas: sin `PUBLIC`, `anon` ni `authenticated`; con `service_role`;
  - `_v2`: sin `PUBLIC` ni `anon`; con `authenticated` y `service_role`;
- confirmar que las 15 tablas operativas mantienen cero `branch_id` nulos;
- ejecutar asesores de seguridad y rendimiento;
- registrar cualquier deuda como observación, no como corrección automática.

## 6. Cierre

D4.8 queda cerrado como decisión de prudencia. La siguiente microcompuerta es
D4.9: fotografía completa de salida no productiva. D5 queda explícitamente
pendiente y no autorizado.
