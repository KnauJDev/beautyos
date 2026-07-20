-- BeautyOS - Tramo A: estructura aditiva multi-tenant y multisede.
--
-- Esta migracion no modifica firmas RPC ni columnas usadas por Flutter.
-- Crea la nueva estructura, genera la Sede principal de cada tenant y
-- replica las relaciones actuales sin retirar ni recalcular datos historicos.

begin;

-- Las relaciones nuevas incluyen tenant_id en sus claves foraneas para que
-- PostgreSQL impida cruces entre negocios, incluso ante IDs manipulados.
create unique index if not exists services_tenant_id_id_uidx
  on public.services (tenant_id, id);

create unique index if not exists stylists_tenant_id_id_uidx
  on public.stylists (tenant_id, id);

create unique index if not exists products_tenant_id_id_uidx
  on public.products (tenant_id, id);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on update cascade on delete restrict,
  name text not null,
  slug text not null,
  timezone text not null default 'America/Bogota',
  currency_code text not null default 'COP',
  contact_email text,
  contact_phone text,
  whatsapp text,
  address text,
  city text,
  department text,
  country_code text not null default 'CO',
  latitude numeric(9,6),
  longitude numeric(9,6),
  booking_mode text not null default 'manual_confirmation',
  is_primary boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branches_tenant_id_id_key unique (tenant_id, id),
  constraint branches_tenant_id_slug_key unique (tenant_id, slug),
  constraint branches_name_not_blank check (btrim(name) <> ''),
  constraint branches_slug_format_check
    check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint branches_timezone_not_blank check (btrim(timezone) <> ''),
  constraint branches_currency_code_check check (currency_code ~ '^[A-Z]{3}$'),
  constraint branches_country_code_check check (country_code ~ '^[A-Z]{2}$'),
  constraint branches_latitude_check check (latitude is null or latitude between -90 and 90),
  constraint branches_longitude_check check (longitude is null or longitude between -180 and 180),
  constraint branches_booking_mode_check
    check (booking_mode in ('manual_confirmation', 'automatic'))
);

create unique index branches_one_primary_per_tenant_uidx
  on public.branches (tenant_id)
  where is_primary;

create index branches_tenant_active_idx
  on public.branches (tenant_id, active);

create table public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on update cascade on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  stylist_id uuid,
  role text not null,
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_memberships_tenant_id_id_key unique (tenant_id, id),
  constraint tenant_memberships_tenant_id_user_id_key unique (tenant_id, user_id),
  constraint tenant_memberships_tenant_stylist_fkey
    foreign key (tenant_id, stylist_id)
    references public.stylists(tenant_id, id)
    on update cascade on delete restrict,
  constraint tenant_memberships_role_check
    check (role in ('tenant_owner', 'admin', 'assistant', 'stylist')),
  constraint tenant_memberships_stylist_role_check
    check ((role = 'stylist' and stylist_id is not null) or role <> 'stylist'),
  constraint tenant_memberships_validity_check
    check (ends_at is null or ends_at > starts_at)
);

create index tenant_memberships_user_active_idx
  on public.tenant_memberships (user_id, active);

create index tenant_memberships_tenant_active_role_idx
  on public.tenant_memberships (tenant_id, active, role);

create index tenant_memberships_stylist_id_idx
  on public.tenant_memberships (stylist_id)
  where stylist_id is not null;

create table public.branch_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  branch_id uuid not null,
  tenant_membership_id uuid not null,
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branch_memberships_branch_membership_key
    unique (branch_id, tenant_membership_id),
  constraint branch_memberships_tenant_branch_fkey
    foreign key (tenant_id, branch_id)
    references public.branches(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_memberships_tenant_membership_fkey
    foreign key (tenant_id, tenant_membership_id)
    references public.tenant_memberships(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_memberships_validity_check
    check (ends_at is null or ends_at > starts_at)
);

create index branch_memberships_membership_active_idx
  on public.branch_memberships (tenant_membership_id, active);

create index branch_memberships_branch_active_idx
  on public.branch_memberships (branch_id, active);

create table public.branch_services (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  branch_id uuid not null,
  service_id uuid not null,
  price numeric(12,2) not null,
  duration_minutes integer not null,
  booking_interval_minutes integer not null default 15,
  visible_to_customer boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branch_services_tenant_branch_id_key unique (tenant_id, branch_id, id),
  constraint branch_services_branch_service_key unique (branch_id, service_id),
  constraint branch_services_tenant_branch_fkey
    foreign key (tenant_id, branch_id)
    references public.branches(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_services_tenant_service_fkey
    foreign key (tenant_id, service_id)
    references public.services(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_services_price_check check (price >= 0),
  constraint branch_services_duration_check check (duration_minutes > 0),
  constraint branch_services_interval_check check (booking_interval_minutes > 0)
);

create index branch_services_service_id_idx
  on public.branch_services (service_id);

create index branch_services_public_active_idx
  on public.branch_services (branch_id, active, visible_to_customer);

create table public.branch_stylists (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  branch_id uuid not null,
  stylist_id uuid not null,
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branch_stylists_tenant_branch_id_key unique (tenant_id, branch_id, id),
  constraint branch_stylists_branch_stylist_key unique (branch_id, stylist_id),
  constraint branch_stylists_tenant_branch_fkey
    foreign key (tenant_id, branch_id)
    references public.branches(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_stylists_tenant_stylist_fkey
    foreign key (tenant_id, stylist_id)
    references public.stylists(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_stylists_validity_check
    check (ends_at is null or ends_at > starts_at)
);

create index branch_stylists_stylist_active_idx
  on public.branch_stylists (stylist_id, active);

create index branch_stylists_branch_active_idx
  on public.branch_stylists (branch_id, active);

create table public.branch_stylist_services (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  branch_id uuid not null,
  branch_stylist_id uuid not null,
  branch_service_id uuid not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branch_stylist_services_pair_key
    unique (branch_stylist_id, branch_service_id),
  constraint branch_stylist_services_stylist_fkey
    foreign key (tenant_id, branch_id, branch_stylist_id)
    references public.branch_stylists(tenant_id, branch_id, id)
    on update cascade on delete restrict,
  constraint branch_stylist_services_service_fkey
    foreign key (tenant_id, branch_id, branch_service_id)
    references public.branch_services(tenant_id, branch_id, id)
    on update cascade on delete restrict
);

create index branch_stylist_services_branch_active_idx
  on public.branch_stylist_services (branch_id, active);

create index branch_stylist_services_service_id_idx
  on public.branch_stylist_services (branch_service_id);

create table public.branch_products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  branch_id uuid not null,
  product_id uuid not null,
  current_stock numeric not null default 0,
  minimum_stock numeric not null default 0,
  average_cost numeric(12,2) not null default 0,
  sale_price numeric(12,2) not null default 0,
  visible_for_sale boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branch_products_branch_product_key unique (branch_id, product_id),
  constraint branch_products_tenant_branch_fkey
    foreign key (tenant_id, branch_id)
    references public.branches(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_products_tenant_product_fkey
    foreign key (tenant_id, product_id)
    references public.products(tenant_id, id)
    on update cascade on delete restrict,
  constraint branch_products_stock_check check (current_stock >= 0),
  constraint branch_products_minimum_stock_check check (minimum_stock >= 0),
  constraint branch_products_average_cost_check check (average_cost >= 0),
  constraint branch_products_sale_price_check check (sale_price >= 0)
);

create index branch_products_product_id_idx
  on public.branch_products (product_id);

create index branch_products_branch_active_idx
  on public.branch_products (branch_id, active);

-- updated_at uniforme para las entidades nuevas. El esquema private no se
-- expone en la Data API y no concede ejecucion directa a clientes.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create function private.beautyos_set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.beautyos_set_updated_at() from public, anon, authenticated;

create trigger branches_set_updated_at
before update on public.branches
for each row execute function private.beautyos_set_updated_at();

create trigger tenant_memberships_set_updated_at
before update on public.tenant_memberships
for each row execute function private.beautyos_set_updated_at();

create trigger branch_memberships_set_updated_at
before update on public.branch_memberships
for each row execute function private.beautyos_set_updated_at();

create trigger branch_services_set_updated_at
before update on public.branch_services
for each row execute function private.beautyos_set_updated_at();

create trigger branch_stylists_set_updated_at
before update on public.branch_stylists
for each row execute function private.beautyos_set_updated_at();

create trigger branch_stylist_services_set_updated_at
before update on public.branch_stylist_services
for each row execute function private.beautyos_set_updated_at();

create trigger branch_products_set_updated_at
before update on public.branch_products
for each row execute function private.beautyos_set_updated_at();

-- En el Tramo A las tablas quedan cerradas a clientes por defecto. Las
-- politicas de membresia se habilitaran junto con las RPC p_branch_id en el
-- Tramo C, evitando abrir una ruta parcial o dependiente del rol antiguo.
alter table public.branches enable row level security;
alter table public.tenant_memberships enable row level security;
alter table public.branch_memberships enable row level security;
alter table public.branch_services enable row level security;
alter table public.branch_stylists enable row level security;
alter table public.branch_stylist_services enable row level security;
alter table public.branch_products enable row level security;

revoke all on table public.branches from public, anon, authenticated;
revoke all on table public.tenant_memberships from public, anon, authenticated;
revoke all on table public.branch_memberships from public, anon, authenticated;
revoke all on table public.branch_services from public, anon, authenticated;
revoke all on table public.branch_stylists from public, anon, authenticated;
revoke all on table public.branch_stylist_services from public, anon, authenticated;
revoke all on table public.branch_products from public, anon, authenticated;

grant all on table public.branches to service_role;
grant all on table public.tenant_memberships to service_role;
grant all on table public.branch_memberships to service_role;
grant all on table public.branch_services to service_role;
grant all on table public.branch_stylists to service_role;
grant all on table public.branch_stylist_services to service_role;
grant all on table public.branch_products to service_role;

-- Backfill aditivo: una Sede principal por tenant y copia exacta de la
-- configuracion vigente. Las tablas originales siguen siendo la fuente usada
-- por Flutter durante la ventana de compatibilidad.
insert into public.branches (
  tenant_id,
  name,
  slug,
  timezone,
  currency_code,
  contact_email,
  contact_phone,
  whatsapp,
  country_code,
  booking_mode,
  is_primary,
  active,
  created_at,
  updated_at
)
select
  t.id,
  'Sede principal',
  'sede-principal',
  'America/Bogota',
  'COP',
  t.contact_email,
  t.contact_phone,
  t.whatsapp,
  'CO',
  'manual_confirmation',
  true,
  t.active,
  t.created_at,
  now()
from public.tenants t
on conflict (tenant_id, slug) do nothing;

insert into public.tenant_memberships (
  tenant_id,
  user_id,
  stylist_id,
  role,
  active,
  starts_at,
  created_at,
  updated_at
)
select
  up.tenant_id,
  up.user_id,
  up.stylist_id,
  case up.role
    when 'owner' then 'tenant_owner'
    else up.role
  end,
  up.active,
  up.created_at,
  up.created_at,
  up.updated_at
from public.user_profiles up
where up.tenant_id is not null
  and up.role in ('owner', 'admin', 'assistant', 'stylist')
on conflict (tenant_id, user_id) do nothing;

insert into public.branch_memberships (
  tenant_id,
  branch_id,
  tenant_membership_id,
  active,
  starts_at,
  created_at,
  updated_at
)
select
  tm.tenant_id,
  b.id,
  tm.id,
  tm.active and b.active,
  tm.starts_at,
  greatest(tm.created_at, b.created_at),
  now()
from public.tenant_memberships tm
join public.branches b
  on b.tenant_id = tm.tenant_id
 and b.is_primary
on conflict (branch_id, tenant_membership_id) do nothing;

insert into public.branch_services (
  tenant_id,
  branch_id,
  service_id,
  price,
  duration_minutes,
  booking_interval_minutes,
  visible_to_customer,
  active,
  created_at,
  updated_at
)
select
  s.tenant_id,
  b.id,
  s.id,
  s.price,
  s.duration_minutes,
  15,
  s.visible_to_customer,
  s.active and b.active,
  s.created_at,
  now()
from public.services s
join public.branches b
  on b.tenant_id = s.tenant_id
 and b.is_primary
on conflict (branch_id, service_id) do nothing;

insert into public.branch_stylists (
  tenant_id,
  branch_id,
  stylist_id,
  active,
  starts_at,
  created_at,
  updated_at
)
select
  st.tenant_id,
  b.id,
  st.id,
  st.active and b.active,
  st.created_at,
  st.created_at,
  now()
from public.stylists st
join public.branches b
  on b.tenant_id = st.tenant_id
 and b.is_primary
on conflict (branch_id, stylist_id) do nothing;

insert into public.branch_stylist_services (
  tenant_id,
  branch_id,
  branch_stylist_id,
  branch_service_id,
  active,
  created_at,
  updated_at
)
select
  ss.tenant_id,
  bst.branch_id,
  bst.id,
  bsv.id,
  ss.active and bst.active and bsv.active,
  ss.created_at,
  now()
from public.stylist_services ss
join public.branch_stylists bst
  on bst.tenant_id = ss.tenant_id
 and bst.stylist_id = ss.stylist_id
join public.branch_services bsv
  on bsv.tenant_id = ss.tenant_id
 and bsv.branch_id = bst.branch_id
 and bsv.service_id = ss.service_id
on conflict (branch_stylist_id, branch_service_id) do nothing;

insert into public.branch_products (
  tenant_id,
  branch_id,
  product_id,
  current_stock,
  minimum_stock,
  average_cost,
  sale_price,
  visible_for_sale,
  active,
  created_at,
  updated_at
)
select
  p.tenant_id,
  b.id,
  p.id,
  p.current_stock,
  p.minimum_stock,
  p.purchase_price,
  p.sale_price,
  p.visible_for_sale,
  p.active and b.active,
  p.created_at,
  p.updated_at
from public.products p
join public.branches b
  on b.tenant_id = p.tenant_id
 and b.is_primary
on conflict (branch_id, product_id) do nothing;

commit;
