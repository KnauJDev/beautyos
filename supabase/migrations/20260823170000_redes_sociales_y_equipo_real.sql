-- ============================================================================
-- MIGRACIÓN: 20260823170000_redes_sociales_y_equipo_real.sql
-- DESCRIPCIÓN: El salón puede editar sus redes sociales desde Configuración
--              (autoservicio), y el Panel de Plataforma muestra la capacidad
--              operativa REAL en vivo (sedes activas y equipo activo con
--              desglose por rol) en vez del formulario estático de registro
--              (bloque de refinamiento arquitectónico 2026-08-23, D-162).
-- ============================================================================

begin;

-- 1. Extender `public.update_tenant_contact_info` con Instagram y Facebook.
-- DROP requerido: cambia la firma (de 4 a 6 parámetros), create or replace
-- no reemplaza una función con distinta cantidad de argumentos, crearía un
-- segundo overload huérfano.
drop function if exists public.update_tenant_contact_info(text, text, text, text);

create or replace function public.update_tenant_contact_info(
  p_full_name text,
  p_business_type text,
  p_contact_phone text,
  p_whatsapp text,
  p_instagram text,
  p_facebook text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.get_my_tenant_id();
  v_full_name text := nullif(trim(coalesce(p_full_name, '')), '');
begin
  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede editar los datos del negocio.';
  end if;

  update public.tenants
  set
    business_type = nullif(trim(coalesce(p_business_type, '')), ''),
    contact_phone = nullif(trim(coalesce(p_contact_phone, '')), ''),
    whatsapp = nullif(trim(coalesce(p_whatsapp, '')), ''),
    instagram = nullif(trim(coalesce(p_instagram, '')), ''),
    facebook = nullif(trim(coalesce(p_facebook, '')), '')
  where id = v_tenant_id
    and active = true;

  if not found then
    raise exception 'No se encontró el negocio activo del usuario actual.';
  end if;

  if v_full_name is not null then
    update public.user_profiles
    set full_name = v_full_name
    where tenant_id = v_tenant_id
      and role = 'owner';
  end if;
end;
$$;

revoke execute on function public.update_tenant_contact_info(text, text, text, text, text, text) from anon;
revoke execute on function public.update_tenant_contact_info(text, text, text, text, text, text) from public;
grant execute on function public.update_tenant_contact_info(text, text, text, text, text, text) to authenticated;

comment on function public.update_tenant_contact_info(text, text, text, text, text, text)
  is 'Autoservicio: el owner o admin del propio negocio actualiza nombre del titular, tipo de negocio, teléfono, WhatsApp, Instagram y Facebook.';

-- 2. Extender `public.platform_list_tenants` con teléfono/redes (solo
-- lectura para la plataforma; se editan desde la Configuración del propio
-- salón, punto 1 de este bloque) y con la capacidad operativa REAL en vivo:
-- sedes activas desde `branches`, equipo activo con desglose por rol desde
-- `user_profiles` (misma fuente que `get_tenant_users()`, no `tenant_memberships`,
-- que es la tabla de autorización por sede, no el directorio de personas).
-- DROP requerido: cambian las columnas de RETURNS TABLE.
drop function if exists public.platform_list_tenants();

create or replace function public.platform_list_tenants()
returns table (
  tenant_id uuid,
  tenant_name text,
  contact_name text,
  business_type text,
  city text,
  estimated_branches integer,
  estimated_team_size integer,
  referral_source text,
  rejection_reason text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text,
  real_branches_count integer,
  real_team_count integer,
  team_breakdown text,
  tenant_active boolean,
  is_demo boolean,
  plan_code text,
  subscription_status text,
  is_founder boolean,
  price_cop bigint,
  discount_percent numeric,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    t.id,
    t.name,
    up_owner.full_name,
    t.business_type,
    t.city,
    t.estimated_branches,
    t.estimated_team_size,
    t.referral_source,
    t.rejection_reason,
    t.contact_email,
    t.contact_phone,
    t.whatsapp,
    t.instagram,
    t.facebook,
    coalesce(branches_count.cnt, 0),
    coalesce(team.real_team_count, 0),
    coalesce(team.team_breakdown, 'Sin colaboradores activos'),
    t.active,
    t.is_demo,
    p.code,
    ts.status,
    ts.is_founder,
    ts.price_cop,
    ts.discount_percent,
    ts.trial_ends_at,
    ts.current_period_end,
    ts.grace_ends_at,
    t.created_at
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  left join public.user_profiles up_owner
    on up_owner.tenant_id = t.id
   and up_owner.role = 'owner'
   and up_owner.active = true
  left join lateral (
    select count(*)::integer as cnt
    from public.branches b
    where b.tenant_id = t.id
      and b.active = true
  ) branches_count on true
  left join lateral (
    select
      sum(cnt)::integer as real_team_count,
      string_agg(cnt || ' ' || label, ', ' order by ord) as team_breakdown
    from (
      select
        case up2.role
          when 'owner' then 1
          when 'admin' then 2
          when 'assistant' then 3
          when 'stylist' then 4
        end as ord,
        count(*) as cnt,
        case up2.role
          when 'owner' then (case when count(*) = 1 then 'dueño' else 'dueños' end)
          when 'admin' then (case when count(*) = 1 then 'admin' else 'admins' end)
          when 'assistant' then (case when count(*) = 1 then 'asistente' else 'asistentes' end)
          when 'stylist' then (case when count(*) = 1 then 'estilista' else 'estilistas' end)
        end as label
      from public.user_profiles up2
      where up2.tenant_id = t.id
        and up2.active = true
        and up2.role in ('owner', 'admin', 'assistant', 'stylist')
      group by up2.role
    ) roles
  ) team on true
  order by
    case when ts.status = 'pending' then 0 else 1 end,
    t.is_demo,
    t.created_at desc;
end;
$$;

revoke all on function public.platform_list_tenants() from public, anon, authenticated;
grant execute on function public.platform_list_tenants() to authenticated;

commit;
