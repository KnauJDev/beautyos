-- ==============================================================================
-- PASO 1 DEL PLAN DEL PRIMER CLIENTE REAL: capacidades nuevas para poder
-- apagarle a cada negocio lo que no usa. (D-310, sobre D-308)
-- ==============================================================================
--
-- QUE PASA
--
-- David Rojas quiere solo agenda. El propietario decidio apagarle caja y
-- cobros, finanzas, inventario, compras y gastos, comisiones, fotos, resenas y
-- blog, y que lo apagado DESAPAREZCA de su app. La lectura viva
-- (intervenciones/extraer_capacidades_por_negocio_paso1.sql) mostro que:
--
--   * El servidor ya sabe apagar una capacidad a un negocio:
--     `platform_set_tenant_feature_override` acepta enabled = false, deja su
--     evento en el historial, y la excepcion gana sobre el plan
--     (`beautyos_resolve_entitlement` la devuelve con source = 'override').
--     `platform_delete_tenant_feature_override` la cierra sin borrarla.
--   * Pero solo hay capacidades para inventario, reportes, fotos, resenas y
--     redes. Faltan caja y cobros, comisiones y blog.
--   * Una capacidad SIN fila en el plan del negocio se resuelve como
--     'no_incluida_en_plan' (negada). Por eso cada capacidad nueva entra
--     ENCENDIDA en los cuatro planes: nadie nota nada hasta que el Panel se la
--     apague a un negocio.
--
-- QUE CAMBIA, Y QUE NO
--
--   Solo se ANADEN filas: tres en `features` y doce en `plan_features`.
--   No se reescribe ninguna funcion ni se toca ninguna fila existente.
--   `on conflict do nothing`: correrla dos veces no hace nada la segunda.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   0. El respaldo (regla 15)
--   1. Esta migracion con aplicar_sql.ps1
--   2. El control 239 (supabase/sql/239_test_capacidades_por_negocio_paso1.sql)
-- ==============================================================================

begin;

insert into public.features (key, name, description) values
  ('cash_register', 'Caja y cobros',
   'Tickets, cobros y caja del dia. Apagado, la agenda no ofrece cobrar.'),
  ('commissions', 'Comisiones',
   'Comisiones del equipo y el panel financiero de cada estilista.'),
  ('blog', 'Blog',
   'Articulos del blog del salon.')
on conflict (key) do nothing;

insert into public.plan_features (plan_id, feature_id, enabled)
select p.id, f.id, true
from public.plans p
cross join public.features f
where f.key in ('cash_register', 'commissions', 'blog')
on conflict (plan_id, feature_id) do nothing;

commit;
