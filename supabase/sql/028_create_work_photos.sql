-- ============================================================
-- BeautyOS - Paso 654
-- Tabla y funcion segura para fotos de trabajos
-- Archivo: supabase/sql/028_create_work_photos.sql
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
language sql
security definer
set search_path = public
as $$
  select
    work_photos.id,
    work_photos.ticket_id,
    coalesce(clients.name, 'Cliente no asociado') as client_name,
    coalesce(stylists.name, 'Estilista no asociado') as stylist_name,
    work_photos.photo_url,
    work_photos.photo_type,
    work_photos.caption,
    work_photos.ai_status,
    work_photos.visible_to_customer,
    work_photos.approved_for_portfolio,
    work_photos.created_at
  from public.work_photos
  left join public.clients
    on clients.id = work_photos.client_id
  left join public.stylists
    on stylists.id = work_photos.stylist_id
  where work_photos.active = true
  order by work_photos.created_at desc;
$$;

grant execute on function public.get_work_photos_summary() to anon, authenticated;
