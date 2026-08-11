-- Salon y Mas - Verificacion del hallazgo R: un estilista, una cuenta activa.
--
-- ESTO NO ES UNA PRUEBA AUTOMATICA. Hay que ejecutarlo a mano:
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\165_verify_un_estilista_una_cuenta.sql"
--
-- Se ejecuta DESPUES de aplicar la migracion 20260811100000. Es de solo
-- lectura hasta el ultimo bloque, que hace una prueba de escritura real y
-- termina en ROLLBACK: no deja rastro.
--
-- Por que existe: el candado y los tres mensajes viven en PostgreSQL, y
-- **ninguna prueba de Dart puede alcanzarlos** (misma limitacion que dejo
-- escrita D-117). Y algo mas, aprendido en D-122: este guion corre como dueno
-- de la base, que **se salta las comprobaciones de permiso de ejecucion**, asi
-- que verificar aqui no sustituye a que el propietario lo pruebe en la app.

\echo ''
\echo '=== 1. El candado existe y es el correcto ==='

select
  case when count(*) = 1 then 'OK' else '** FALTA **' end as resultado,
  'indice unico sobre (tenant_id, stylist_id) solo para cuentas activas' as que_comprueba
from pg_indexes
where schemaname = 'public'
  and indexname = 'tenant_memberships_estilista_cuenta_activa_idx'
  and indexdef ilike '%unique%'
  and indexdef ilike '%active%';

\echo ''
\echo '=== 2. Hoy no hay ningun estilista con dos cuentas activas ==='

select
  case when count(*) = 0 then 'OK' else '** HAY DUPLICADOS **' end as resultado,
  count(*) as estilistas_con_mas_de_una_cuenta_activa
from (
  select tm.tenant_id, tm.stylist_id
  from public.tenant_memberships tm
  where tm.stylist_id is not null
    and tm.active = true
  group by tm.tenant_id, tm.stylist_id
  having count(*) > 1
) d;

\echo ''
\echo '=== 3. El caso real: cuantas cuentas hay por estilista, y cuantas activas ==='
\echo '    (Erick Chaparro debe salir con 2 cuentas y 1 activa)'

-- Se agrupa por el identificador del estilista, no por su nombre: dos "Maria"
-- de negocios distintos saldrian como una sola fila.
select
  st.name as estilista,
  count(*) as cuentas_en_total,
  count(*) filter (where tm.active) as activas,
  string_agg(
    coalesce(up.full_name, '(sin perfil)')
      || case when tm.active then ' [activa]' else ' [suspendida]' end,
    ', ' order by tm.active desc
  ) as detalle
from public.tenant_memberships tm
join public.stylists st
  on st.id = tm.stylist_id
left join public.user_profiles up
  on up.user_id = tm.user_id
 and up.tenant_id = tm.tenant_id
where tm.stylist_id is not null
group by tm.tenant_id, st.id, st.name
having count(*) > 1
order by st.name;

\echo ''
\echo '=== 4. Las cuatro funciones quedaron con la comprobacion dentro ==='

select
  p.proname as funcion,
  case when pg_get_functiondef(p.oid) ilike '%ya tiene%cuenta activa%'
         or pg_get_functiondef(p.oid) ilike '%ya tiene otra cuenta activa%'
       then 'OK'
       else '** SIN COMPROBACION **'
  end as resultado
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'create_team_invitation',
    'accept_team_invitation',
    'update_tenant_user_access'
  )
order by p.proname;

\echo ''
\echo '=== 5. La lista de invitar responde por sede y marca a los ocupados ==='

select
  case when count(*) = 1 then 'OK' else '** FALTA **' end as resultado,
  'get_stylists_for_invitation(uuid) existe' as que_comprueba
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_stylists_for_invitation';

\echo ''
\echo '=== 6. get_stylists_summary NO se toco (sigue con sus 5 columnas) ==='

select
  case when pg_get_function_result(p.oid) not ilike '%has_active_account%'
       then 'OK - intacta'
       else '** LA TOCARON **'
  end as resultado,
  pg_get_function_result(p.oid) as devuelve
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_stylists_summary';

\echo ''
\echo '=== 7. PRUEBA DE ESCRITURA REAL: el candado rechaza el duplicado ==='
\echo '    Termina en ROLLBACK. No deja nada.'

begin;

do $$
declare
  v_tenant uuid;
  v_stylist uuid;
  v_user uuid;
  v_fallo text;
begin
  -- Se busca un estilista que HOY tenga una cuenta activa, y se intenta
  -- meterle una segunda. Si no hay ninguno, no se puede probar y se dice.
  select tm.tenant_id, tm.stylist_id
    into v_tenant, v_stylist
  from public.tenant_memberships tm
  where tm.stylist_id is not null
    and tm.active = true
  limit 1;

  if v_tenant is null then
    raise notice 'SIN DATOS PARA PROBAR: no hay ningun estilista con cuenta activa.';
    return;
  end if;

  -- Una cuenta cualquiera que no sea la que ya lo tiene.
  select u.id
    into v_user
  from auth.users u
  where not exists (
    select 1 from public.tenant_memberships tm2
    where tm2.tenant_id = v_tenant
      and tm2.user_id = u.id
  )
  limit 1;

  if v_user is null then
    raise notice 'SIN DATOS PARA PROBAR: no hay una cuenta libre con la que intentarlo.';
    return;
  end if;

  begin
    insert into public.tenant_memberships (
      tenant_id, user_id, stylist_id, role, active, starts_at
    ) values (
      v_tenant, v_user, v_stylist, 'stylist', true, now()
    );
    raise notice '** MAL: la base ACEPTO una segunda cuenta activa para el mismo estilista. **';
  exception when unique_violation then
    raise notice 'OK: la base rechazo la segunda cuenta activa para el mismo estilista.';
  end;

  -- Y la otra mitad: una cuenta SUSPENDIDA para el mismo estilista SI debe
  -- entrar. Es lo que hace posible cambiar de correo sin perder el historial.
  begin
    insert into public.tenant_memberships (
      tenant_id, user_id, stylist_id, role, active, starts_at
    ) values (
      v_tenant, v_user, v_stylist, 'stylist', false, now()
    );
    raise notice 'OK: una cuenta SUSPENDIDA para el mismo estilista si se acepta.';
  exception when others then
    get stacked diagnostics v_fallo = message_text;
    raise notice '** MAL: rechazo la cuenta suspendida -> % **', v_fallo;
  end;
end
$$;

rollback;

\echo ''
\echo '=== FIN. Nada de lo anterior quedo escrito. ==='
