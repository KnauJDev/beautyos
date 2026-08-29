-- D-170: paso 6.3, "Respuestas a reseñas asistidas" (version determinista).
--
-- POR QUE ESTE ARCHIVO
--
-- set_review_reply escribe texto publico bajo el nombre del salon en su
-- propia pagina -- un fallo de aislamiento entre tenants ahi seria un
-- negocio hablando en la pagina de otro. Y la respuesta debe seguir la
-- misma regla de visibilidad que ya tiene la reseña (D-165): una reseña
-- privada no debe filtrar su respuesta en publico tampoco.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\189_test_respuestas_a_resenas.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_service uuid;
  v_stylist uuid;
  v_client uuid;
  v_ticket_publica uuid;
  v_ticket_privada uuid;
  v_review_publica uuid;
  v_review_privada uuid;
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

  select bs.service_id into v_service
  from public.branch_services bs
  where bs.tenant_id = v_tenant and bs.branch_id = v_branch and bs.active
  limit 1;

  select st.id into v_stylist
  from public.stylists st
  where st.tenant_id = v_tenant and st.active
  limit 1;

  if v_tenant is null or v_branch is null or v_owner is null or v_service is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- Fixture: una clienta con dos tickets pasados, cada uno con su reseña
  -- (una publica y otra privada).
  -- =====================================================================
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Resenas D170', '300 000 0399', true)
  returning id into v_client;

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '4 days')
  returning id into v_ticket_publica;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_publica, v_service, v_stylist, 50000, 45, 'finalizado');

  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, stylist_id, service_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket_publica, v_client, v_stylist, v_service, 5, 'Excelente trabajo', 'approved', true, true)
  returning id into v_review_publica;

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '6 days')
  returning id into v_ticket_privada;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_privada, v_service, v_stylist, 50000, 45, 'finalizado');

  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, stylist_id, service_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket_privada, v_client, v_stylist, v_service, 2, 'No me gustó', 'approved', false, true)
  returning id into v_review_privada;

  -- =====================================================================
  -- CASO 1: guardar una respuesta y verla en get_reviews_summary_v2.
  -- =====================================================================
  perform public.set_review_reply(v_branch, v_review_publica, '  Gracias por tu comentario, Clienta  ');

  select * into v_resultado
  from public.get_reviews_summary_v2(v_branch)
  where id = v_review_publica;

  if v_resultado.business_reply = 'Gracias por tu comentario, Clienta'
     and v_resultado.business_reply_at is not null
  then
    raise notice 'OK  1  la respuesta se guarda recortada de espacios y con fecha';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  reply="%", reply_at=%', v_resultado.business_reply, v_resultado.business_reply_at;
  end if;

  -- =====================================================================
  -- CASO 2: la respuesta de una reseña PUBLICA aparece en
  -- get_public_salon_reviews.
  -- =====================================================================
  if exists (
    select 1 from public.get_public_salon_reviews(v_tenant)
    where rating = 5 and business_reply = 'Gracias por tu comentario, Clienta'
  ) then
    raise notice 'OK  2  la respuesta de una reseña publica se ve en la pagina publica';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  la respuesta publica no aparecio en get_public_salon_reviews';
  end if;

  -- =====================================================================
  -- CASO 3: una reseña PRIVADA no filtra su respuesta en publico -- de
  -- hecho no debe aparecer ni la reseña (D-165 ya filtra por
  -- visible_to_public, esto solo confirma que sumar business_reply no
  -- abrio una grieta nueva).
  -- =====================================================================
  perform public.set_review_reply(v_branch, v_review_privada, 'Lamentamos tu experiencia, escríbenos');

  if not exists (
    select 1 from public.get_public_salon_reviews(v_tenant)
    where business_reply = 'Lamentamos tu experiencia, escríbenos'
  ) then
    raise notice 'OK  3  la respuesta de una reseña privada no se filtra en publico';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  la respuesta de una reseña privada SI aparecio en publico';
  end if;

  -- =====================================================================
  -- CASO 4: texto vacío quita la respuesta (limpia reply y reply_at).
  -- =====================================================================
  perform public.set_review_reply(v_branch, v_review_publica, '   ');

  select * into v_resultado
  from public.get_reviews_summary_v2(v_branch)
  where id = v_review_publica;

  if v_resultado.business_reply is null and v_resultado.business_reply_at is null then
    raise notice 'OK  4  un texto vacío quita la respuesta por completo';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  se esperaba reply/reply_at en null: reply="%", reply_at=%', v_resultado.business_reply, v_resultado.business_reply_at;
  end if;

  -- =====================================================================
  -- CASO 5: una reseña inexistente (uuid al azar) se rechaza.
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.set_review_reply(v_branch, gen_random_uuid(), 'Hola');
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%no existe o no pertenece a esta sede%' then
    raise notice 'OK  5  una reseña inexistente se rechaza con el mensaje esperado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- =====================================================================
  -- CASO 6: un estilista no puede responder reseñas (solo owner/admin).
  -- =====================================================================
  if v_stylist_user is not null then
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    v_capturo := false;
    begin
      perform public.set_review_reply(v_branch, v_review_publica, 'Intento no autorizado');
    exception
      when others then
        v_capturo := true;
    end;

    if v_capturo then
      raise notice 'OK  6  un estilista no puede responder reseñas';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 6  un estilista pudo responder una reseña';
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
    raise notice '=== TODAS LAS PRUEBAS DE RESPUESTAS A RESEÑAS PASARON ===';
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
