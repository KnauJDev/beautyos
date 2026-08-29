-- D-169: paso 6.2, "Estudio de publicacion" (version determinista).
--
-- POR QUE ESTE ARCHIVO
--
-- get_publication_studio_data reutiliza el mismo candado legal que el
-- portafolio publico (D-167: sin aprobacion + consentimiento, no se puede
-- usar la foto) y agrega dos datos que hoy no viajan juntos a ningun lado
-- (nombre del servicio del ticket, reseña de buena calificacion del mismo
-- ticket). Un fallo aqui es exponer una foto que no deberia ser publica, o
-- una reseña que no cumple el filtro de calidad/visibilidad.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\188_test_estudio_de_publicacion.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_service_a uuid;
  v_service_b uuid;
  v_stylist uuid;
  v_client uuid;
  v_ticket_con_resena uuid;
  v_ticket_sin_resena uuid;
  v_ticket_resena_baja uuid;
  v_photo_completa uuid;
  v_photo_sin_resena uuid;
  v_photo_resena_baja uuid;
  v_photo_no_aprobada uuid;
  v_resultado record;
  v_capturo boolean;
  v_error_msg text;
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
  where b.tenant_id = v_tenant and b.active and b.is_primary
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

  select bs.service_id into v_service_a
  from public.branch_services bs
  where bs.tenant_id = v_tenant and bs.branch_id = v_branch and bs.active
  order by bs.service_id
  limit 1;

  select bs.service_id into v_service_b
  from public.branch_services bs
  where bs.tenant_id = v_tenant and bs.branch_id = v_branch and bs.active
    and bs.service_id <> v_service_a
  order by bs.service_id
  limit 1;

  select st.id into v_stylist
  from public.stylists st
  where st.tenant_id = v_tenant and st.active
  limit 1;

  if v_tenant is null or v_branch is null or v_owner is null or v_service_a is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- Fixture: una clienta con tres tickets pasados en tres situaciones.
  -- =====================================================================
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Estudio D169', '300 000 0299', true)
  returning id into v_client;

  -- Ticket con reseña de 5 estrellas y (si hay dos servicios activos) dos
  -- servicios, para probar el string_agg.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '5 days')
  returning id into v_ticket_con_resena;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_con_resena, v_service_a, v_stylist, 50000, 45, 'finalizado');

  if v_service_b is not null then
    insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
    values (v_tenant, v_branch, v_ticket_con_resena, v_service_b, v_stylist, 30000, 30, 'finalizado');
  end if;

  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket_con_resena, v_client, 5, 'Quedé feliz con el resultado', 'approved', true, true);

  -- Ticket sin ninguna reseña.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '8 days')
  returning id into v_ticket_sin_resena;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_sin_resena, v_service_a, v_stylist, 50000, 45, 'finalizado');

  -- Ticket con reseña de 3 estrellas: no cumple el filtro de calidad.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '12 days')
  returning id into v_ticket_resena_baja;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_resena_baja, v_service_a, v_stylist, 50000, 45, 'finalizado');

  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket_resena_baja, v_client, 3, 'Estuvo bien', 'approved', true, true);

  -- Fotos: una completa (aprobada+consentimiento) por cada ticket, y una
  -- cuarta que se queda sin aprobar.
  v_photo_completa := public.create_work_photo(
    v_branch, v_ticket_con_resena, v_branch::text || '/estudio-completa.jpg',
    'final', 'Resultado final', v_stylist, true
  );
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_photo_completa, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/estudio-completa.jpg'
  );

  v_photo_sin_resena := public.create_work_photo(
    v_branch, v_ticket_sin_resena, v_branch::text || '/estudio-sin-resena.jpg',
    'final', 'Sin reseña todavía', v_stylist, true
  );
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_photo_sin_resena, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/estudio-sin-resena.jpg'
  );

  v_photo_resena_baja := public.create_work_photo(
    v_branch, v_ticket_resena_baja, v_branch::text || '/estudio-resena-baja.jpg',
    'final', 'Reseña de 3 estrellas', v_stylist, true
  );
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_photo_resena_baja, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/estudio-resena-baja.jpg'
  );

  -- Foto sin aprobar para portafolio (consentimiento sí, aprobación no).
  v_photo_no_aprobada := public.create_work_photo(
    v_branch, v_ticket_sin_resena, v_branch::text || '/estudio-no-aprobada.jpg',
    'before', 'Antes', v_stylist, true
  );

  -- =====================================================================
  -- CASO 1: foto completa trae servicio(s) y la reseña de 5 estrellas.
  -- =====================================================================
  select * into v_resultado
  from public.get_publication_studio_data(v_branch, v_photo_completa);

  if v_resultado.photo_url is not null
     and v_resultado.service_names like '%' || (select name from public.services where id = v_service_a) || '%'
     and v_resultado.review_rating = 5
     and v_resultado.review_comment = 'Quedé feliz con el resultado'
     and v_resultado.review_client_name = 'Clienta Estudio D169'
  then
    raise notice 'OK  1  foto completa trae photo_url, servicio(s) y la reseña de 5 estrellas';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  datos incompletos: photo_url=%, service_names=%, rating=%, comment=%, client=%',
      v_resultado.photo_url, v_resultado.service_names, v_resultado.review_rating,
      v_resultado.review_comment, v_resultado.review_client_name;
  end if;

  -- =====================================================================
  -- CASO 2: ticket sin reseña -- los tres campos de reseña quedan null,
  -- el servicio sigue llegando.
  -- =====================================================================
  select * into v_resultado
  from public.get_publication_studio_data(v_branch, v_photo_sin_resena);

  if v_resultado.service_names is not null
     and v_resultado.review_rating is null
     and v_resultado.review_comment is null
  then
    raise notice 'OK  2  sin reseña, los tres campos de reseña quedan en null';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  se esperaba review_rating/comment en null: rating=%, comment=%, service_names=%',
      v_resultado.review_rating, v_resultado.review_comment, v_resultado.service_names;
  end if;

  -- =====================================================================
  -- CASO 3: reseña de 3 estrellas no cumple el filtro de calidad (>= 4).
  -- =====================================================================
  select * into v_resultado
  from public.get_publication_studio_data(v_branch, v_photo_resena_baja);

  if v_resultado.review_rating is null then
    raise notice 'OK  3  una reseña de 3 estrellas no se ofrece para la publicación';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  se esperaba que la reseña de 3 estrellas quedara excluida: rating=%',
      v_resultado.review_rating;
  end if;

  -- =====================================================================
  -- CASO 4: una foto sin aprobar para portafolio se rechaza -- mismo
  -- candado legal del portafolio publico (D-167).
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.get_publication_studio_data(v_branch, v_photo_no_aprobada);
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%no esta aprobada para portafolio%' then
    raise notice 'OK  4  una foto sin aprobar para portafolio se rechaza con el mensaje esperado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  se esperaba el rechazo del candado legal; capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- =====================================================================
  -- CASO 5: una foto inexistente (uuid al azar) se rechaza como "no
  -- existe", no como un error interno.
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.get_publication_studio_data(v_branch, gen_random_uuid());
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%no existe o no pertenece a esta sede%' then
    raise notice 'OK  5  una foto inexistente se rechaza con el mensaje esperado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  se esperaba el rechazo de "no existe"; capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- =====================================================================
  -- CASO 6: un estilista no puede llamar esta función (solo owner/admin,
  -- mismo criterio que la galería interna).
  -- =====================================================================
  if v_stylist_user is not null then
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    v_capturo := false;
    begin
      perform public.get_publication_studio_data(v_branch, v_photo_completa);
    exception
      when others then
        v_capturo := true;
    end;

    if v_capturo then
      raise notice 'OK  6  un estilista no puede usar el Estudio de publicación';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 6  un estilista pudo usar el Estudio de publicación';
    end if;

    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
      true
    );
  else
    raise notice 'AVISO 6  no hay un estilista activo en este tenant; caso omitido';
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL ESTUDIO DE PUBLICACION PASARON ===';
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
