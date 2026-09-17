-- CONTROL 213: La lista dice en que estado estan las sedes (D-244, paso 9.45).
--
-- POR QUE ESTE ARCHIVO
--
-- La lista de clientes sabia **cuantas** sedes hay y no **como estan**. Desde
-- que el cobro va por sede (D-239), un cliente con dos sedes y una en mora se
-- veia exactamente igual que uno con las dos al dia: un "2" identico.
--
-- Lo que mas importa vigilar aqui es lo sutil, no lo obvio:
--
--   * que `past_due` y `grace` se cuenten **juntos** como "en mora". Son dos
--     estados de la base y una sola idea para quien mira. Agrupando por estado
--     en vez de por clave saldrian **dos renglones con la misma etiqueta**, y
--     nadie lo notaria hasta tener un cliente en gracia; y
--   * que una sede **cerrada no cuente**, para que el desglose sume siempre lo
--     mismo que el numero de al lado. Un desglose que no cuadra con su total
--     hace dudar de los dos.
--
-- Que valida, transaccionalmente:
--   1. La funcion devuelve la columna `branches_breakdown`.
--   2. Dos sedes en estados distintos se describen por separado y en orden.
--   3. **`past_due` y `grace` se suman en un solo "2 en mora".** La importante.
--   4. Una sede cerrada no entra en el desglose ni en el total.
--   5. Sin sedes activas, dice algo legible en vez de quedarse vacio.
--   6. El singular y el plural concuerdan donde la palabra cambia.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\213_test_desglose_de_sedes_en_la_lista.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.
--
-- NOTA: un disparador (`branches_crear_suscripcion`, D-190) ya le crea su
-- suscripcion `pending` a cada sede, por eso se usa `on conflict (branch_id)
-- do update`. Y `branches.slug` es NOT NULL y unico por negocio. Las dos cosas
-- costaron una corrida cada una en el control 208.

begin;

do $ctrl$
declare
  v_owner    uuid := gen_random_uuid();
  v_plan     uuid;
  v_mixto    uuid;
  v_mora     uuid;
  v_vacio    uuid;
  v_s1       uuid;
  v_s2       uuid;
  v_s3       uuid;
  v_s4       uuid;
  v_s5       uuid;
  v_texto    text;
  v_cuenta   integer;
begin
  -- 1. La columna existe
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral unnest(p.proargnames) as col(nombre)
    where n.nspname = 'public'
      and p.proname = 'platform_list_tenants'
      and col.nombre = 'branches_breakdown'
  ) then
    raise exception 'FALLO 1: platform_list_tenants no devuelve branches_breakdown. Sin el, un cliente con una sede en mora se ve igual que uno al dia (D-244).';
  end if;
  raise notice 'OK 1   la lista devuelve el desglose de sedes';

  -- Fixtures
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_owner, 'owner_test213@salonymas.com')
  on conflict (id) do nothing;
  insert into public.platform_operators (user_id, role, active)
  values (v_owner, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  -- Negocio A: una al dia, una en prueba y una CERRADA pero pagada.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 213 mixto', 'barberia', 'c213a@salonymas.com', '3000000216', true, true)
  returning id into v_mixto;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_mixto, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_mixto, 'C213 A1', 'c213-a1', true, true) returning id into v_s1;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_mixto, 'C213 A2', 'c213-a2', false, true) returning id into v_s2;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_mixto, 'C213 A3', 'c213-a3', false, false) returning id into v_s3;

  insert into public.branch_subscriptions (tenant_id, branch_id, status)
  values (v_mixto, v_s1, 'active'), (v_mixto, v_s2, 'trialing'), (v_mixto, v_s3, 'active')
  on conflict (branch_id) do update set status = excluded.status;

  -- Negocio B: una vencida y otra en gracia. Dos estados, UNA sola idea.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 213 mora', 'barberia', 'c213b@salonymas.com', '3000000217', true, true)
  returning id into v_mora;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_mora, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_mora, 'C213 B1', 'c213-b1', true, true) returning id into v_s4;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_mora, 'C213 B2', 'c213-b2', false, true) returning id into v_s5;

  insert into public.branch_subscriptions (tenant_id, branch_id, status)
  values (v_mora, v_s4, 'past_due'), (v_mora, v_s5, 'grace')
  on conflict (branch_id) do update set status = excluded.status;

  -- Negocio C: sin ninguna sede activa.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 213 vacio', 'barberia', 'c213c@salonymas.com', '3000000218', true, true)
  returning id into v_vacio;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_vacio, v_plan, 'active', now() + interval '30 days');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  -- 2. Estados distintos, renglones distintos y en orden
  select branches_breakdown into v_texto
  from public.platform_list_tenants() where tenant_id = v_mixto;

  if v_texto is distinct from '1 al dia' || ' ' || chr(183) || ' ' || '1 en prueba' then
    raise exception 'FALLO 2: el desglose deberia decir "1 al dia (punto) 1 en prueba" y dice "%"', v_texto;
  end if;
  raise notice 'OK 2   dos estados distintos se describen por separado y en orden';

  -- 4. La cerrada no entra, ni en el desglose ni en el total
  select real_branches_count into v_cuenta
  from public.platform_list_tenants() where tenant_id = v_mixto;
  if v_cuenta <> 2 then
    raise exception 'FALLO 4: cuenta % sedes y solo 2 estan abiertas', v_cuenta;
  end if;
  if v_texto like '%3%' then
    raise exception 'FALLO 4b: la sede cerrada se colo en el desglose: %', v_texto;
  end if;
  raise notice 'OK 4   una sede cerrada no cuenta, y el desglose cuadra con el total';

  -- 3. LA IMPORTANTE: vencida y en gracia son UNA sola idea
  select branches_breakdown into v_texto
  from public.platform_list_tenants() where tenant_id = v_mora;

  if v_texto is distinct from '2 en mora' then
    raise exception 'FALLO 3: `past_due` y `grace` deberian sumarse en "2 en mora" y sale "%". Si se agrupa por ESTADO en vez de por clave, salen dos renglones con la misma etiqueta y nadie lo nota hasta tener un cliente en gracia (D-244).', v_texto;
  end if;
  raise notice 'OK 3   vencida y en gracia se suman en un solo "2 en mora"';

  -- 5. Sin sedes activas, algo legible
  select branches_breakdown into v_texto
  from public.platform_list_tenants() where tenant_id = v_vacio;

  if v_texto is null then
    raise exception 'FALLO 5: sin sedes activas devuelve nulo. La pantalla enseniaria un hueco, que se lee como un error de carga.';
  end if;
  if v_texto not ilike '%sin sedes%' then
    raise exception 'FALLO 5b: sin sedes activas dice "%", que no lo explica', v_texto;
  end if;
  raise notice 'OK 5   sin sedes activas dice algo legible';

  -- 6. Singular y plural donde la palabra cambia
  update public.branch_subscriptions set status = 'suspended' where branch_id = v_s4;
  update public.branch_subscriptions set status = 'active' where branch_id = v_s5;

  select branches_breakdown into v_texto
  from public.platform_list_tenants() where tenant_id = v_mora;
  if v_texto not like '%1 suspendida%' then
    raise exception 'FALLO 6: con una sola deberia decir "1 suspendida" y dice "%"', v_texto;
  end if;

  update public.branch_subscriptions set status = 'suspended' where branch_id = v_s5;
  select branches_breakdown into v_texto
  from public.platform_list_tenants() where tenant_id = v_mora;
  if v_texto not like '%2 suspendidas%' then
    raise exception 'FALLO 6b: con dos deberia decir "2 suspendidas" y dice "%"', v_texto;
  end if;
  raise notice 'OK 6   el singular y el plural concuerdan';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 213 COMPLETO: 6 de 6 en verde.';
end
$ctrl$;

rollback;
