-- ==============================================================================
-- Migración: Galería de fotos con consecutivo de ticket (#0000701) e IDs para filtros (Paso 4.9 / D-156)
-- ==============================================================================
-- Actualiza public.get_work_photos_summary_v2 para incluir:
--   - ticket_number (consecutive_number)
--   - ticket_code ('#' || lpad(consecutive_number, 7, '0'))
--   - client_id
--   - stylist_id
-- Permitiendo filtrar la galería por cliente y estilista, y mostrando el chip
-- del ticket en cada tarjeta de trabajo.
-- ==============================================================================

begin;

drop function if exists public.get_work_photos_summary_v2(uuid);

create or replace function public.get_work_photos_summary_v2(p_branch_id uuid)
returns table (
  id uuid,
  ticket_id uuid,
  ticket_number bigint,
  ticket_code text,
  client_id uuid,
  client_name text,
  stylist_id uuid,
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
    array['tenant_owner', 'admin', 'assistant']::text[],
    true
  );

  return query
  select
    wp.id,
    wp.ticket_id,
    tk.consecutive_number as ticket_number,
    case
      when tk.consecutive_number is not null then '#' || lpad(tk.consecutive_number::text, 7, '0')
      else null
    end as ticket_code,
    wp.client_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    wp.stylist_id,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
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
  left join public.tickets tk
    on tk.tenant_id = wp.tenant_id
   and tk.id = wp.ticket_id
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
  is 'Galería de fotos de trabajo con consecutivo de ticket (#0000701) e IDs de cliente/estilista para filtrado (D-156).';

commit;
