-- CONTROL 223: Una sola register_tenant, y nada de private para anon.
--              Hallazgos BG y BH.
--
-- POR QUE ESTE ARCHIVO EXISTE
--
-- El control 214 vigila que el registro funcione **por la firma que usa la
-- app**. No podia ver que existia otra firma, de 8 parametros, que todavia
-- buscaba el plan 'profesional': un control que vigila una funcion no vigila
-- una regla (la misma leccion del control 221). Este mira el catalogo.
--
-- Que valida:
--   1. Hay exactamente UNA register_tenant en public.
--   2. Es la de 9 parametros, la que usa la app.
--   3. Y authenticated la puede ejecutar: el registro sigue abierto.
--   4. Ninguna funcion de private la puede ejecutar anon.
--   5. Las nueve que la radiografia encontro abiertas siguen disponibles para
--      authenticated: quitar el permiso de anon no rompe nada con sesion.
--
-- COMO SE EJECUTA (despues de aplicar 20260923130000_una_sola_register_tenant_y_permisos_de_private_bg_bh.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\223_test_una_sola_register_tenant.sql"
--
-- SOLO LEE. Termina en rollback de todos modos.

begin;

do $ctrl$
declare
  v_cuantas integer;
  v_firma   text;
  v_abiertas text;
begin
  -- 1. Una sola
  select count(*) into v_cuantas
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'register_tenant';

  if v_cuantas <> 1 then
    raise exception 'FALLO 1: hay % register_tenant en public. Tiene que haber una: dos firmas dejan a PostgREST eligiendo.', v_cuantas;
  end if;
  raise notice 'OK 1   hay una sola register_tenant';

  -- 2. La de 9
  if to_regprocedure('public.register_tenant(text, text, text, text, text, integer, integer, text, text)') is null then
    raise exception 'FALLO 2: la que queda no es la de 9 parametros, que es la que manda la app.';
  end if;
  raise notice 'OK 2   es la de 9 parametros, la que usa la app';

  -- 3. El registro sigue abierto
  if not has_function_privilege('authenticated',
      'public.register_tenant(text, text, text, text, text, integer, integer, text, text)', 'execute') then
    raise exception 'FALLO 3: authenticated no puede registrarse. El registro esta cerrado.';
  end if;
  raise notice 'OK 3   authenticated puede registrarse';

  -- 4. Nada de private para anon
  select string_agg(p.oid::regprocedure::text, ', ')
    into v_abiertas
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and p.prokind = 'f'
    and has_function_privilege('anon', p.oid, 'execute');

  if v_abiertas is not null then
    raise exception 'FALLO 4: anon puede ejecutar funciones de private: %', v_abiertas;
  end if;
  raise notice 'OK 4   anon no puede ejecutar ninguna funcion de private';

  -- 5. Con sesion, todo sigue
  foreach v_firma in array array[
    'private.beautyos_celular_normalizado(text)',
    'private.beautyos_celular_valido(text)',
    'private.beautyos_precio_efectivo(uuid)',
    'private.beautyos_require_limit(uuid, text, integer, text)'
  ]
  loop
    if to_regprocedure(v_firma) is not null
       and not has_function_privilege('authenticated', v_firma, 'execute') then
      raise exception 'FALLO 5: authenticated perdio % . Quitarle el permiso a anon no debia tocar a nadie con sesion.', v_firma;
    end if;
  end loop;
  raise notice 'OK 5   authenticated conserva las que tenia';

  raise notice '--- CONTROL 223: 5/5 ---';
end
$ctrl$;

rollback;
