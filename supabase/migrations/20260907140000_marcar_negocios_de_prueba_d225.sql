-- ============================================================================
-- MIGRACIÓN: 20260907140000_marcar_negocios_de_prueba_d225.sql
-- DESCRIPCIÓN: Una forma de marcar un negocio como de prueba (D-225, paso 9.29).
--
-- POR QUÉ EXISTE
--
-- D-120 creó la columna `tenants.is_demo` para que los negocios de ensayo no
-- ensuciaran las métricas del SaaS, y `platform_get_saas_metrics` la respeta
-- (`where not t.is_demo`). Pero la marca se puso **con un update escrito a
-- mano dentro de aquella migración**, y nunca se dejó forma de ponerla otra
-- vez: ni RPC, ni botón, ni nada.
--
-- Consecuencia, comprobada contra producción el 07-sep:
--
--   Naguara de Uñas          is_demo = false   (creado 24-jul)
--   Prueba Barbería Elite    is_demo = false   (creado 16-ago)
--   Exportadora              is_demo = false   (creado 21-ago)
--
-- Los tres cuentan como salones reales. Naguara lo era y un script de ensayo
-- de ePayco lo revirtió; los otros dos nacieron después de D-120, con el
-- `default false`, y **nadie los marcó porque no se podía**. Las métricas de
-- la plataforma llevan meses contando negocios de prueba con sus tickets
-- sembrados.
--
-- QUÉ HACE
--
--   1. `platform_set_tenant_demo(tenant, es_prueba)` -- solo el dueño de la
--      plataforma. Deja rastro en `subscription_events`, igual que hace
--      `platform_update_tenant_pricing`.
--   2. Marca los tres negocios de ensayo que existen hoy.
--
-- La marca es REVERSIBLE a propósito: si algún día hace falta que un negocio
-- de prueba reciba los correos de vencimiento para probarlos, se desmarca,
-- se prueba y se vuelve a marcar. Eso es justo lo que hoy no se podía hacer.
-- ============================================================================

begin;

create or replace function public.platform_set_tenant_demo(
  p_tenant_id uuid,
  p_is_demo boolean
)
returns public.tenants
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_tenant public.tenants%rowtype;
  v_sub_id uuid;
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede marcar un negocio como de prueba.';
  end if;

  if p_is_demo is null then
    raise exception 'Hay que decir si el negocio es de prueba o no. No se supone.';
  end if;

  update public.tenants
  set is_demo = p_is_demo
  where id = p_tenant_id
  returning * into v_tenant;

  if not found then
    raise exception 'No se encontró el negocio indicado.';
  end if;

  -- Rastro. La suscripción existe siempre; si por lo que fuera no estuviera,
  -- la marca se aplica igual y solo se pierde el apunte.
  select ts.id into v_sub_id
  from public.tenant_subscriptions ts
  where ts.tenant_id = p_tenant_id;

  if v_sub_id is not null then
    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, provider, payload, created_by
    ) values (
      p_tenant_id,
      v_sub_id,
      'demo_flag_updated',
      'platform_admin',
      jsonb_build_object('is_demo', p_is_demo, 'tenant_name', v_tenant.name),
      auth.uid()
    );
  end if;

  return v_tenant;
end;
$$;

revoke all on function public.platform_set_tenant_demo(uuid, boolean) from public, anon;
grant execute on function public.platform_set_tenant_demo(uuid, boolean) to authenticated;

comment on function public.platform_set_tenant_demo(uuid, boolean) is
  'Marca o desmarca un negocio como de ensayo, solo para el dueño de plataforma. '
  'Un negocio marcado sale de las métricas del SaaS y deja de recibir avisos de '
  'vencimiento. Es reversible a propósito (D-225). NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- Los tres negocios de ensayo que existen hoy.
-- Se marcan por id y no por nombre: los ids salieron de una consulta a
-- producción del 07-sep, y un nombre puede repetirse o cambiar. Si esta
-- migración corre contra otra base, sencillamente no encuentra nada.
-- ---------------------------------------------------------------------------
update public.tenants set is_demo = true
where id in (
  '94029fe3-12c1-4fb4-991f-08db10b5627d',  -- Naguara de Uñas
  'b30a051a-747e-482d-a1bf-f26100136056',  -- Prueba Barbería Elite
  'd9f946e1-ec10-4bc9-ac99-cbff09e8a9eb'   -- Exportadora
);

commit;
