-- CONTROL 220: El precio es de la sede, y el camino del negocio esta cerrado.
--              Hallazgo AG, parte 1.
--
-- POR QUE ESTE ARCHIVO
--
-- Desde D-239 quien cobra es la sede, pero el precio del negocio seguia vivo
-- y ofreciendo un camino de cobro propio. En la misma pantalla habia **dos
-- botones que cobraban distinto**, y el de arriba cobraba por un camino que
-- no activa ninguna sede: se pagaba y no pasaba nada.
--
-- Medido antes de tocar: los tres negocios de la base tenian una sede a
-- tarifa de lista mientras su negocio decia otra cosa. Peluqueria Exito decia
-- $4.500 y su unica sede habria cobrado $150.000.
--
-- Que valida, transaccionalmente:
--   1. **La puerta esta cerrada:** iniciar un cobro de negocio se niega, y el
--      mensaje dice por donde se cobra ahora.
--   2. **La maquinaria que liquida sigue viva.** Si se hubiera borrado, un
--      pago confirmado por ePayco dejaria de registrarse.
--   3. El camino de la sede funciona: calcula un cargo de verdad.
--   4. **Ninguna sede viva cobra tarifa de lista mientras su negocio tiene un
--      acuerdo.** Es el desajuste entero de AG, convertido en invariante.
--   5. Una sede con precio pactado cobra ESE precio, no el de lista.
--   6. El descuento del negocio ya no toca lo que paga una sede.
--   7. `anon` no alcanza el calculo de la sede.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\220_test_el_precio_es_de_la_sede.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_tenant    uuid;
  v_branch    uuid;
  v_branch2   uuid;
  v_dueno     uuid := gen_random_uuid();
  v_memb      uuid;
  v_capturo   boolean;
  v_error     text;
  v_monto     bigint;
  v_huerfanas text;
  v_lista     bigint;
begin
  -- 1. La puerta de cobro del negocio esta cerrada
  v_capturo := false;
  begin
    perform 1 from public.beautyos_calcular_cargo_epayco(gen_random_uuid(), 'pro');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception
      'FALLO 1: todavia se puede iniciar un cobro por negocio. Ese camino cobra sin activar ninguna sede: se paga y no pasa nada.';
  end if;
  if v_error not ilike '%sede%' then
    raise exception 'FALLO 1b: se nego, pero sin decir por donde se cobra ahora. Dijo: %', v_error;
  end if;
  raise notice 'OK 1   iniciar un cobro por negocio se niega, y dice por donde va ahora';

  -- 2. La maquinaria que LIQUIDA sigue viva
  if to_regprocedure('private.beautyos_procesar_evento_epayco(uuid, text, text, bigint, text, jsonb)') is null
     and not exists (
       select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'private' and p.proname = 'beautyos_procesar_evento_epayco'
     ) then
    raise exception
      'FALLO 2: desaparecio el procesador de pagos del negocio. Un pago rezagado confirmado por ePayco dejaria de registrarse: la clienta paga y el sistema no se entera.';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'beautyos_calcular_cargo_epayco'
  ) then
    raise exception 'FALLO 2b: desaparecio el calculo interno del que cuelga ese procesador.';
  end if;
  raise notice 'OK 2   la maquinaria que liquida un pago de negocio sigue viva';

  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;
  select p.price_cop into v_lista from public.plans p where p.id = v_plan;

  insert into auth.users (id, email) values (v_dueno, 'dueno_test220@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 220', 'peluqueria', 'c220@salonymas.com', '3000000220', true)
  returning id into v_tenant;

  -- El negocio con un acuerdo: 10.000 pactados. Antes de AG esto decidia lo
  -- que se cobraba; ahora no decide nada.
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_end, price_cop, price_reason
  ) values (
    v_tenant, v_plan, 'active', now() + interval '30 days', 10000, 'Acuerdo de prueba del control 220'
  );

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C220 sede pactada', 'c220-pactada', true, true)
  returning id into v_branch;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C220 sede a lista', 'c220-lista', false, true)
  returning id into v_branch2;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true) returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);

  -- Las sedes pueden nacer con su suscripcion por disparador; se completa lo
  -- que falte sin dar por hecho que existe.
  insert into public.branch_subscriptions (tenant_id, branch_id, status)
  select v_tenant, b.id, 'pending'
  from public.branches b
  where b.tenant_id = v_tenant
    and not exists (
      select 1 from public.branch_subscriptions bs where bs.branch_id = b.id
    );

  update public.branch_subscriptions
     set price_cop = 25000,
         price_reason = 'Acuerdo de la sede, control 220'
   where branch_id = v_branch;

  -- 3. El camino de la sede si calcula
  select c.monto_cop into v_monto
  from private.beautyos_calcular_cargo_sede(v_branch) c;

  if v_monto is null then
    raise exception 'FALLO 3: el camino de la sede no devolvio ningun cargo. Si el del negocio se cierra y este no calcula, no se puede cobrar nada.';
  end if;
  raise notice 'OK 3   el camino de la sede calcula un cargo de verdad';

  -- 5. Una sede pactada cobra SU precio
  if v_monto <> 25000 then
    raise exception 'FALLO 5: la sede pactada en 25.000 calculo %. El precio de la sede tiene que mandar.', v_monto;
  end if;
  raise notice 'OK 5   la sede pactada cobra su precio, no el de lista';

  -- 6. Y el acuerdo del negocio ya no toca lo que paga la otra sede
  select c.monto_cop into v_monto
  from private.beautyos_calcular_cargo_sede(v_branch2) c;

  if v_monto = 10000 then
    raise exception
      'FALLO 6: la sede sin pactar cobro los 10.000 del negocio. El precio del negocio se retiro: si todavia decide, AG no esta cerrado.';
  end if;
  if v_monto <> v_lista then
    raise exception 'FALLO 6b: la sede sin pactar calculo % y la tarifa de lista es %.', v_monto, v_lista;
  end if;
  raise notice 'OK 6   el acuerdo del negocio ya no decide lo que paga una sede (cobro % de lista)', v_monto;

  -- 4. LA INVARIANTE: ninguna sede viva a tarifa de lista con acuerdo arriba
  --
  -- Se mira sobre los negocios REALES, no sobre el de prueba -- el de este
  -- control tiene una sede a lista a proposito, para poder probar la 6.
  select string_agg(t.name || ' / ' || b.name, ', ')
    into v_huerfanas
  from public.branch_subscriptions bs
  join public.branches b on b.id = bs.branch_id
  join public.tenants t on t.id = b.tenant_id
  join public.tenant_subscriptions ts on ts.tenant_id = t.id
  where t.active and b.active
    and t.id <> v_tenant
    and bs.price_cop is null
    and (ts.price_cop is not null or ts.discount_percent is not null);

  if v_huerfanas is not null then
    raise exception
      'FALLO 4: estas sedes cobrarian tarifa de lista mientras su negocio tiene un acuerdo: %. Es el desajuste que AG vino a cerrar.',
      v_huerfanas;
  end if;
  raise notice 'OK 4   ninguna sede real cobra tarifa de lista teniendo su negocio un acuerdo';

  -- 7. anon no alcanza el calculo de la sede
  if has_function_privilege('anon', 'public.beautyos_calcular_cargo_sede(uuid)', 'execute') then
    raise exception 'FALLO 7: anon puede calcular lo que cuesta una sede.';
  end if;
  raise notice 'OK 7   anon no alcanza el calculo de la sede';

  raise notice ' ';
  raise notice 'CONTROL 220: 7 de 7 en verde';
end
$ctrl$;

rollback;
