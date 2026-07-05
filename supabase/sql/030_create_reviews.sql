-- ============================================================
-- BeautyOS - Paso 679
-- Tabla y funcion segura para reseñas
-- Archivo: supabase/sql/030_create_reviews.sql
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
language sql
security definer
set search_path = public
as $$
  select
    reviews.id,
    reviews.ticket_id,
    coalesce(clients.name, 'Cliente no asociado') as client_name,
    coalesce(stylists.name, 'Estilista no asociado') as stylist_name,
    coalesce(services.name, 'Servicio no asociado') as service_name,
    reviews.rating,
    reviews.comment,
    reviews.moderation_status,
    reviews.visible_to_public,
    reviews.created_at
  from public.reviews
  left join public.clients
    on clients.id = reviews.client_id
  left join public.stylists
    on stylists.id = reviews.stylist_id
  left join public.services
    on services.id = reviews.service_id
  where reviews.active = true
  order by reviews.created_at desc;
$$;

grant execute on function public.get_reviews_summary() to anon, authenticated;
