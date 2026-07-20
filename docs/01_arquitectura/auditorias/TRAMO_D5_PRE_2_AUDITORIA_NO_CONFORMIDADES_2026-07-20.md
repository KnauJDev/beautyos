# Tramo D5-pre.2 — auditoría de no conformidades del Tramo D

**Fecha:** 20 de julio de 2026
**Estado:** completado localmente; D5 permanece en NO-GO
**Producción modificada:** no
**Conexiones remotas realizadas:** ninguna
**Base Git:** `b8ad9d5 Documentar bloqueo productivo de D5`

## 1. Objetivo

Revisar la conformidad técnica y documental de D1–D5 antes de declarar cerrado
el Tramo D. Esta auditoría no aplica migraciones ni consulta Supabase remoto.

## 2. Controles conformes

- `flutter analyze`: sin hallazgos.
- `flutter test`: 5 pruebas aprobadas.
- Flutter no contiene llamadas a las seis RPC heredadas sustituidas.
- `BranchContext` rechaza un contexto sin `branch_id` y la interfaz bloquea al
  usuario sin sede operativa asignada.
- D2 comprueba cero nulos dentro de la misma transacción antes de aplicar
  `NOT NULL` a las 15 tablas.
- Las seis RPC `_v2` de D3.2 reciben `p_branch_id`, resuelven autorización en
  backend, fijan `search_path=pg_catalog` y revocan `PUBLIC`/`anon`.
- D3.4 conserva reversión para las seis firmas sustituidas sin abrir `anon`.
- El inventario operativo Flutter ya lee stock desde `branch_products`; la
  columna heredada `products.current_stock` puede permanecer hasta Tramo F.

## 3. No conformidades bloqueantes

| ID | Hallazgo | Evidencia | Cierre exigido |
|---|---|---|---|
| NC-D-01 | Identidad productiva contradictoria. El mismo ref `eogppgbdnwxdtcbctaol` figura como producción en C y como no productivo en D4. | D5-pre.1, despliegue C y D4.2–D4.9. | Declaración inequívoca del propietario y reconciliación del historial remoto correcto. |
| NC-D-02 | Ocho triggers conservan fallback de sede principal: seis raíces operativas y dos de ticket opcional. `NOT NULL` no lo impide porque el trigger completa `branch_id` antes de validar la restricción. | `beautyos_resolve_branch`, `beautyos_set_root_branch`, `beautyos_set_optional_ticket_branch` y D3.0. | Reescribirlos para exigir sede explícita cuando no exista padre operativo, preservando los siete triggers derivados como integridad. |
| NC-D-03 | D3.0 clasificó 52 RPC heredadas; D3.4 solo resolvió las seis que recibieron reemplazo en D3.2. No existe migración local que cierre el acceso externo de las otras 46 según su clasificación. | D3.0 y únicas migraciones D3.2/D3.4. | Inventario vivo y migración por grupos: 24 sin consumidores, 6 implementaciones internas, 13 tenant/catálogo y 3 helpers; no eliminar funciones con dependencias. |
| NC-D-04 | La autorización heredada basada en `user_profiles` sigue presente en RPC y helpers. | D3.0 y referencias versionadas a `user_profiles`. | Migración gradual a memberships o redefinición explícita y aprobada de este objetivo fuera del cierre D. |
| NC-D-05 | El paquete D4.10 propone D3.2, D2 y D3.4, pero no incluye NC-D-02, NC-D-03 ni NC-D-04. Por ello no satisface los seis objetivos ni la puerta “no existe ruta antigua insegura” del plan rector. | D4.10 frente a `IMPACTO_Y_MIGRACION_MULTISEDE.md`. | Sustituir el paquete D5 después de cerrar o reubicar formalmente estas brechas. |
| NC-D-06 | Faltan condiciones operativas: proyecto exacto, respaldo fresco restaurado, ventana fechada y evidencia de Flutter D1 disponible para usuarios productivos. | D4.10 y D5-pre.1. | Completar todos los criterios GO antes de cualquier acción productiva. |

## 4. Deuda conocida no bloqueante para este tramo

- protección contra contraseñas filtradas deshabilitada: obligatoria antes del
  piloto real, pero no se corrige dentro de una migración D sin autorización;
- políticas `user_profiles` con `auth_rls_initplan`: deuda de rendimiento;
- índices todavía sin uso en un entorno pequeño: no deben retirarse sin carga y
  `EXPLAIN` representativos;
- tablas cerradas con RLS sin políticas directas: compatible con el modelo RPC
  actual mientras sus grants permanezcan mínimos.

Esta deuda debe seguir registrada y volver a compararse con asesores en la
fotografía productiva final.

## 5. Dictamen

El código Flutter y el subconjunto D2/D3.2/D3.4 están conformes con su alcance
estrecho. El **Tramo D completo no puede declararse terminado** porque mantiene
fallbacks de escritura y una superficie heredada mayor que el paquete D5.

No se autoriza ejecutar D5 en producción con el paquete actual. El orden seguro
de corrección es:

1. D3.5.1: diseñar y ensayar localmente el endurecimiento de los ocho triggers;
2. D3.5.2: reconciliar y cerrar permisos de las 46 RPC restantes por grupo;
3. D3.5.3: decidir y ejecutar la migración de autorización a memberships o
   reubicarla formalmente mediante decisión arquitectónica;
4. rehacer D4/D5 sobre el alcance completo y el proyecto inequívoco;
5. crear respaldo fresco, restaurarlo y solicitar autorización productiva
   específica.

El siguiente micro-paso recomendado es **D3.5.1**, exclusivamente local y sin
modificar producción.
