-- D-171: paso 6.6, "Blog de artículos de belleza y estética" (por cada
-- salón, sin url propia por artículo en esta versión).
--
-- POR QUE ESTE ARCHIVO
--
-- Es contenido público bajo el nombre del negocio, igual riesgo de
-- aislamiento que las reseñas (D-170): un fallo aquí podría dejar un
-- artículo en borrador visible al público, o un artículo de un tenant
-- filtrándose en la página de otro.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\190_test_blog_de_articulos.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $$
declare
  v_tenant uuid;
  v_otro_tenant uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_post_publicado uuid;
  v_post_borrador uuid;
  v_capturo boolean;
  v_error_msg text;
  v_resultado record;
  v_count integer;
  v_fallos integer := 0;
  v_error text;
begin
  select t.id into v_tenant
  from public.tenants t
  where t.active
  order by t.created_at
  limit 1;

  select t.id into v_otro_tenant
  from public.tenants t
  where t.active and t.id <> v_tenant
  order by t.created_at
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

  if v_tenant is null or v_owner is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- CASO 1: crear un artículo publicado y uno en borrador.
  -- =====================================================================
  v_post_publicado := public.create_blog_post(
    'Cuidados después de una manicure',
    'Primer párrafo con consejos reales.',
    null,
    true
  );

  v_post_borrador := public.create_blog_post(
    'Borrador sin terminar',
    'Todavía en construcción.',
    null,
    false
  );

  if v_post_publicado is not null and v_post_borrador is not null then
    raise notice 'OK  1  los dos artículos se crean correctamente';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  create_blog_post no devolvió un id válido';
  end if;

  -- =====================================================================
  -- CASO 2: título o contenido vacío se rechaza.
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.create_blog_post('   ', 'Contenido válido');
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%título no puede estar vacío%' then
    raise notice 'OK  2  un título vacío se rechaza con el mensaje esperado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- =====================================================================
  -- CASO 3: get_blog_posts_summary del dueño ve AMBOS (publicado y
  -- borrador).
  -- =====================================================================
  select count(*) into v_count
  from public.get_blog_posts_summary()
  where id in (v_post_publicado, v_post_borrador);

  if v_count = 2 then
    raise notice 'OK  3  el panel del salón ve el artículo publicado y el borrador';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  se esperaban 2 filas, llegaron %', v_count;
  end if;

  -- =====================================================================
  -- CASO 4: get_public_salon_blog_posts solo trae el PUBLICADO.
  -- =====================================================================
  if exists (
    select 1 from public.get_public_salon_blog_posts(v_tenant) where id = v_post_publicado
  ) and not exists (
    select 1 from public.get_public_salon_blog_posts(v_tenant) where id = v_post_borrador
  ) then
    raise notice 'OK  4  la página pública solo muestra el artículo publicado, no el borrador';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  la lista pública no filtró correctamente por publicado';
  end if;

  -- =====================================================================
  -- CASO 5: un artículo de otro tenant no aparece en la lista pública de
  -- este.
  -- =====================================================================
  if v_otro_tenant is not null then
    if not exists (
      select 1 from public.get_public_salon_blog_posts(v_tenant)
      where id not in (v_post_publicado, v_post_borrador)
    ) then
      raise notice 'OK  5  la lista pública no trae artículos de otros negocios';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 5  aparecieron artículos que no son de este tenant';
    end if;
  else
    raise notice 'AVISO 5  no hay un segundo tenant activo; caso omitido';
  end if;

  -- =====================================================================
  -- CASO 6: editar un artículo propio funciona.
  -- =====================================================================
  perform public.update_blog_post(
    v_post_borrador,
    'Borrador ahora terminado',
    'Contenido final, listo para publicar.',
    null,
    true
  );

  select * into v_resultado
  from public.get_blog_posts_summary()
  where id = v_post_borrador;

  if v_resultado.title = 'Borrador ahora terminado' and v_resultado.published = true then
    raise notice 'OK  6  editar un artículo propio actualiza título, contenido y estado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  title="%", published=%', v_resultado.title, v_resultado.published;
  end if;

  -- =====================================================================
  -- CASO 7: borrar un artículo propio funciona; borrarlo de nuevo se
  -- rechaza como "no existe".
  -- =====================================================================
  perform public.delete_blog_post(v_post_borrador);

  if not exists (select 1 from public.get_blog_posts_summary() where id = v_post_borrador) then
    raise notice 'OK  7a  borrar un artículo propio lo quita de la lista';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7a  el artículo borrado sigue apareciendo';
  end if;

  v_capturo := false;
  begin
    perform public.delete_blog_post(v_post_borrador);
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%no existe o no pertenece a tu negocio%' then
    raise notice 'OK  7b  borrar dos veces el mismo artículo se rechaza con el mensaje esperado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7b  capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- =====================================================================
  -- CASO 8: un estilista no puede escribir en el blog (solo owner/admin).
  -- =====================================================================
  if v_stylist_user is not null then
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    v_capturo := false;
    begin
      perform public.create_blog_post('Intento no autorizado', 'Contenido');
    exception
      when others then
        v_capturo := true;
    end;

    if v_capturo then
      raise notice 'OK  8  un estilista no puede escribir en el blog';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 8  un estilista pudo crear un artículo';
    end if;

    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
      true
    );
  else
    raise notice 'AVISO 8  no hay un estilista activo en este tenant; caso omitido';
  end if;

  -- =====================================================================
  -- Limpieza del artículo publicado que sigue en pie (el borrador ya se
  -- borró en el Caso 7). El ROLLBACK final igual lo cubre, pero se borra
  -- explícito para que el propio control quede prolijo si algún día se
  -- corre fuera de una transacción de prueba.
  -- =====================================================================
  perform public.delete_blog_post(v_post_publicado);

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL BLOG DE ARTÍCULOS PASARON ===';
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
