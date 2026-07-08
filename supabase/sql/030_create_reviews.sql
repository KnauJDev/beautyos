-- ============================================================
-- BeautyOS - Paso 679
-- Tabla y funcion segura para reseñas
-- Archivo: supabase/sql/030_create_reviews.sql
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer reseñas, clientes, estilistas y servicios de otros negocios.
-- ============================================================

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  ticket_id uuid references public.tickets(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  stylist_id uuid references public.stylists(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  rating integer not null,
  comment text,
  moderation_status text not null default 'pending',
  visible_to_public boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint reviews_rating_check
    check (rating between 1 and 5),

  constraint reviews_moderation_status_check
    check (moderation_status in ('pending', 'approved', 'rejected'))
);

alter table public.reviews enable row level security;

create index if not exists reviews_tenant_id_idx
on public.reviews (tenant_id);

create index if not exists reviews_ticket_id_idx
on public.reviews (ticket_id);

create index if not exists reviews_client_id_idx
on public.reviews (client_id);

create index if not exists reviews_stylist_id_idx
on public.reviews (stylist_id);

create or replace function public.get_reviews_summary()
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  service_name text,
  rating integer,
  comment text,
  moderation_status text,
  visible_to_public boolean,
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
    raise exception 'No autorizado. Solo owner o admin puede ver reseñas.';
  end if;

  return query
  select
    r.id,
    r.ticket_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
    coalesce(s.name, 'Servicio no asociado') as service_name,
    r.rating,
    r.comment,
    r.moderation_status,
    r.visible_to_public,
    r.created_at
  from public.reviews r
  left join public.clients c
    on c.id = r.client_id
   and c.tenant_id = current_tenant_id
  left join public.stylists st
    on st.id = r.stylist_id
   and st.tenant_id = current_tenant_id
  left join public.services s
    on s.id = r.service_id
   and s.tenant_id = current_tenant_id
  where r.tenant_id = current_tenant_id
    and r.active = true
  order by r.created_at desc;
end;
$$;

revoke execute on function public.get_reviews_summary() from anon;
revoke execute on function public.get_reviews_summary() from public;

grant execute on function public.get_reviews_summary() to authenticated;
