-- ============================================================
-- BeautyOS - Paso 654
-- Tabla y funcion segura para fotos de trabajos
-- Archivo: supabase/sql/028_create_work_photos.sql
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer fotos, clientes y estilistas de otros negocios.
-- ============================================================

create table if not exists public.work_photos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  ticket_id uuid references public.tickets(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  stylist_id uuid references public.stylists(id) on delete set null,
  photo_url text not null,
  photo_type text not null default 'final',
  caption text,
  ai_status text not null default 'not_required',
  visible_to_customer boolean not null default false,
  approved_for_portfolio boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint work_photos_photo_type_check
    check (photo_type in ('before', 'after', 'final', 'portfolio')),

  constraint work_photos_ai_status_check
    check (ai_status in ('not_required', 'pending', 'processed', 'failed'))
);

alter table public.work_photos enable row level security;

create index if not exists work_photos_tenant_id_idx
on public.work_photos (tenant_id);

create index if not exists work_photos_ticket_id_idx
on public.work_photos (ticket_id);

create index if not exists work_photos_stylist_id_idx
on public.work_photos (stylist_id);

create or replace function public.get_work_photos_summary()
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  photo_url text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver fotos de trabajos.';
  end if;

  return query
  select
    wp.id,
    wp.ticket_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
    wp.photo_url,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  left join public.clients c
    on c.id = wp.client_id
   and c.tenant_id = current_tenant_id
  left join public.stylists st
    on st.id = wp.stylist_id
   and st.tenant_id = current_tenant_id
  where wp.tenant_id = current_tenant_id
    and wp.active = true
  order by wp.created_at desc;
end;
$$;

revoke execute on function public.get_work_photos_summary() from anon;
revoke execute on function public.get_work_photos_summary() from public;

grant execute on function public.get_work_photos_summary() to authenticated;
