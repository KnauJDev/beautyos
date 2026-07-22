-- BeautyOS - Registro self-serve de un negocio nuevo.
--
-- Antes de esta migracion, un tenant nuevo solo podia crearse a mano por
-- SQL (supabase/sql/034, 042). Esta migracion agrega la RPC que un usuario
-- recien autenticado (justo despues de auth.signUp) puede llamar una sola
-- vez para crear su propio negocio con una sede inicial y quedar en el
-- plan Profesional en periodo de prueba (decision del propietario:
-- 21 dias, plan Profesional por defecto).
--
-- Alcance: un usuario recien registrado que todavia no pertenece a ningun
-- negocio. No cubre invitar usuarios a un tenant existente (eso ya existe
-- via update_tenant_user_access) ni cambio de plan/pago (fuera de alcance,
-- ver SUSCRIPCION_Y_ENTITLEMENTS.md seccion 6).

begin;

create or replace function public.register_tenant(
  p_business_name text,
  p_owner_full_name text,
  p_whatsapp text,
  p_business_type text default null
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  trial_ends_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_tenant_id uuid;
  v_branch_id uuid;
  v_tenant_membership_id uuid;
  v_plan_id uuid;
  v_subscription_id uuid;
  v_trial_ends_at timestamptz := now() + interval '21 days';
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada para registrar un negocio.';
  end if;

  if exists (
    select 1 from public.tenant_memberships where user_id = v_user_id
  ) then
    raise exception 'Este usuario ya pertenece a un negocio.';
  end if;

  if length(trim(coalesce(p_business_name, ''))) = 0 then
    raise exception 'El nombre del negocio es obligatorio.';
  end if;

  if length(trim(coalesce(p_owner_full_name, ''))) = 0 then
    raise exception 'Tu nombre completo es obligatorio.';
  end if;

  if length(trim(coalesce(p_whatsapp, ''))) = 0 then
    raise exception 'El WhatsApp de contacto es obligatorio.';
  end if;

  select email into v_email from auth.users where id = v_user_id;
  if v_email is null then
    raise exception 'No se encontro un correo asociado a esta sesion.';
  end if;

  select id into v_plan_id
  from public.plans
  where code = 'profesional' and status = 'active';

  if v_plan_id is null then
    raise exception 'No hay un plan disponible para iniciar la prueba gratis.';
  end if;

  insert into public.tenants (name, business_type, contact_email, whatsapp)
  values (
    trim(p_business_name),
    nullif(trim(coalesce(p_business_type, '')), ''),
    v_email,
    trim(p_whatsapp)
  )
  returning id into v_tenant_id;

  insert into public.branches (tenant_id, name, slug, is_primary)
  values (v_tenant_id, trim(p_business_name), 'principal', true)
  returning id into v_branch_id;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_id, v_user_id, trim(p_owner_full_name), 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_user_id, 'tenant_owner', true, now())
  returning id into v_tenant_membership_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (
    v_tenant_id, v_branch_id, v_tenant_membership_id, true, now(), v_user_id
  );

  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, trial_ends_at, current_period_start
  ) values (
    v_tenant_id, v_plan_id, 'trialing', v_trial_ends_at, now()
  )
  returning id into v_subscription_id;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    v_tenant_id,
    v_subscription_id,
    'trial_started',
    jsonb_build_object('plan', 'profesional', 'trial_ends_at', v_trial_ends_at),
    v_user_id
  );

  return query select v_tenant_id, v_branch_id, v_trial_ends_at;
end;
$$;

revoke all on function public.register_tenant(text, text, text, text)
  from public, anon;
grant execute on function public.register_tenant(text, text, text, text)
  to authenticated, service_role;

commit;
