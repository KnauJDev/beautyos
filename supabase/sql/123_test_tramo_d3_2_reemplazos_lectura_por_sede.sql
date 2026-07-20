-- BeautyOS - Prueba integral reversible del Tramo D3.2.
-- Crea una segunda sede y un tenant ajeno; todo termina con ROLLBACK.

begin;

do $$
declare
  v_tenant_id uuid;
  v_owner_user uuid;
  v_owner_membership uuid;
  v_primary_branch uuid;
  v_secondary_branch uuid;
  v_foreign_tenant uuid := gen_random_uuid();
  v_foreign_branch uuid;
  v_stylist_user uuid;
  v_stylist_membership uuid;
  v_stylist_id uuid;
  v_other_stylist_id uuid;
  v_service_id uuid;
  v_client_id uuid;
  v_branch_service_id uuid;
  v_branch_stylist_id uuid;
  v_other_branch_stylist_id uuid;
  v_ticket_id uuid;
  v_ticket_service_id uuid;
  v_photo_id uuid;
  v_other_photo_id uuid;
  v_review_id uuid;
  v_today timestamptz;
  v_active_clients integer;
  v_count integer;
  v_metrics record;
  v_policy record;
  v_blocked boolean;
begin
  select tm.tenant_id, tm.user_id, tm.id, b.id
    into v_tenant_id, v_owner_user, v_owner_membership, v_primary_branch
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
   and b.is_primary
   and b.active
  where tm.role = 'tenant_owner'
    and tm.active
  order by tm.created_at
  limit 1;

  select tm.user_id, tm.id, tm.stylist_id
    into v_stylist_user, v_stylist_membership, v_stylist_id
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant_id
    and tm.role = 'stylist'
    and tm.active
    and tm.stylist_id is not null
  order by tm.created_at
  limit 1;

  select s.id into v_service_id
  from public.services s
  where s.tenant_id = v_tenant_id
    and s.active
    and s.visible_to_customer
  order by s.created_at
  limit 1;

  select st.id into v_other_stylist_id
  from public.stylists st
  where st.tenant_id = v_tenant_id
    and st.active
    and st.id <> v_stylist_id
  order by st.created_at
  limit 1;

  select c.id into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id and c.active
  order by c.created_at
  limit 1;

  select count(*)::integer into v_active_clients
  from public.clients c
  where c.tenant_id = v_tenant_id and c.active;

  if v_owner_user is null or v_stylist_user is null
     or v_other_stylist_id is null
     or v_service_id is null or v_client_id is null then
    raise exception 'D3.2 requiere owner, stylist, servicio y cliente activos.';
  end if;

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_tenant_id, 'Sede A2 Tramo D3.2', 'sede-a2-tramo-d3-2',
    'America/Bogota', 'COP', false, true
  ) returning id into v_secondary_branch;

  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer, active
  ) values (
    v_tenant_id, v_secondary_branch, v_service_id,
    43210, 75, 15, true, true
  ) returning id into v_branch_service_id;

  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_id, true
  ) returning id into v_branch_stylist_id;

  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_other_stylist_id, true
  ) returning id into v_other_branch_stylist_id;

  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values (
    v_tenant_id, v_secondary_branch,
    v_branch_stylist_id, v_branch_service_id, true
  );

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_membership, true
  );

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week,
    opens_at, closes_at, is_open, active
  ) values (
    v_tenant_id, v_secondary_branch, 1,
    time '08:15', time '17:45', true, true
  );

  insert into public.appointment_policies (
    tenant_id, branch_id, requires_deposit, deposit_percentage,
    cancellation_hours, reschedule_hours, manual_confirmation_required,
    customer_reschedule_allowed, active
  ) values (
    v_tenant_id, v_secondary_branch, true, 33,
    12, 6, false, true, true
  );

  v_today := (
    (now() at time zone 'America/Bogota')::date::timestamp + time '12:00'
  ) at time zone 'America/Bogota';

  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_secondary_branch, v_client_id, v_today,
    'confirmado', 'manual', 'Prueba D3.2 reversible'
  ) returning id into v_ticket_id;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id,
    v_service_id, v_stylist_id, 43210, 75, 'pendiente'
  ) returning id into v_ticket_service_id;

  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    photo_url, photo_type, caption, ai_status,
    visible_to_customer, approved_for_portfolio, active
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id, v_client_id, v_stylist_id,
    'https://example.invalid/d3-2.jpg', 'final', 'Foto D3.2 A2',
    'not_required', true, true, true
  ) returning id into v_photo_id;

  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    photo_url, photo_type, caption, ai_status,
    visible_to_customer, approved_for_portfolio, active
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id, v_client_id,
    v_other_stylist_id, 'https://example.invalid/d3-2-other.jpg',
    'final', 'Foto D3.2 otro estilista', 'not_required',
    false, false, true
  ) returning id into v_other_photo_id;

  insert into public.reviews (
    tenant_id, branch_id, ticket_id, client_id, stylist_id, service_id,
    rating, comment, moderation_status, visible_to_public, active
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id, v_client_id,
    v_stylist_id, v_service_id, 5, 'Resena D3.2 A2',
    'approved', true, true
  ) returning id into v_review_id;

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_foreign_tenant, 'Tenant B Tramo D3.2', 'test',
    'tenant-b-d3-2@example.invalid', '+570000000032', true
  );

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_foreign_tenant, 'Sede B1 Tramo D3.2', 'sede-b1-tramo-d3-2',
    'America/Bogota', 'COP', true, true
  ) returning id into v_foreign_branch;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  select * into strict v_metrics
  from public.get_dashboard_metrics_v2(v_secondary_branch);
  if v_metrics.active_services_count <> 1
     or v_metrics.clients_count <> v_active_clients
     or v_metrics.confirmed_tickets_count <> 1
     or v_metrics.today_tickets_count <> 1
     or v_metrics.active_stylists_count <> 2
     or v_metrics.active_stylist_services_count <> 1 then
    raise exception 'Metricas D3.2 A2 incorrectas: %.', row_to_json(v_metrics);
  end if;

  select * into strict v_policy
  from public.get_appointment_policy_v2(v_secondary_branch);
  if not v_policy.requires_deposit
     or v_policy.deposit_percentage <> 33
     or v_policy.cancellation_hours <> 12
     or v_policy.reschedule_hours <> 6 then
    raise exception 'Politica D3.2 A2 incorrecta: %.', row_to_json(v_policy);
  end if;

  select count(*) into v_count
  from public.get_business_hours_v2(v_secondary_branch) bh
  where bh.day_of_week = 1
    and bh.opens_at = time '08:15'
    and bh.closes_at = time '17:45';
  if v_count <> 1 then
    raise exception 'Horarios D3.2 A2 no quedaron aislados.';
  end if;

  select count(*) into v_count
  from public.get_work_photos_summary_v2(v_secondary_branch) wp
  where wp.id = v_photo_id and wp.caption = 'Foto D3.2 A2';
  if v_count <> 1 then
    raise exception 'Fotos administrativas D3.2 A2 no quedaron aisladas.';
  end if;

  select count(*) into v_count
  from public.get_reviews_summary_v2(v_secondary_branch) r
  where r.id = v_review_id and r.comment = 'Resena D3.2 A2';
  if v_count <> 1 then
    raise exception 'Resenas D3.2 A2 no quedaron aisladas.';
  end if;

  select count(*) into v_count
  from public.get_work_photos_summary_v2(v_primary_branch) wp
  where wp.id = v_photo_id;
  if v_count <> 0 then
    raise exception 'Aislamiento D3.2 fallido: foto A2 aparecio en A1.';
  end if;

  select count(*) into v_count
  from public.get_reviews_summary_v2(v_primary_branch) r
  where r.id = v_review_id;
  if v_count <> 0 then
    raise exception 'Aislamiento D3.2 fallido: resena A2 aparecio en A1.';
  end if;

  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(v_foreign_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento D3.2 fallido: Owner A accedio a Tenant B.';
  end if;

  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(gen_random_uuid());
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 acepto una sede inexistente.';
  end if;

  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(null);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 acepto branch_id nulo.';
  end if;

  execute 'reset role';

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active
  )
  select v_tenant_id, v_primary_branch, v_owner_membership, true
  where not exists (
    select 1
    from public.branch_memberships bm
    where bm.branch_id = v_primary_branch
      and bm.tenant_membership_id = v_owner_membership
  );

  update public.tenant_memberships
  set role = 'admin'
  where id = v_owner_membership;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  perform 1 from public.get_dashboard_metrics_v2(v_primary_branch);

  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(v_secondary_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 permitio al admin leer una sede sin membresia.';
  end if;

  execute 'reset role';
  update public.tenant_memberships
  set role = 'tenant_owner'
  where id = v_owner_membership;

  perform set_config('request.jwt.claim.sub', v_stylist_user::text, true);
  execute 'set local role authenticated';

  select count(*) into v_count
  from public.get_my_stylist_work_photos_v2(v_secondary_branch) wp
  where wp.id = v_photo_id and wp.service_name is not null;
  if v_count <> 1 then
    raise exception 'El estilista D3.2 no obtuvo su foto A2.';
  end if;

  select count(*) into v_count
  from public.get_my_stylist_work_photos_v2(v_secondary_branch) wp
  where wp.id = v_other_photo_id;
  if v_count <> 0 then
    raise exception 'D3.2 mostro al estilista una foto de otro profesional.';
  end if;

  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(v_secondary_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 permitio al stylist consultar el dashboard.';
  end if;

  execute 'reset role';

  update public.branch_memberships
  set starts_at = now() - interval '1 day',
      ends_at = now() - interval '1 second'
  where branch_id = v_secondary_branch
    and tenant_membership_id = v_stylist_membership;

  perform set_config('request.jwt.claim.sub', v_stylist_user::text, true);
  execute 'set local role authenticated';
  v_blocked := false;
  begin
    perform 1 from public.get_my_stylist_work_photos_v2(v_secondary_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 acepto una membresia de sede vencida.';
  end if;
  execute 'reset role';

  update public.branch_memberships
  set starts_at = now(), ends_at = null
  where branch_id = v_secondary_branch
    and tenant_membership_id = v_stylist_membership;

  update public.branch_stylists
  set active = false
  where id = v_branch_stylist_id;

  perform set_config('request.jwt.claim.sub', v_stylist_user::text, true);
  execute 'set local role authenticated';
  v_blocked := false;
  begin
    perform 1 from public.get_my_stylist_work_photos_v2(v_secondary_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 acepto un estilista no asignado a la sede.';
  end if;
  execute 'reset role';

  update public.branches set active = false where id = v_secondary_branch;
  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';
  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(v_secondary_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 acepto una sede inactiva.';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role authenticated';
  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(v_primary_branch);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 acepto una sesion sin usuario.';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role anon';
  v_blocked := false;
  begin
    perform 1 from public.get_dashboard_metrics_v2(v_primary_branch);
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'D3.2 permitio EXECUTE a anon.';
  end if;
  execute 'reset role';

  if v_ticket_service_id is null or v_other_branch_stylist_id is null then
    raise exception 'D3.2 no creo las relaciones de prueba esperadas.';
  end if;
end;
$$;

rollback;
