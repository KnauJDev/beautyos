-- ============================================================================
-- MIGRACION: 20260917140000_borrar_un_negocio_de_prueba_d246.sql
-- DESCRIPCION: Borrar un negocio de prueba, y solo de prueba (D-246, paso 9.47).
--
-- POR QUE EXISTE
--
-- El propietario, antes de invitar a los diez socios de disenyo: *"puedo crear
-- mas tenant de prueba, pero al final no quiero ver una APP llena de clientes
-- ficticios; hay alguna forma de limpiar la base?"*.
--
-- EL SEGURO, QUE ES LO PRIMERO
--
-- La funcion **se niega si el negocio no esta marcado como demo**
-- (`is_demo = true`, D-225). No es una comprobacion de cortesia: es lo que
-- hace imposible borrar un cliente real por equivocarse de boton. Un borrado
-- no se deshace, y el `ROLLBACK` de una transaccion no ayuda a quien pulso
-- bien el boton sobre la fila equivocada.
--
-- POR QUE DESCUBRE LAS TABLAS EN VEZ DE LLEVAR UNA LISTA
--
-- Al disenyar esto se busco la lista de tablas en las migraciones y salieron
-- **25**. Faltaban `tenants`, `clients`, `tickets` y `work_photos`: nacieron
-- antes de que el proyecto usara migraciones, asi que **el repositorio no
-- contiene el esquema completo**.
--
-- Una lista escrita a mano se habria dejado fuera justo las tablas con mas
-- datos, y el negocio habria quedado "borrado" con sus 703 tickets dentro.
-- Por eso las tablas se leen de `information_schema`: **la base es la unica
-- que sabe la verdad sobre si misma**, y ademas asi no envejece cuando se
-- anyada una tabla nueva.
--
-- EL ORDEN, SIN CALCULARLO
--
-- Nueve claves foraneas son `on delete restrict`, asi que el orden importa.
-- En vez de resolver el grafo de dependencias, se borra **a pasadas**: lo que
-- falla por depender de otra cosa se reintenta en la vuelta siguiente. Si una
-- pasada entera no consigue borrar nada y todavia quedan filas, se detiene y
-- lo dice.
--
-- Y AL FINAL SE COMPRUEBA
--
-- Tras borrar, se recorre otra vez cada tabla con `tenant_id` y se exige que
-- **no quede ni una fila**. Un borrado a medias es peor que ninguno: deja
-- basura invisible que nadie vuelve a mirar. Si queda algo, la funcion lanza
-- y **la transaccion entera se deshace**.
--
-- LO QUE NO BORRA, A PROPOSITO
--
-- * **Las cuentas de `auth.users`.** No son del negocio, son de las personas.
--   Y dejarlas permite que esa misma persona vuelva a registrarse para otra
--   prueba, porque `register_tenant` solo bloquea a quien ya tiene membresia.
-- * **Los archivos de Storage.** Las filas de fotos se van; los archivos
--   viven fuera de la base y se limpian con `respaldo_archivos.ps1`. Queda
--   dicho aqui para que nadie crea que se fueron.
--
-- LA TRAZA, QUE PIDE `AGENTS.md`
--
-- *"No alterar el historial financiero, pagos, comisiones o reservas sin
-- trazabilidad."* Estos negocios llevan pagos de ePayco **reales**
-- (`EPAYCO_TEST_MODE = false`), asi que antes de borrar se guarda un resumen
-- --nombre, cuando, quien, cuantas filas por tabla y cuanto dinero-- en
-- `public.deleted_demo_tenants`. Esa tabla es la trazabilidad.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. El rastro de lo borrado
-- ----------------------------------------------------------------------------

create table if not exists public.deleted_demo_tenants (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  tenant_name text not null,
  contact_email text,
  deleted_at timestamptz not null default now(),
  deleted_by uuid references auth.users(id) on delete set null,
  filas_por_tabla jsonb not null default '{}'::jsonb,
  pagos_registrados integer not null default 0,
  dinero_cop bigint not null default 0
);

comment on table public.deleted_demo_tenants is
  'Rastro de los negocios de PRUEBA borrados con platform_delete_demo_tenant '
  '(D-246). Existe porque AGENTS.md prohibe alterar historial financiero sin '
  'trazabilidad, y estos negocios llevaban pagos de ePayco reales. '
  'Se conserva aunque el negocio ya no exista: es lo unico que queda. '
  'NO ELIMINAR.';

alter table public.deleted_demo_tenants enable row level security;

revoke all on table public.deleted_demo_tenants from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. El borrado
-- ----------------------------------------------------------------------------

create or replace function public.platform_delete_demo_tenant(
  p_tenant_id uuid
)
returns table (
  tabla text,
  filas_borradas bigint
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_nombre    text;
  v_correo    text;
  v_es_demo   boolean;
  v_tablas    text[];
  v_pendiente text[];
  v_siguiente text[];
  v_t         text;
  v_borradas  bigint;
  v_progreso  boolean;
  v_vueltas   integer := 0;
  v_conteo    jsonb := '{}'::jsonb;
  v_pagos     integer := 0;
  v_dinero    bigint := 0;
  v_restantes bigint;
  v_sobran    text := '';
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  -- EL SEGURO. Se mira el negocio y se exige que este marcado como prueba.
  select t.name, t.contact_email, coalesce(t.is_demo, false)
    into v_nombre, v_correo, v_es_demo
  from public.tenants t
  where t.id = p_tenant_id;

  if v_nombre is null then
    raise exception 'No existe el negocio %.', p_tenant_id;
  end if;

  if not v_es_demo then
    raise exception 'El negocio "%" NO esta marcado como de prueba, asi que no se borra. Esta funcion solo toca negocios con is_demo = true (D-225, D-246). Si de verdad quieres borrarlo, marcalo primero como prueba y piensatelo dos veces: un borrado no se deshace.', v_nombre;
  end if;

  -- Las tablas, leidas de la base y no de una lista escrita a mano: el
  -- repositorio no contiene el esquema completo (ver la cabecera).
  select array_agg(c.table_name::text order by c.table_name)
    into v_tablas
  from information_schema.columns c
  join information_schema.tables t
    on t.table_schema = c.table_schema
   and t.table_name = c.table_name
   and t.table_type = 'BASE TABLE'
  where c.table_schema = 'public'
    and c.column_name = 'tenant_id'
    and c.table_name <> 'deleted_demo_tenants';

  if v_tablas is null then
    raise exception 'No se encontro ninguna tabla con tenant_id. Algo va muy mal.';
  end if;

  -- El dinero, ANTES de borrarlo, para el rastro.
  begin
    execute 'select count(*)::integer, coalesce(sum(amount_cop), 0)::bigint
             from public.subscription_payment_intents where tenant_id = $1'
      into v_pagos, v_dinero using p_tenant_id;
  exception when others then
    v_pagos := 0;
    v_dinero := 0;
  end;

  -- A pasadas: lo que falla por depender de otra cosa se reintenta.
  v_pendiente := v_tablas;

  while array_length(v_pendiente, 1) > 0 and v_vueltas < 40 loop
    v_vueltas := v_vueltas + 1;
    v_progreso := false;
    v_siguiente := array[]::text[];

    foreach v_t in array v_pendiente loop
      begin
        execute format('delete from public.%I where tenant_id = $1', v_t)
          using p_tenant_id;
        get diagnostics v_borradas = row_count;

        v_conteo := v_conteo || jsonb_build_object(
          v_t,
          coalesce((v_conteo ->> v_t)::bigint, 0) + v_borradas
        );
        v_progreso := true;
      exception when foreign_key_violation then
        -- Todavia hay algo colgando de esta tabla. Vuelve a la cola.
        v_siguiente := v_siguiente || v_t;
      end;
    end loop;

    if not v_progreso and array_length(v_siguiente, 1) > 0 then
      raise exception 'Una vuelta entera sin poder borrar nada, y quedan % tablas: %. Hay una dependencia que este metodo no resuelve; no se borra nada.',
        array_length(v_siguiente, 1), array_to_string(v_siguiente, ', ');
    end if;

    v_pendiente := v_siguiente;
  end loop;

  if array_length(v_pendiente, 1) > 0 then
    raise exception 'Se agotaron las vueltas y quedan tablas sin borrar: %.',
      array_to_string(v_pendiente, ', ');
  end if;

  -- El negocio, al final.
  delete from public.tenants where id = p_tenant_id;

  -- Y SE COMPRUEBA. Un borrado a medias deja basura que nadie vuelve a mirar.
  foreach v_t in array v_tablas loop
    execute format('select count(*) from public.%I where tenant_id = $1', v_t)
      into v_restantes using p_tenant_id;
    if v_restantes > 0 then
      v_sobran := v_sobran || v_t || ' (' || v_restantes || ') ';
    end if;
  end loop;

  if v_sobran <> '' then
    raise exception 'El borrado quedo a medias y sobran filas en: %. Se deshace todo: media limpieza es peor que ninguna.', v_sobran;
  end if;

  if exists (select 1 from public.tenants where id = p_tenant_id) then
    raise exception 'El negocio sigue existiendo despues de borrarlo. Se deshace todo.';
  end if;

  -- El rastro (AGENTS.md). Va al final a proposito: si algo de arriba fallo,
  -- la transaccion se deshace y no queda una nota de un borrado que no paso.
  insert into public.deleted_demo_tenants (
    tenant_id, tenant_name, contact_email, deleted_by,
    filas_por_tabla, pagos_registrados, dinero_cop
  ) values (
    p_tenant_id, v_nombre, v_correo, auth.uid(),
    v_conteo, v_pagos, v_dinero
  );

  -- Lo que se borro, para poder ensenyarlo.
  return query
  select k.key::text, (k.value #>> '{}')::bigint
  from jsonb_each(v_conteo) k
  where (k.value #>> '{}')::bigint > 0
  order by (k.value #>> '{}')::bigint desc;
end;
$$;

revoke all on function public.platform_delete_demo_tenant(uuid) from public, anon;
grant execute on function public.platform_delete_demo_tenant(uuid) to authenticated;

comment on function public.platform_delete_demo_tenant(uuid) is
  'Borra un negocio de PRUEBA y todo lo suyo (D-246). **Se niega si is_demo '
  'no es true**: ese seguro es lo que impide borrar un cliente real por '
  'equivocarse de boton. Descubre las tablas en information_schema porque el '
  'repositorio no tiene el esquema completo, borra a pasadas para no calcular '
  'el orden de las claves foraneas, y **verifica al final que no quede ni una '
  'fila** -- si queda, deshace todo. Deja rastro en deleted_demo_tenants. '
  'NO borra cuentas de auth.users ni archivos de Storage. NO ELIMINAR.';

commit;
