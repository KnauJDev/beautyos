-- D-164: slugs únicos por negocio, resolución pública sin sesión, y gestión
-- de enlace en Configuración (Fase 5, Bloque 1, pasos 5.1 a 5.4).
--
-- POR QUE ESTE ARCHIVO
--
-- El slug es la puerta de entrada pública de cada negocio
-- (`salonymas.com/<slug>`) y además queda protegido con una lista de
-- palabras reservadas del propio sistema (login, admin, api...). Un fallo
-- aquí es silencioso hasta que alguien intenta entrar a su enlace o dos
-- negocios chocan de slug.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\184_test_slugs_publicos.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila, ni siquiera el tenant de prueba
-- que crea para el caso de colisión.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_other_tenant uuid;
  v_slug text;
  v_disponible boolean;
  v_capturo boolean;
  v_sin_slug integer;
  v_duplicados integer;
  v_fallos integer := 0;
  v_error text;
begin
  select t.id into v_tenant
  from public.tenants t
  where t.active
  order by t.created_at
  limit 1;

  select b.id into v_branch
  from public.branches b
  where b.tenant_id = v_tenant and b.active
  order by b.is_primary desc
  limit 1;

  select tm.user_id into v_owner
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  select tm.user_id into v_stylist_user
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'stylist'
    and tm.active
  limit 1;

  if v_tenant is null or v_branch is null or v_owner is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- CASO 1: private.beautyos_slugify -- acentos, eñe y separadores.
  -- =====================================================================
  if private.beautyos_slugify('Barbería Élite') = 'barberia-elite' then
    raise notice 'OK  1a  "Barbería Élite" -> "barberia-elite"';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1a  se esperaba "barberia-elite"; llego "%"',
      private.beautyos_slugify('Barbería Élite');
  end if;

  if private.beautyos_slugify('Naguara de Uñas') = 'naguara-de-unas' then
    raise notice 'OK  1b  "Naguara de Uñas" -> "naguara-de-unas" (sin eñe, con guiones entre palabras)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1b  se esperaba "naguara-de-unas"; llego "%"',
      private.beautyos_slugify('Naguara de Uñas');
  end if;

  if private.beautyos_slugify('   ') is null then
    raise notice 'OK  1c  un nombre sin nada aprovechable (solo espacios) da null, no explota';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1c  se esperaba null; llego "%"', private.beautyos_slugify('   ');
  end if;

  -- =====================================================================
  -- CASO 2: private.beautyos_generate_unique_tenant_slug -- colisión y
  -- palabra reservada. Se usa un tenant de prueba dedicado (no un tenant
  -- real) para no depender de si el nombre real ya colisionó con otro al
  -- correr el backfill.
  -- =====================================================================
  insert into public.tenants (name, slug, active)
  values ('Test Colision D164', 'test-colision-d164', true);

  if private.beautyos_generate_unique_tenant_slug('Test Colision D164') = 'test-colision-d164-2' then
    raise notice 'OK  2a  un nombre cuyo slug base ya existe genera "<base>-2"';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2a  se esperaba "test-colision-d164-2"; llego "%"',
      private.beautyos_generate_unique_tenant_slug('Test Colision D164');
  end if;

  delete from public.tenants where slug = 'test-colision-d164';

  if private.beautyos_generate_unique_tenant_slug('Admin') like 'admin-salon%' then
    raise notice 'OK  2b  un nombre que coincide con una palabra reservada ("admin") se ajusta solo';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2b  se esperaba "admin-salon..."; llego "%"',
      private.beautyos_generate_unique_tenant_slug('Admin');
  end if;

  -- =====================================================================
  -- CASO 3: el backfill dejó a todos los tenants existentes con un slug
  -- válido y único.
  -- =====================================================================
  select count(*) into v_sin_slug from public.tenants where slug is null;

  if v_sin_slug = 0 then
    raise notice 'OK  3a  ningun tenant existente quedo sin slug tras el backfill';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3a  % tenant(s) quedaron sin slug', v_sin_slug;
  end if;

  select count(*) into v_duplicados
  from (
    select slug from public.tenants where slug is not null
    group by slug having count(*) > 1
  ) d;

  if v_duplicados = 0 then
    raise notice 'OK  3b  no hay slugs duplicados entre tenants';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3b  hay % slug(s) duplicados', v_duplicados;
  end if;

  -- =====================================================================
  -- CASO 4: check_slug_availability -- formato, reservado y disponibilidad.
  -- =====================================================================
  select slug into v_slug from public.tenants where id = v_tenant;

  select public.check_slug_availability(v_slug) into v_disponible;
  if v_disponible = false then
    raise notice 'OK  4a  el slug que ya usa un tenant real no aparece disponible';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4a  un slug ya tomado aparecio disponible';
  end if;

  select public.check_slug_availability('admin') into v_disponible;
  if v_disponible = false then
    raise notice 'OK  4b  una palabra reservada ("admin") no esta disponible';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4b  "admin" aparecio disponible';
  end if;

  select public.check_slug_availability('AB') into v_disponible;
  if v_disponible = false then
    raise notice 'OK  4c  un slug de menos de 3 caracteres no es valido';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4c  "AB" aparecio disponible';
  end if;

  select public.check_slug_availability('un-slug-libre-de-verdad-' || substr(gen_random_uuid()::text, 1, 8)) into v_disponible;
  if v_disponible = true then
    raise notice 'OK  4d  un slug nuevo, bien formado y sin dueño aparece disponible';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4d  un slug libre aparecio como no disponible';
  end if;

  -- =====================================================================
  -- CASO 5: update_tenant_slug -- exito, reservado, y choque con otro
  -- tenant real (se crea uno de prueba, se borra solo al hacer ROLLBACK).
  -- =====================================================================
  insert into public.tenants (name, slug, active)
  values ('Negocio de prueba D-164', 'negocio-de-prueba-d164', true)
  returning id into v_other_tenant;

  begin
    perform public.update_tenant_slug('negocio-de-prueba-d164');
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5a  se pudo tomar el slug de otro negocio real';
  exception
    when others then
      raise notice 'OK  5a  no se puede tomar el slug de otro negocio ya existente';
  end;

  begin
    perform public.update_tenant_slug('login');
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5b  se acepto una palabra reservada como slug propio';
  exception
    when others then
      raise notice 'OK  5b  una palabra reservada ("login") se rechaza como slug propio';
  end;

  select public.update_tenant_slug('mi-salon-nuevo-d164') into v_slug;
  if v_slug = 'mi-salon-nuevo-d164' then
    raise notice 'OK  5c  un slug disponible y bien formado se guarda correctamente';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5c  se esperaba "mi-salon-nuevo-d164"; llego "%"', v_slug;
  end if;

  if exists (select 1 from public.tenants where id = v_tenant and slug = 'mi-salon-nuevo-d164') then
    raise notice 'OK  5d  el cambio de slug quedo reflejado en la fila del tenant';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5d  la fila del tenant no refleja el slug nuevo';
  end if;

  -- Un estilista no puede cambiar el enlace del negocio.
  if v_stylist_user is null then
    raise notice 'SALTADA 5e: el negocio no tiene estilista con cuenta.';
  else
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    v_capturo := false;
    begin
      perform public.update_tenant_slug('lo-que-sea');
    exception
      when others then
        v_capturo := true;
    end;

    if v_capturo then
      raise notice 'OK  5e  un estilista no puede cambiar el enlace del negocio';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 5e  un estilista pudo cambiar el enlace del negocio';
    end if;

    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
      true
    );
  end if;

  -- =====================================================================
  -- CASO 6: get_public_salon_by_slug -- sin sesion, datos de vitrina.
  -- =====================================================================
  if exists (
    select 1
    from public.get_public_salon_by_slug('mi-salon-nuevo-d164')
    where tenant_id = v_tenant
  ) then
    raise notice 'OK  6a  la funcion publica resuelve el tenant correcto por su slug';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6a  la funcion publica no encontro el tenant por su slug nuevo';
  end if;

  if not exists (
    select 1 from public.get_public_salon_by_slug('este-slug-no-existe-jamas-d164')
  ) then
    raise notice 'OK  6b  un slug que no existe devuelve cero filas, no un error';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6b  un slug inexistente devolvio filas';
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DE SLUGS PUBLICOS PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
    raise notice 'Si es la primera vez que se corre, puede ser el guion y no';
    raise notice 'la aplicacion. Pasale este mensaje al asistente.';
end;
$$;

rollback;
