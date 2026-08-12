-- Salon y Mas - Verificacion de los pasos 3.5 y 3.6.
--
-- NO ES UNA PRUEBA AUTOMATICA. Se ejecuta a mano DESPUES de la migracion:
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\167_verify_precios_y_limites.sql"
--
-- De solo lectura hasta el ultimo bloque, que hace una prueba de escritura real
-- terminada en ROLLBACK: no deja rastro.

\echo ''
\echo '=== 1. Los tres precios, en PESOS enteros ==='

select code, name, price_cop, currency_code,
       case when price_cop is null then '** SIN PRECIO **'
            when price_cop between 100000 and 999999 then 'OK'
            else '** REVISAR: no parece pesos **'
       end as resultado
from public.plans
where status = 'active'
order by price_cop;

\echo ''
\echo '=== 2. La columna ya no se llama "centavos" ==='

select
  case when count(*) filter (where column_name = 'price_cop') = 1
        and count(*) filter (where column_name = 'price_cents') = 0
       then 'OK - renombrada' else '** MAL **' end as resultado
from information_schema.columns
where table_schema = 'public' and table_name = 'plans';

\echo ''
\echo '=== 3. Los limites por plan. Vacio = SIN LIMITE ==='

select p.code as plan, f.key as capacidad, pf.enabled,
       coalesce(pf.limit_value::text, 'sin limite') as tope
from public.plan_features pf
join public.plans p on p.id = pf.plan_id
join public.features f on f.id = pf.feature_id
where f.key in ('branches', 'team_members')
order by f.key, p.price_cop;

\echo ''
\echo '=== 4. Las columnas de precio por cliente existen ==='

select string_agg(column_name, ', ' order by column_name) as columnas_nuevas,
       case when count(*) = 5 then 'OK' else '** FALTAN **' end as resultado
from information_schema.columns
where table_schema = 'public' and table_name = 'tenant_subscriptions'
  and column_name in ('price_cop','discount_percent','discount_ends_at','price_reason','is_founder');

\echo ''
\echo '=== 5. Cuanto paga hoy el unico negocio ==='
\echo '    (Naguara de Unas: sin precio propio ni descuento -> paga el de lista)'

select t.name as negocio, p.code as plan, e.base_cop, e.descuento, e.precio_cop
from public.tenants t
join public.tenant_subscriptions ts on ts.tenant_id = t.id
join public.plans p on p.id = ts.plan_id
cross join lateral private.beautyos_precio_efectivo(t.id) e;

\echo ''
\echo '=== 6. Los limites se hacen cumplir de verdad ==='
\echo '    Prueba de escritura real. Termina en ROLLBACK.'

begin;

do $$
declare
  v_tenant uuid;
  v_plan_basico uuid;
  v_fallo text;
begin
  select id into v_tenant from public.tenants limit 1;
  select id into v_plan_basico from public.plans where code = 'basico';

  if v_tenant is null or v_plan_basico is null then
    raise notice 'SIN DATOS PARA PROBAR.';
    return;
  end if;

  -- Se pone el negocio en Basico, que permite 1 sede, y se comprueba el
  -- ayudante directamente: es lo que usan create_branch y la invitacion.
  update public.tenant_subscriptions
     set plan_id = v_plan_basico
   where tenant_id = v_tenant;

  -- Con 0 sedes deberia dejar.
  begin
    perform private.beautyos_require_limit(v_tenant, 'branches', 0, 'sedes');
    raise notice 'OK: con 0 sedes, el Basico deja crear.';
  exception when others then
    get stacked diagnostics v_fallo = message_text;
    raise notice '** MAL: rechazo con 0 sedes -> % **', v_fallo;
  end;

  -- Con 1 sede (su tope) NO deberia dejar.
  begin
    perform private.beautyos_require_limit(v_tenant, 'branches', 1, 'sedes');
    raise notice '** MAL: el Basico dejo crear una SEGUNDA sede. **';
  exception when others then
    get stacked diagnostics v_fallo = message_text;
    raise notice 'OK: rechazo la segunda sede -> %', v_fallo;
  end;

  -- Sin limite: el Profesional no tiene tope de sedes.
  update public.tenant_subscriptions
     set plan_id = (select id from public.plans where code = 'profesional')
   where tenant_id = v_tenant;

  begin
    perform private.beautyos_require_limit(v_tenant, 'branches', 99, 'sedes');
    raise notice 'OK: el Profesional acepta 99 sedes (vacio = sin limite).';
  exception when others then
    get stacked diagnostics v_fallo = message_text;
    raise notice '** MAL: rechazo al Profesional -> % **', v_fallo;
  end;
end
$$;

rollback;

\echo ''
\echo '=== FIN. El plan del negocio quedo como estaba. ==='
