-- CONTROL 238: la pagina publica de un salon tambien funciona con una sesion
-- abierta (hallazgo CE, D-307).
--
-- POR QUE ESTE ARCHIVO
--
-- El 02-oct, con su sesion de Salon y Mas abierta en el celular, el propietario
-- no pudo reservar en la pagina publica de un salon: "permission denied for
-- function public_get_branch_booking_info". Las seis funciones de la pagina
-- publica se concedian solo a `anon`. La migracion 20261002100000 se las da
-- tambien a `authenticated`.
--
-- Que valida, transaccionalmente:
--   1. Las seis funciones existen, y ahora las pueden ejecutar `anon` Y
--      `authenticated`.
--   2. Con una sesion abierta (rol `authenticated`), llamarlas ya no da el error
--      de permisos. Puede dar un error de negocio (una sede o un ticket que no
--      existen): ese no es el que se vigila.
--   3. Sin sesion (rol `anon`), siguen funcionando igual que antes.
--
-- COMO SE EJECUTA (despues de aplicar 20261002100000_la_pagina_publica_tambien_con_sesion_ce.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\238_test_la_pagina_publica_tambien_con_sesion_ce.sql"
--
-- TERMINA EN ROLLBACK. No crea nada que sobreviva.
--
-- El cambio de rol (`set local role` / `reset role`) se copio del control 231,
-- que paso el 27-sep (regla 25d).

begin;

do $ctrl$
declare
  r          record;
  v_cuantas  integer := 0;
  v_branch   uuid;
  v_rol      text;
  v_negadas  text := '';
begin
  -- 1. Las seis, concedidas a los dos
  for r in
    select p.oid, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname in (
        'public_get_branch_booking_info', 'public_get_bookable_services',
        'public_get_available_slots', 'public_create_booking',
        'public_get_ticket_for_review', 'public_create_review'
      )
  loop
    v_cuantas := v_cuantas + 1;
    if not has_function_privilege('authenticated', r.oid, 'EXECUTE') then
      raise exception 'FALLO 1: % sigue negada a quien tiene sesion', r.proname;
    end if;
    if not has_function_privilege('anon', r.oid, 'EXECUTE') then
      raise exception 'FALLO 1b: % ya no la puede usar un visitante sin sesion', r.proname;
    end if;
  end loop;
  if v_cuantas <> 6 then
    raise exception 'FALLO 1c: se esperaban 6 funciones y hay %', v_cuantas;
  end if;
  raise notice 'OK 1   las seis funciones de la pagina publica: anon si, authenticated si';

  select b.id into v_branch from public.branches b where b.active limit 1;
  if v_branch is null then
    raise exception 'FALLO: no hay ninguna sede activa con la que probar';
  end if;

  -- 2 y 3. Llamarlas de verdad, con sesion y sin ella
  foreach v_rol in array array['authenticated', 'anon'] loop
    v_negadas := '';
    perform set_config('request.jwt.claims',
      json_build_object('sub', gen_random_uuid()::text, 'role', v_rol)::text, true);

    begin
      execute format('set local role %I', v_rol);
      perform * from public.public_get_branch_booking_info(v_branch);
      execute 'reset role';
    exception
      when insufficient_privilege then execute 'reset role'; v_negadas := v_negadas || ' public_get_branch_booking_info';
      when others then execute 'reset role';
    end;

    begin
      execute format('set local role %I', v_rol);
      perform * from public.public_get_bookable_services(v_branch);
      execute 'reset role';
    exception
      when insufficient_privilege then execute 'reset role'; v_negadas := v_negadas || ' public_get_bookable_services';
      when others then execute 'reset role';
    end;

    begin
      execute format('set local role %I', v_rol);
      perform * from public.public_get_available_slots(v_branch, null, null, current_date);
      execute 'reset role';
    exception
      when insufficient_privilege then execute 'reset role'; v_negadas := v_negadas || ' public_get_available_slots';
      when others then execute 'reset role';
    end;

    begin
      execute format('set local role %I', v_rol);
      perform * from public.public_create_booking(
        v_branch, null, null, now() + interval '1 day',
        'Control 238', '3000000238', null, null
      );
      execute 'reset role';
    exception
      when insufficient_privilege then execute 'reset role'; v_negadas := v_negadas || ' public_create_booking';
      when others then execute 'reset role';
    end;

    begin
      execute format('set local role %I', v_rol);
      perform * from public.public_get_ticket_for_review(gen_random_uuid());
      execute 'reset role';
    exception
      when insufficient_privilege then execute 'reset role'; v_negadas := v_negadas || ' public_get_ticket_for_review';
      when others then execute 'reset role';
    end;

    begin
      execute format('set local role %I', v_rol);
      perform * from public.public_create_review(gen_random_uuid(), 5, 'Control 238', null, null);
      execute 'reset role';
    exception
      when insufficient_privilege then execute 'reset role'; v_negadas := v_negadas || ' public_create_review';
      when others then execute 'reset role';
    end;

    if v_negadas <> '' then
      raise exception 'FALLO %: como %, el permiso se sigue negando en:%',
        case when v_rol = 'authenticated' then 2 else 3 end, v_rol, v_negadas;
    end if;

    if v_rol = 'authenticated' then
      raise notice 'OK 2   con una sesion abierta, ninguna de las seis da el error de permisos';
    else
      raise notice 'OK 3   sin sesion, las seis siguen funcionando como antes';
    end if;
  end loop;

  perform set_config('request.jwt.claims', '{}', true);

  raise notice '--- CONTROL 238: 3/3 ---';
end
$ctrl$;

rollback;
