-- CONTROL 217: Un telefono, una persona (D-249, paso 9.52).
--
-- POR QUE ESTE ARCHIVO
--
-- El celular es la llave del portal de la clienta (D-167): con el y un PIN se
-- ven sus citas y sus fotos. El propietario decidio el 19-sep que esa llave
-- **no se comparte**, y su razon no era el orden de los datos:
--
--   *"cuando un usuario del numero autorice datos del otro, ahi que?"*
--
-- Asi que lo que este control protege no es una tabla limpia: es que **nadie
-- pueda autorizar ni ver lo de otra persona por compartir un numero**.
--
-- Que valida, transaccionalmente:
--   1. La regla existe y esta en UN solo sitio.
--   2. La forma canonica: espacios, guiones y el indicativo +57 dan lo mismo.
--   3. **Diez digitos o se para**, con un mensaje que se entiende.
--   4. **Crear con un celular que ya es de otra se niega**, y dice de quien es.
--   5. **Editar hacia un celular ajeno tambien se niega.** Es la otra puerta.
--   6. `+57 <numero>` y `<numero>` son la MISMA clienta al reservar. El caso
--      que se colo en el control 216 y destapo todo esto.
--   7. El candado existe y es por negocio.
--   8. **Desactivar una ficha libera su numero**, para que un salon pueda
--      reusarlo cuando una clienta se va y otra llega con ese celular.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\217_test_un_telefono_una_persona.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_tenant    uuid;
  v_branch    uuid;
  v_service   uuid;
  v_bservice  uuid;
  v_stylist   uuid;
  v_bstylist  uuid;
  v_dueno     uuid := gen_random_uuid();
  v_slot      timestamptz;
  v_manana    date;
  v_c1        uuid;
  v_c2        uuid;
  v_clientes  integer;
  v_capturo   boolean;
  v_error     text;
  v_norm      text;
begin
  -- 1. La regla existe y esta en un solo sitio
  if to_regprocedure('private.beautyos_celular_valido(text)') is null then
    raise exception 'FALLO 1: no existe private.beautyos_celular_valido';
  end if;
  if to_regprocedure('private.beautyos_celular_normalizado(text)') is null then
    raise exception 'FALLO 1b: no existe private.beautyos_celular_normalizado';
  end if;
  raise notice 'OK 1   la regla del celular existe y vive en private';

  -- 2. La forma canonica
  if private.beautyos_celular_normalizado('350 681 56 29') <> '3506815629' then
    raise exception 'FALLO 2: los espacios no se limpian';
  end if;
  if private.beautyos_celular_normalizado('350-681-5629') <> '3506815629' then
    raise exception 'FALLO 2b: los guiones no se limpian';
  end if;
  if private.beautyos_celular_normalizado('+57 350 681 5629') <> '3506815629' then
    raise exception 'FALLO 2c: el indicativo +57 no se quita. ESTE es el caso que se colo en el control 216.';
  end if;
  if private.beautyos_celular_normalizado('   ') is not null then
    raise exception 'FALLO 2d: un celular vacio deberia ser null, no una cadena';
  end if;
  raise notice 'OK 2   espacios, guiones e indicativo dan el mismo numero';

  -- 3. Diez digitos o se para
  v_capturo := false;
  begin
    v_norm := private.beautyos_celular_valido('323456789');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 3: acepto un celular de nueve digitos (%). La llave a medias es una llave equivocada.', v_norm;
  end if;
  if v_error not ilike '%10 digitos%' then
    raise exception 'FALLO 3b: se nego pero sin explicar cuantos digitos faltan. Dijo: %', v_error;
  end if;
  raise notice 'OK 3   nueve digitos se niegan, y el mensaje dice por que';

  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_dueno, 'dueno_test217@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 217', 'barberia', 'c217@salonymas.com', '3000000217', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C217 sede', 'c217-sede', true, true)
  returning id into v_branch;

  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, v_branch, d, time '06:00', time '22:00', true from generate_series(1, 7) d;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true);

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  -- 4. Crear con un celular que ya es de otra se niega, y dice de quien es
  select c.id into v_c1 from public.create_client('C217 Ana', '3101112233') c;
  if v_c1 is null then
    raise exception 'FALLO 4: no se pudo crear la primera clienta';
  end if;

  v_capturo := false;
  begin
    perform public.create_client('C217 Su hermana', '310 111 22 33');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception 'FALLO 4: dos personas comparten celular. Eso significa que una puede autorizar las fotos de la otra y ver sus citas.';
  end if;
  if v_error not ilike '%C217 Ana%' then
    raise exception 'FALLO 4b: se nego, pero sin decir de quien es el numero. Dijo: %', v_error;
  end if;
  raise notice 'OK 4   el celular repetido se niega, y dice de quien es';

  -- 5. Editar hacia un celular ajeno tambien se niega
  select c.id into v_c2 from public.create_client('C217 Beatriz', '3204445566') c;

  v_capturo := false;
  begin
    perform public.update_client(v_c2, 'C217 Beatriz', '+57 3101112233');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception 'FALLO 5: editando se pudo robar el celular de otra clienta. La puerta de crear estaba cerrada y la de editar abierta.';
  end if;
  raise notice 'OK 5   editar hacia un celular ajeno tambien se niega';

  -- 6. Al reservar, +57 y el numero pelado son la MISMA clienta
  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C217 corte', 'Corte', 30, 20000, true) returning id into v_service;
  insert into public.branch_services (tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active)
  values (v_tenant, v_branch, v_service, 20000, 30, true, true) returning id into v_bservice;
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C217 estilista', '3000000000', 'Corte') returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day') returning id into v_bstylist;
  insert into public.branch_stylist_services (tenant_id, branch_id, branch_stylist_id, branch_service_id, active)
  values (v_tenant, v_branch, v_bstylist, v_bservice, true);

  v_manana := ((now() at time zone 'America/Bogota')::date + 1);

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  perform public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C217 Carmen', '3155556677', null, 'control 217');

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  perform public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C217 Carmen', '+57 315 555 6677', null, 'control 217');

  select count(*) into v_clientes
  from public.clients where tenant_id = v_tenant and phone = '3155556677';

  if v_clientes <> 1 then
    raise exception
      'FALLO 6: "+57 315 555 6677" dejo % fichas. Con el indicativo delante sigue siendo la misma persona, y esto es lo que destapo el control 216.',
      v_clientes;
  end if;
  raise notice 'OK 6   al reservar, +57 y el numero pelado son la misma clienta';

  -- 7. El candado existe y es por negocio
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'clients_tenant_phone_uidx'
  ) then
    raise exception 'FALLO 7: falta el indice unico clients_tenant_phone_uidx';
  end if;
  raise notice 'OK 7   el candado existe';

  -- 8. Desactivar una ficha libera su numero
  update public.clients set active = false where id = v_c1;

  begin
    perform public.create_client('C217 La nueva duena del numero', '3101112233');
  exception when others then
    raise exception
      'FALLO 8: con la ficha vieja desactivada el numero sigue bloqueado. Un salon tiene que poder reusar el celular de una clienta que se fue. Dijo: %',
      sqlerrm;
  end;
  raise notice 'OK 8   desactivar una ficha libera su numero';

  raise notice ' ';
  raise notice 'CONTROL 217: 8 de 8 en verde';
end
$ctrl$;

rollback;
