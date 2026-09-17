-- ============================================================================
-- MIGRACION: 20260917100000_el_registro_estaba_roto_d245.sql
-- DESCRIPCION: P0 - nadie podia registrarse desde el 01-sep (D-245, paso 9.46).
--
-- QUE PASABA
--
-- `register_tenant` buscaba el plan asi:
--
--     where p.code = 'profesional' and p.status = 'active'
--
-- y **D-188 jubilo ese codigo el 01-sep**, al fundir los tres planes en uno
-- solo llamado 'pro':
--
--     update public.plans set status = 'retired'
--     where code in ('basico', 'business', 'profesional');
--
-- Desde ese dia, cualquiera que intentara registrarse recibia *"No hay un plan
-- disponible para registrar la solicitud"*. **Dieciseis dias.**
--
-- POR QUE NO SE NOTO, QUE ES LA PARTE QUE IMPORTA
--
-- Porque en dieciseis dias no se registro nadie. El propietario lo descubrio
-- hoy, al invitar a sus primeros probadores, y lo vio **un desconocido antes
-- que nosotros**.
--
-- Es la tercera vez con la misma forma: el cobro caido 26 dias por las llaves
-- heredadas (D-215), el `calc is not defined` que llego a produccion (hallazgo
-- AB), y ahora esto. **Un camino que nadie recorre no avisa de que esta roto:
-- avisa el primero que lo recorre, y suele ser un cliente.**
--
-- QUE HACE
--
-- El plan **deja de buscarse por su codigo**. Escribir 'pro' repetiria la
-- trampa en el siguiente cambio de catalogo; se pide EL plan activo, y si hay
-- cero o mas de uno la funcion **se para y dice por que** en vez de adivinar.
--
-- El cuerpo se extrajo del de D-173 y solo se le cambiaron la declaracion y
-- ese bloque: es la regla de comparar linea por linea al reescribir una
-- funcion (D-119, D-122, D-123).
--
-- Y nace el **control 214**, que llama a `register_tenant` de verdad dentro de
-- una transaccion. Es el que habria cazado esto el 01-sep.
-- ============================================================================

begin;

create or replace function public.register_tenant(
  p_business_name text,
  p_owner_full_name text,
  p_whatsapp text,
  p_business_type text default null,
  p_city text default null,
  p_estimated_branches integer default 1,
  p_estimated_team_size integer default 1,
  p_referral_source text default null,
  p_referral_code_used text default null
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  status text
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
  v_planes_activos integer;
  v_subscription_id uuid;
  v_slug text;
  v_referral_code_clean text;
  v_partner_id uuid;
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

  -- D-245: **el plan ya no se busca por su codigo.**
  --
  -- Aqui decia `where p.code = 'profesional'`. D-188 jubilo ese codigo el
  -- 01-sep al fundir los tres planes en uno solo ('pro'), y desde ese dia
  -- **nadie pudo registrarse**. Tardo 16 dias en notarse porque en 16 dias no
  -- se registro nadie: se apago en silencio, como el cobro con las llaves
  -- heredadas (D-215).
  --
  -- Escribir 'pro' aqui seria repetir la trampa en el siguiente cambio de
  -- catalogo. Se pide EL plan activo, sin nombrarlo. D-188 establecio que hay
  -- uno solo; si algun dia hay dos, esto **se para y dice por que**, en vez de
  -- elegir uno al azar y cobrarle mal a alguien.
  select count(*)::integer into v_planes_activos
  from public.plans p
  where p.status = 'active';

  if v_planes_activos = 0 then
    raise exception 'No hay ningun plan activo en el catalogo, asi que no se puede registrar. Revisa public.plans (D-245).';
  end if;

  if v_planes_activos > 1 then
    raise exception 'Hay % planes activos y el registro no sabe cual usar. Deja uno solo activo (D-188) o dile a esta funcion cual (D-245).', v_planes_activos;
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.status = 'active';

  v_slug := private.beautyos_generate_unique_tenant_slug(p_business_name);

  -- Partner (D-173): el código puede no existir (se guarda igual en
  -- referral_code_used para trazabilidad) o pertenecer a un partner
  -- inactivo (no se vincula, pero el código queda registrado).
  v_referral_code_clean := upper(trim(coalesce(p_referral_code_used, '')));
  if length(v_referral_code_clean) = 0 then
    v_referral_code_clean := null;
  end if;

  if v_referral_code_clean is not null then
    select p.id into v_partner_id
    from public.partners p
    where p.referral_code = v_referral_code_clean
      and p.active = true;
  end if;

  insert into public.tenants (
    name,
    slug,
    business_type,
    contact_email,
    whatsapp,
    city,
    estimated_branches,
    estimated_team_size,
    referral_source,
    partner_id,
    referral_code_used,
    active
  ) values (
    trim(p_business_name),
    v_slug,
    nullif(trim(coalesce(p_business_type, '')), ''),
    v_email,
    trim(p_whatsapp),
    nullif(trim(coalesce(p_city, '')), ''),
    greatest(1, coalesce(p_estimated_branches, 1)),
    greatest(1, coalesce(p_estimated_team_size, 1)),
    nullif(trim(coalesce(p_referral_source, '')), ''),
    v_partner_id,
    v_referral_code_clean,
    true
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

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open
  )
  select
    v_tenant_id,
    v_branch_id,
    schedule.day_of_week,
    schedule.opens_at,
    schedule.closes_at,
    schedule.is_open
  from (
    values
      (1, time '08:00', time '20:00', true),
      (2, time '08:00', time '20:00', true),
      (3, time '08:00', time '20:00', true),
      (4, time '08:00', time '20:00', true),
      (5, time '08:00', time '20:00', true),
      (6, time '08:00', time '20:00', true),
      (7, null::time, null::time, false)
  ) as schedule(day_of_week, opens_at, closes_at, is_open);

  insert into public.appointment_policies (tenant_id, branch_id)
  values (v_tenant_id, v_branch_id);

  insert into public.commission_policies (tenant_id)
  values (v_tenant_id);

  -- Filtro de Aceptación (D-125): el negocio nace en estado 'pending'.
  -- La prueba gratis NO arranca aquí (trial_ends_at = NULL).
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, trial_ends_at, current_period_start
  ) values (
    v_tenant_id, v_plan_id, 'pending', null, null
  )
  returning id into v_subscription_id;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    v_tenant_id,
    v_subscription_id,
    'registration_requested',
    jsonb_build_object(
      'business_name', trim(p_business_name),
      'owner_full_name', trim(p_owner_full_name),
      'city', nullif(trim(coalesce(p_city, '')), ''),
      'business_type', nullif(trim(coalesce(p_business_type, '')), ''),
      'estimated_branches', p_estimated_branches,
      'estimated_team_size', p_estimated_team_size,
      'referral_source', nullif(trim(coalesce(p_referral_source, '')), ''),
      'referral_code_used', v_referral_code_clean,
      'partner_id', v_partner_id
    ),
    v_user_id
  );

  return query select v_tenant_id, v_branch_id, 'pending'::text;
end;
$$;

revoke all on function public.register_tenant(
  text, text, text, text, text, integer, integer, text, text
) from public, anon;
grant execute on function public.register_tenant(
  text, text, text, text, text, integer, integer, text, text
) to authenticated;

comment on function public.register_tenant(
  text, text, text, text, text, integer, integer, text, text
) is
  'Alta autoservicio de un negocio con su primera sede (D-173). Desde D-245 '
  '**no nombra el plan por su codigo**: pide el unico plan activo, porque '
  'nombrarlo dejo el registro roto 16 dias cuando D-188 jubilo "profesional". '
  'NO ELIMINAR.';

commit;
