-- Salon y Mas - Restaura dos textos de respaldo que se perdieron al reescribir
-- la galeria de fotos en D-119.
--
-- QUE SE PERDIO
--
-- La version original de `get_work_photos_summary_v2` devolvia:
--
--     coalesce(c.name, 'Cliente no asociado')
--     coalesce(st.name, 'Estilista no asociado')
--
-- Al reescribirla para agregar el almacen y la ruta, se copiaron las columnas
-- pero **no los coalesce**. Una foto sin cliente o sin estilista pasaba a
-- devolver vacio.
--
-- POR QUE ESO NO ES COSMETICO
--
-- `WorkPhotoSummary.fromMap` lee esos dos campos como texto **obligatorio**.
-- Un vacio ahi no deja un hueco en la tarjeta: **rompe la lectura de toda la
-- lista**, asi que una sola foto sin estilista dejaria la galeria entera sin
-- cargar. La version original nunca podia caer en eso.
--
-- Se corrige en los dos lados a proposito -- aqui y en el modelo de Flutter,
-- que pasa a tolerar el vacio -- porque depender de que el servidor nunca
-- mande nulo es exactamente la suposicion que causo esto.
--
-- Tercer fallo de la misma familia en la sesion del 09-ago, despues del de
-- D-119 (verificacion de plan, tickets cancelados y tipo de foto) y del de
-- D-122 (permiso de ejecucion). **Al reescribir una funcion, comparar linea
-- por linea contra la original, no solo la firma.**

begin;

drop function if exists public.get_work_photos_summary_v2(uuid);

create or replace function public.get_work_photos_summary_v2(p_branch_id uuid)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  photo_url text,
  storage_bucket text,
  storage_path text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  return query
  select
    wp.id,
    wp.ticket_id,
    coalesce(c.name, 'Cliente no asociado'),
    coalesce(st.name, 'Estilista no asociado'),
    wp.photo_url,
    wp.storage_bucket,
    wp.storage_path,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join public.stylists st
    on st.tenant_id = wp.tenant_id
   and st.id = wp.stylist_id
  where wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active
  order by wp.created_at desc, wp.id;
end;
$$;

revoke all on function public.get_work_photos_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_work_photos_summary_v2(uuid)
  to authenticated;

comment on function public.get_work_photos_summary_v2(uuid)
  is 'Galeria de fotos de trabajo de la sede, con el almacen donde vive cada archivo (H-09). Owner y admin.';

commit;
