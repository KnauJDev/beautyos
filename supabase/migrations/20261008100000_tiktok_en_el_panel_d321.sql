-- ==============================================================================
-- El Panel ve el TikTok de cada salón. (D-321)
-- ==============================================================================
--
-- QUÉ PASA
--
-- D-319 agregó `tenants.tiktok` y no tocó el Panel, a propósito. El 08-oct el
-- propietario preguntó por qué no lo veía en la ficha del salón, junto a
-- Instagram y Facebook, y pidió agregarlo. Solo para leer: las redes las
-- escribe cada salón en su Configuración.
--
-- CÓMO SE ESCRIBIÓ (regla 10)
--
-- **Generada por un script desde el texto vivo** de `platform_list_tenants`
-- (lectura `intervenciones/extraer_redes_tiktok.sql`, 08-oct; D-319 no tocó
-- esta función). Solo dos cambios, comprobados uno por uno: `tiktok text` al
-- final de lo que devuelve, y `t.tiktok` al final de lo que selecciona. Todo
-- lo demás es el texto vivo tal cual, incluido `search_path = pg_catalog`.
-- Cambiar lo que devuelve exige DROP (D-237); los permisos y el comentario,
-- los de D-244.
--
-- Lo prueba el CONTROL 247.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

drop function if exists public.platform_list_tenants();

CREATE OR REPLACE FUNCTION public.platform_list_tenants()
 RETURNS TABLE(tenant_id uuid, tenant_name text, contact_name text, business_type text, city text, estimated_branches integer, estimated_team_size integer, referral_source text, rejection_reason text, contact_email text, contact_phone text, whatsapp text, instagram text, facebook text, real_branches_count integer, real_team_count integer, team_breakdown text, tenant_active boolean, is_demo boolean, plan_code text, subscription_status text, is_founder boolean, price_cop bigint, discount_percent numeric, trial_ends_at timestamp with time zone, current_period_end timestamp with time zone, grace_ends_at timestamp with time zone, created_at timestamp with time zone, paid_periods_count integer, total_paid_cop bigint, effective_monthly_price bigint, debt_status text, debt_amount_cop bigint, active_overrides_count integer, partner_id uuid, partner_name text, referral_code_used text, branches_breakdown text, tiktok text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
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
    t.created_at,
    coalesce(pagos.cnt, 0),
    coalesce(pagos.total_cop, 0),
    coalesce(precio.precio_cop, 0),
    case
      when ts.status = 'trialing' then 'en_prueba'
      when ts.status in ('past_due', 'grace') then 'en_mora'
      when ts.status = 'suspended' and last_susp.event_type = 'auto_suspended_grace_expired' then 'en_mora'
      else 'al_dia'
    end,
    case
      when ts.status in ('past_due', 'grace') then coalesce(precio.precio_cop, ts.price_cop, 0)
      when ts.status = 'suspended' and last_susp.event_type = 'auto_suspended_grace_expired'
        then coalesce(precio.precio_cop, ts.price_cop, 0)
      else 0
    end,
    coalesce(overrides.cnt, 0),
    t.partner_id,
    partner.full_name,
    t.referral_code_used,
    -- D-244: en que estado de pago estan esas sedes, no solo cuantas.
    coalesce(sedes.branches_breakdown, 'Sin sedes activas'),
    -- D-321: el TikTok del salón (D-319), para verlo en el Panel.
    t.tiktok
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  left join public.user_profiles up_owner
    on up_owner.tenant_id = t.id
   and up_owner.role = 'owner'
   and up_owner.active = true
  left join public.partners partner on partner.id = t.partner_id
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
  left join lateral (
    select
      count(*)::integer as cnt,
      coalesce(sum((se.payload->>'monto_cop_recibido')::bigint), 0)::bigint as total_cop
    from public.subscription_events se
    where se.tenant_id = t.id
      and se.provider = 'epayco'
      and se.payload ? 'monto_cop_recibido'
  ) pagos on true
  left join lateral (
    select pe.precio_cop
    from private.beautyos_precio_efectivo(t.id) pe
  ) precio on true
  left join lateral (
    select se.event_type
    from public.subscription_events se
    where se.tenant_id = t.id
      and se.event_type in ('suspended_by_platform', 'auto_suspended_grace_expired')
    order by se.created_at desc
    limit 1
  ) last_susp on true
  left join lateral (
    select count(*)::integer as cnt
    from public.tenant_feature_overrides tfo
    where tfo.tenant_id = t.id
      and tfo.starts_at <= now()
      and (tfo.ends_at is null or tfo.ends_at > now())
  ) overrides on true
  left join lateral (
    -- Mismo patron que `team_breakdown` (D-162): una frase corta armada en el
    -- servidor, en vez de seis numeros que la pantalla tenga que recomponer.
    --
    -- Se agrupa por la CLAVE y no por el estado: `past_due` y `grace` son los
    -- dos "en mora", y agrupar por estado daria dos renglones con la misma
    -- etiqueta.
    select string_agg(
             cnt || ' ' ||
             case clave
               when 'al_dia'     then 'al dia'
               when 'en_prueba'  then 'en prueba'
               when 'sin_pagar'  then 'sin pagar'
               when 'en_mora'    then 'en mora'
               when 'suspendida' then (case when cnt = 1 then 'suspendida' else 'suspendidas' end)
               else                   (case when cnt = 1 then 'cancelada' else 'canceladas' end)
             end,
             ' · ' order by ord
           ) as branches_breakdown
    from (
      select
        case bs.status
          when 'active'    then 'al_dia'
          when 'trialing'  then 'en_prueba'
          when 'pending'   then 'sin_pagar'
          when 'past_due'  then 'en_mora'
          when 'grace'     then 'en_mora'
          when 'suspended' then 'suspendida'
          else                  'cancelada'
        end as clave,
        case bs.status
          when 'active'    then 1
          when 'trialing'  then 2
          when 'pending'   then 3
          when 'past_due'  then 4
          when 'grace'     then 4
          when 'suspended' then 5
          else                  6
        end as ord,
        count(*)::integer as cnt
      from public.branches b
      join public.branch_subscriptions bs on bs.branch_id = b.id
      where b.tenant_id = t.id
        and b.active = true
      group by 1, 2
    ) s
  ) sedes on true
  order by
    case when ts.status = 'pending' then 0 else 1 end,
    t.is_demo,
    t.created_at desc;
end;
$function$;

revoke all on function public.platform_list_tenants() from public, anon, authenticated;
grant execute on function public.platform_list_tenants() to authenticated;

comment on function public.platform_list_tenants() is
  'Lista de negocios para el Panel de Plataforma: capacidad operativa real '
  '(D-162), vision 360 financiera (D-172), partner vinculado (D-173) y, desde '
  'D-244, **en que estado de pago estan sus sedes** -- no solo cuantas hay. '
  'Desde D-321 devuelve tambien el TikTok del salon. '
  'NO ELIMINAR.';

commit;
