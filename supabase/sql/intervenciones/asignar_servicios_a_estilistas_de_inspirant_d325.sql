-- ASIGNA los servicios de Inspirant (David) a sus 4 estilistas (D-325).
-- SÍ MODIFICA: solo agrega asignaciones; no quita ninguna.
--
-- POR QUÉ. De sus 28 servicios solo 3 tenían estilista, y la reserva en línea
-- solo ofrece lo que alguien hace (D-322): los otros 25 salían con "Pregunta
-- por WhatsApp". El 09-oct el propietario pidió asignarlos todos a los 4,
-- con el sí de David ("todos hacen todo"), menos "Corte personalizado y
-- asesoría", que va SOLO a David (era su categoría "solo David marin").
-- Quedan 27 servicios para Antonio, Diana y Mauricio, y 28 para David: 109
-- asignaciones. David puede quitar cualquiera después en Estilistas.
--
-- CÓMO SE ESCRIBIÓ (regla 10). Desde la lectura viva
-- (`extraer_estilistas_de_inspirant.sql`, 09-oct): los 4 estilistas por su id,
-- los 4 activos en su única sede, y los 28 servicios activos en ella. Los dos
-- INSERT son los de `set_stylist_services` (la función de la pantalla
-- Estilistas) tal cual: el del catálogo (`stylist_services`) y el de la sede
-- (`branch_stylist_services`), que es el que mira la reserva en línea
-- (`public_get_bookable_services`). Sin la parte de esa función que DESACTIVA
-- lo no elegido: aquí solo se agrega. Si algo no cuadra con lo leído, no se
-- cambia NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\respaldo_supabase.ps1"
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\asignar_servicios_a_estilistas_de_inspirant_d325.sql"
--
-- Al final dice cuántos servicios tiene cada estilista y cuántos se pueden
-- reservar en línea.

set client_encoding = 'UTF8';

begin;

do $asignar$
declare
  v_tenant uuid;
  v_david uuid := 'dd03ca0d-ec73-4ae5-8133-78905449d7d4';
  v_asesoria uuid := '0418e040-05e4-4872-83e7-ad2f3f4f74f1';
  v_estilistas uuid[] := array[
    '1db1bfa7-331b-4014-83ec-c88f92b642d0',  -- Antonio
    'dd03ca0d-ec73-4ae5-8133-78905449d7d4',  -- David Marin
    '2830433a-9b1e-4fa3-979e-df51f8d05d6d',  -- Diana Parra
    '759c78d8-0a7e-46f5-b25b-e5ec3d491831'   -- Mauricio Mendez
  ]::uuid[];
  v_n integer;
begin
  select t.id into v_tenant from public.tenants t where t.slug = 'inspirant-salon';
  if v_tenant is null then
    raise exception 'No encontre el salon inspirant-salon. No se cambio nada.';
  end if;

  select count(*) into v_n
  from public.stylists st
  where st.tenant_id = v_tenant and st.active and st.id = any(v_estilistas);
  if v_n <> 4 then
    raise exception 'Se esperaban los 4 estilistas activos leidos el 09-oct y hay %. No se cambio nada.', v_n;
  end if;

  select count(*) into v_n
  from public.services s
  where s.tenant_id = v_tenant and s.active;
  if v_n <> 28 then
    raise exception 'Se esperaban los 28 servicios activos leidos el 09-oct y hay %. No se cambio nada.', v_n;
  end if;

  if not exists (
    select 1 from public.services s
    where s.id = v_asesoria and s.tenant_id = v_tenant and s.active
  ) then
    raise exception 'No encontre "Corte personalizado y asesoria". No se cambio nada.';
  end if;

  -- Los pares estilista-servicio: todos con todos, y la asesoría solo David.
  create temp table pares on commit drop as
  select st.id as stylist_id, s.id as service_id
  from public.stylists st
  cross join public.services s
  where st.tenant_id = v_tenant
    and st.id = any(v_estilistas)
    and s.tenant_id = v_tenant
    and s.active
    and (s.id <> v_asesoria or st.id = v_david);

  -- El catálogo: el INSERT de set_stylist_services.
  insert into public.stylist_services (tenant_id, stylist_id, service_id, active)
  select v_tenant, p.stylist_id, p.service_id, true
  from pares p
  on conflict on constraint stylist_services_stylist_id_service_id_key
  do update set active = excluded.active;

  -- La sede: el INSERT de set_stylist_services (lo que ve la reserva).
  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  )
  select v_tenant, bst.branch_id, bst.id, bs.id, true
  from pares p
  join public.branch_stylists bst
    on bst.tenant_id = v_tenant
   and bst.stylist_id = p.stylist_id
   and bst.active = true
  join public.branch_services bs
    on bs.tenant_id = v_tenant
   and bs.branch_id = bst.branch_id
   and bs.service_id = p.service_id
  on conflict on constraint branch_stylist_services_pair_key
  do update set active = true, updated_at = now();

  -- Comprobar: 3 x 27 + 28 = 109, en el catálogo y en la sede.
  select count(*) into v_n
  from public.stylist_services ss
  where ss.tenant_id = v_tenant and ss.active and ss.stylist_id = any(v_estilistas);
  if v_n <> 109 then
    raise exception 'En el catalogo quedarian % asignaciones y se esperaban 109. No se cambio nada.', v_n;
  end if;

  select count(*) into v_n
  from public.branch_stylist_services bss
  join public.branch_stylists bst on bst.id = bss.branch_stylist_id
  where bss.tenant_id = v_tenant and bss.active and bst.stylist_id = any(v_estilistas);
  if v_n <> 109 then
    raise exception 'En la sede quedarian % asignaciones y se esperaban 109. No se cambio nada.', v_n;
  end if;

  raise notice 'OK: 109 asignaciones (27 servicios a Antonio, Diana y Mauricio; 28 a David)';
end
$asignar$;

commit;

\echo ''
\echo 'SERVICIOS DE CADA ESTILISTA:'
select st.name as estilista, count(*) as servicios
from public.stylist_services ss
join public.stylists st on st.id = ss.stylist_id
join public.tenants t on t.id = ss.tenant_id
where t.slug = 'inspirant-salon' and ss.active
group by st.name
order by st.name;

\echo 'SERVICIOS QUE SE PUEDEN RESERVAR EN LINEA:'
select count(distinct x.service_id) as servicios_reservables
from public.public_get_bookable_services(
  (select b.id from public.branches b
   join public.tenants t on t.id = b.tenant_id
   where t.slug = 'inspirant-salon' and b.is_primary)
) x;
