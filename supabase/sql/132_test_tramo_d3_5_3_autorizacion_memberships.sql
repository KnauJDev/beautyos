-- BeautyOS - Esquema sintetico reutilizable para pruebas locales.
--
-- Aviso importante de alcance: este repositorio no contiene una migracion
-- basal para tenants/branches/user_profiles/clients/
-- user_profile_access_history (nacieron antes de versionar migraciones; ver
-- Tramo 0, seccion 6.1). Por eso "supabase db reset" no puede reconstruir el
-- esquema completo en un Postgres local vacio. Este script crea una copia
-- minima y fiel de esas tablas (contrastada 2026-07-22 contra un dump real
-- de solo lectura del unico proyecto Supabase, no solo contra fragmentos de
-- RPC) para poder ejecutar de verdad la logica nueva contra Postgres real,
-- con auth.uid() real de GoTrue. No sustituye una prueba contra el esquema
-- vivo completo.
--
-- Usado por las pruebas de: Tramo D3.5.3, fundacion de suscripciones/
-- entitlements, registro self-serve de tenant. Ejecutar una sola vez contra
-- una base local desechable.

begin;

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  business_type text,
  contact_email text not null,
  contact_phone text,
  whatsapp text not null,
  instagram text,
  facebook text,
  active boolean not null default true
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null,
  slug text not null,
  timezone text not null default 'America/Bogota',
  currency_code text not null default 'COP',
  is_primary boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branches_tenant_id_slug_key unique (tenant_id, slug)
);

create table public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id),
  user_id uuid not null,
  full_name text,
  role text,
  active boolean not null default true,
  stylist_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id),
  name text,
  phone text,
  email text,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.stylists (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id),
  name text,
  active boolean not null default true
);

create table public.user_profile_access_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  profile_id uuid not null,
  target_user_id uuid not null,
  previous_role text not null,
  new_role text not null,
  previous_active boolean not null,
  new_active boolean not null,
  changed_by uuid not null,
  created_at timestamptz not null default now()
);

create table public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  user_id uuid not null references auth.users(id),
  stylist_id uuid,
  role text not null check (role in ('tenant_owner', 'admin', 'assistant', 'stylist')),
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, user_id),
  check (ends_at is null or ends_at > starts_at)
);

create table public.branch_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  branch_id uuid not null,
  tenant_membership_id uuid not null,
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branch_memberships_validity_check check (ends_at is null or ends_at > starts_at)
);

create table public.business_hours (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  day_of_week integer not null check (day_of_week between 1 and 7),
  opens_at time,
  closes_at time,
  is_open boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.appointment_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  requires_deposit boolean not null default false,
  deposit_percentage numeric not null default 0,
  cancellation_hours integer not null default 24,
  reschedule_hours integer not null default 24,
  manual_confirmation_required boolean not null default true,
  customer_reschedule_allowed boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.commission_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  commission_type text not null default 'percentage',
  commission_percentage numeric not null default 40,
  fixed_commission_amount numeric not null default 0,
  applies_after_discount boolean not null default true,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

commit;
