-- ==============================================================================
-- HALLAZGOS BG y BH: higiene que encontro la radiografia de la base (23-sep)
-- ==============================================================================
--
-- BG — `register_tenant` TENIA DOS VERSIONES
--
-- La de 9 parametros es la que usa la app, arreglada el 17-sep (D-245). La de
-- 8, del 27-ago, **nadie la retiro** cuando el 30-ago se anadio el parametro de
-- referidos, porque `create or replace` con otra firma NO reemplaza: anade
-- una sobrecarga. **Y esa version vieja todavia busca el plan 'profesional'**,
-- jubilado el 01-sep: es el fallo de D-245 vivo en una segunda puerta, la
-- misma forma que el 50% de D-252. Hoy no la llama nadie, pero cualquier
-- llamada sin el codigo de referido encontraria dos candidatas.
--
-- BH — NUEVE FUNCIONES DE `private` CON EL PERMISO POR DEFECTO A PUBLIC
--
-- PostgreSQL da EXECUTE a PUBLIC al crear una funcion, y estas nueve nunca se
-- lo quitaron, asi que `anon` las tiene. **No se alcanzan desde internet**: la
-- API solo publica `public` (D-214). Es higiene, no un agujero: que la regla
-- sea la misma en todo `private`, como hizo D-174 con H-11.
--
-- **Se le quita a PUBLIC y a anon, y se le da explicitamente a authenticated y
-- service_role.** Asi nada que hoy funcione con sesion deja de funcionar: si
-- alguna la usa un CHECK o una funcion que corre como el usuario, sigue
-- teniendo permiso. Lo unico que se pierde es lo que nadie deberia tener.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Respaldo:   scripts\respaldo_supabase.ps1
--   2. Esta migracion con scripts\aplicar_sql.ps1
--   3. El control: supabase\sql\223_test_una_sola_register_tenant.sql
-- ==============================================================================

begin;

-- ---------------------------------------------------------------------------
-- BG. Retirar la version de 8 parametros
-- ---------------------------------------------------------------------------

do $bg$
declare
  v_nueve regprocedure := to_regprocedure(
    'public.register_tenant(text, text, text, text, text, integer, integer, text, text)');
  v_ocho regprocedure := to_regprocedure(
    'public.register_tenant(text, text, text, text, text, integer, integer, text)');
begin
  -- La que usa la app TIENE que existir antes de quitar la otra: si no, se
  -- dejaria el registro sin ninguna puerta.
  if v_nueve is null then
    raise exception 'PARADA: no existe register_tenant de 9 parametros. No se quita la de 8: el registro se quedaria sin ninguna.';
  end if;

  if v_ocho is null then
    raise notice 'BG: la version de 8 parametros ya no existia. Nada que quitar.';
  else
    drop function public.register_tenant(text, text, text, text, text, integer, integer, text);
    raise notice 'BG: retirada la version de 8 parametros, la que buscaba el plan profesional.';
  end if;

  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'register_tenant') <> 1 then
    raise exception 'FALLO BG: despues de retirar la vieja no queda exactamente UNA register_tenant.';
  end if;
end
$bg$;

-- ---------------------------------------------------------------------------
-- BH. El permiso por defecto, fuera de `private`
-- ---------------------------------------------------------------------------

do $bh$
declare
  v_firma text;
  v_hechas integer := 0;
begin
  foreach v_firma in array array[
    'private.beautyos_assign_sale_number_on_close()',
    'private.beautyos_assign_ticket_number()',
    'private.beautyos_celular_normalizado(text)',
    'private.beautyos_celular_valido(text)',
    'private.beautyos_crear_suscripcion_de_sede()',
    'private.beautyos_freeze_ticket_number()',
    'private.beautyos_precio_efectivo(uuid)',
    'private.beautyos_protect_immutable_sale_number()',
    'private.beautyos_require_limit(uuid, text, integer, text)'
  ]
  loop
    if to_regprocedure(v_firma) is null then
      raise notice 'BH: % no existe con esa firma; se salta.', v_firma;
      continue;
    end if;

    execute format('revoke execute on function %s from public, anon', v_firma);
    execute format('grant execute on function %s to authenticated, service_role', v_firma);
    v_hechas := v_hechas + 1;
  end loop;

  raise notice 'BH: % de 9 funciones de private sin permiso para anon.', v_hechas;
end
$bh$;

-- PostgREST guarda la lista de funciones: que se entere de que hay una menos.
notify pgrst, 'reload schema';

commit;
