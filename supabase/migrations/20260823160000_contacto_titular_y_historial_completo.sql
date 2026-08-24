-- ============================================================================
-- MIGRACIÓN: 20260823160000_contacto_titular_y_historial_completo.sql
-- DESCRIPCIÓN: Edición del nombre de contacto titular y datos básicos del
--              negocio (desde el Panel de Plataforma y desde la propia
--              Configuración del salón), y trazabilidad completa del
--              historial de suscripción con período comprometido y medio de
--              pago (bosquejo del propietario, bloque de mejoras 2026-08-23).
-- ============================================================================

begin;

-- 1. RPC `public.platform_update_tenant_contact`
-- Permite al dueño de la plataforma corregir el nombre de contacto del
-- titular (guardado en user_profiles.full_name, rol 'owner'), el correo, el
-- WhatsApp, el tipo de negocio y la ciudad de CUALQUIER tenant.
create or replace function public.platform_update_tenant_contact(
  p_tenant_id uuid,
  p_contact_name text,
  p_contact_email text,
  p_whatsapp text,
  p_business_type text,
  p_city text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_contact_name text := nullif(trim(coalesce(p_contact_name, '')), '');
  v_contact_email text := nullif(trim(coalesce(p_contact_email, '')), '');
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede modificar los datos de contacto.';
  end if;

  if v_contact_email is null then
    raise exception 'El correo de contacto no puede estar vacío.';
  end if;

  update public.tenants
  set
    business_type = nullif(trim(coalesce(p_business_type, '')), ''),
    city = nullif(trim(coalesce(p_city, '')), ''),
    contact_email = v_contact_email,
    whatsapp = nullif(trim(coalesce(p_whatsapp, '')), '')
  where id = p_tenant_id;

  if not found then
    raise exception 'No se encontró el negocio especificado.';
  end if;

  if v_contact_name is not null then
    update public.user_profiles
    set full_name = v_contact_name
    where tenant_id = p_tenant_id
      and role = 'owner';
  end if;

  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    provider,
    payload,
    created_by
  )
  select
    p_tenant_id,
    ts.id,
    'contact_updated',
    'platform_admin',
    jsonb_build_object(
      'contact_name', v_contact_name,
      'contact_email', v_contact_email,
      'whatsapp', p_whatsapp,
      'business_type', p_business_type,
      'city', p_city
    ),
    auth.uid()
  from public.tenant_subscriptions ts
  where ts.tenant_id = p_tenant_id;
end;
$$;

revoke all on function public.platform_update_tenant_contact(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.platform_update_tenant_contact(uuid, text, text, text, text, text) to authenticated;

comment on function public.platform_update_tenant_contact(uuid, text, text, text, text, text)
  is 'Permite al dueño de plataforma corregir el nombre del contacto titular (user_profiles.full_name) y los datos básicos de cualquier negocio.';

-- 2. RPC `public.update_tenant_contact_info`
-- Autoservicio: permite al owner o admin del PROPIO negocio (sin p_tenant_id,
-- se resuelve con get_my_tenant_id()) mantener actualizados el nombre del
-- titular, el tipo de negocio, el teléfono y el WhatsApp. Mismo criterio de
-- autorización que get_business_settings (is_owner_or_admin), del que este
-- RPC es la contraparte de escritura.
create or replace function public.update_tenant_contact_info(
  p_full_name text,
  p_business_type text,
  p_contact_phone text,
  p_whatsapp text
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
    whatsapp = nullif(trim(coalesce(p_whatsapp, '')), '')
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

revoke execute on function public.update_tenant_contact_info(text, text, text, text) from anon;
revoke execute on function public.update_tenant_contact_info(text, text, text, text) from public;
grant execute on function public.update_tenant_contact_info(text, text, text, text) to authenticated;

comment on function public.update_tenant_contact_info(text, text, text, text)
  is 'Autoservicio: el owner o admin del propio negocio actualiza el nombre del titular, tipo de negocio, teléfono y WhatsApp.';

-- 3. Extender `public.platform_list_tenants` con el nombre real de contacto
-- (hoy la UI del panel finge ese dato con la parte del correo antes de la @).
-- DROP requerido: create or replace no permite agregar columnas a RETURNS TABLE.
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
  whatsapp text,
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
    up.full_name,
    t.business_type,
    t.city,
    t.estimated_branches,
    t.estimated_team_size,
    t.referral_source,
    t.rejection_reason,
    t.contact_email,
    t.whatsapp,
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
  left join public.user_profiles up
    on up.tenant_id = t.id
   and up.role = 'owner'
   and up.active = true
  -- Orden:
  -- 1. Primero solicitudes pendientes de aprobación (status = 'pending')
  -- 2. Luego clientes activos (no demo)
  -- 3. Al final negocios de prueba
  order by
    case when ts.status = 'pending' then 0 else 1 end,
    t.is_demo,
    t.created_at desc;
end;
$$;

revoke all on function public.platform_list_tenants() from public, anon, authenticated;
grant execute on function public.platform_list_tenants() to authenticated;

-- 4. Extender `public.get_business_settings` con el nombre real de contacto
-- del titular, para que Configuración lo pueda mostrar/editar.
drop function if exists public.get_business_settings();

create or replace function public.get_business_settings()
returns table (
  id uuid,
  name text,
  contact_name text,
  business_type text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text,
  logo_url text,
  cover_photo_url text,
  theme_key text,
  brand_color text
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
    raise exception 'No autorizado. Solo owner o admin puede ver la configuración del negocio.';
  end if;

  return query
  select
    t.id,
    t.name,
    up.full_name,
    t.business_type,
    t.contact_email,
    t.contact_phone,
    t.whatsapp,
    t.instagram,
    t.facebook,
    t.logo_url,
    t.cover_photo_url,
    t.theme_key,
    t.brand_color
  from public.tenants t
  left join public.user_profiles up
    on up.tenant_id = t.id
   and up.role = 'owner'
   and up.active = true
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

-- 5. Reescribir `public.platform_get_tenant_subscription_history` con la
-- trazabilidad completa que pidió el propietario en su bosquejo: fecha/hora
-- exacta, nombre del plan, período comprometido (desde/hasta) y valor/medio
-- de pago/referencia para cotejo contable. D-160 ya deja periodo_inicio y
-- periodo_fin en el payload de cada pago de ePayco aceptado; tenant_approved
-- guarda trial_ends_at; trial_extended guarda new_trial_ends_at.
-- DROP requerido: cambian las columnas de RETURNS TABLE.
drop function if exists public.platform_get_tenant_subscription_history(uuid);

create or replace function public.platform_get_tenant_subscription_history(
  p_tenant_id uuid
)
returns table (
  event_id uuid,
  created_at timestamptz,
  event_type text,
  plan_code text,
  plan_name text,
  period_start timestamptz,
  period_end timestamptz,
  amount_cop bigint,
  payment_detail text,
  description text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
begin
  if v_caller_role is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    se.id as event_id,
    se.created_at,
    se.event_type,
    coalesce(se.payload->>'plan_code', p.code, 'profesional') as plan_code,
    coalesce(p.name, initcap(coalesce(se.payload->>'plan_code', 'profesional'))) as plan_name,
    case
      when se.event_type = 'tenant_approved' then se.created_at
      when se.event_type like 'epayco_%' and se.payload ? 'periodo_inicio'
        then (se.payload->>'periodo_inicio')::timestamptz
      else null
    end as period_start,
    case
      when se.event_type = 'tenant_approved' then (se.payload->>'trial_ends_at')::timestamptz
      when se.event_type like 'epayco_%' and se.payload ? 'periodo_fin'
        then (se.payload->>'periodo_fin')::timestamptz
      when se.event_type = 'trial_extended' then (se.payload->>'new_trial_ends_at')::timestamptz
      else null
    end as period_end,
    coalesce(
      (se.payload->>'monto_cop_recibido')::bigint,
      (se.payload->>'amount_cop')::bigint,
      (se.payload->>'price_cop')::bigint,
      null
    ) as amount_cop,
    case
      when se.provider = 'epayco' then
        nullif(
          trim(
            concat_ws(
              ' ',
              nullif(se.payload->>'x_franchise', ''),
              nullif(se.payload->>'x_bank_name', '')
            )
            || case
                 when se.provider_event_id is not null
                   then format(' (Ref: %s)', se.provider_event_id)
                 else ''
               end
          ),
          ''
        )
      when se.event_type = 'tenant_approved' then 'Período de prueba'
      when se.event_type = 'trial_extended' then 'Prueba ampliada'
      else null
    end as payment_detail,
    coalesce(se.payload->>'price_reason', se.payload->>'motivo', se.event_type) as description
  from public.subscription_events se
  join public.tenant_subscriptions ts on ts.id = se.tenant_subscription_id
  left join public.plans p on p.id = ts.plan_id
  where se.tenant_id = p_tenant_id
  order by se.created_at desc;
end;
$$;

revoke all on function public.platform_get_tenant_subscription_history(uuid) from public, anon;
grant execute on function public.platform_get_tenant_subscription_history(uuid) to authenticated;

comment on function public.platform_get_tenant_subscription_history(uuid)
  is 'Historial completo de suscripción: fecha/hora, plan, período comprometido y valor/medio de pago/referencia, para el Panel de Plataforma.';

commit;
