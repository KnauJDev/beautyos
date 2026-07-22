-- BeautyOS - Tramo D3.5.3
-- Prueba de contrato para la migracion 20260722175530.
--
-- Aviso importante de alcance: este repositorio no contiene una migracion
-- basal para tenants/user_profiles/clients/user_profile_access_history
-- (nacieron antes de versionar migraciones; ver Tramo 0, seccion 6.1).
-- Por eso "supabase db reset" no puede reconstruir el esquema completo en
-- un Postgres local vacio. Este script crea una copia minima y fiel de las
-- columnas que los seis objetos tocados realmente usan (documentadas en
-- supabase/sql/033, 035-037, 056, 085 y en la migracion Tramo A) para poder
-- ejecutar de verdad la nueva logica contra Postgres real, con auth.uid()
-- real de GoTrue. No sustituye una prueba contra el esquema vivo completo.
--
-- Ejecutar una sola vez contra una base local desechable.

begin;

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Tenant sintetico'
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

commit;
