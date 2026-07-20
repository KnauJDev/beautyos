-- BeautyOS - Prueba integral reversible del Tramo C2b.

begin;

do $$
declare
  v_tenant_id uuid;
  v_owner_user uuid;
  v_primary_branch uuid;
  v_secondary_branch uuid;
  v_foreign_tenant uuid := gen_random_uuid();
  v_foreign_branch uuid;
  v_stylist_id uuid;
  v_stylist_membership uuid;
  v_service_id uuid;
  v_other_service_id uuid;
  v_client_id uuid;
  v_primary_price numeric;
  v_primary_duration integer;
  v_branch_service_id uuid;
  v_other_branch_service_id uuid;
  v_branch_stylist_id uuid;
  v_date date;
  v_starts_at timestamptz;
  v_new_starts_at timestamptz;
  v_ticket_id uuid;
  v_primary_ticket_id uuid;
  v_main_ticket_service_id uuid;
  v_added_ticket_service_id uuid;
  v_payment_id uuid;
  v_count integer;
  v_blocked boolean;
  v_total numeric;
begin
  select tm.tenant_id, tm.user_id, b.id
    into v_tenant_id, v_owner_user, v_primary_branch
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id and b.is_primary and b.active
  where tm.role = 'tenant_owner' and tm.active
  order by tm.created_at
  limit 1;

  select tm.id, tm.stylist_id
    into v_stylist_membership, v_stylist_id
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant_id
    and tm.role = 'stylist'
    and tm.active
    and tm.stylist_id is not null
  order by tm.created_at
  limit 1;

  select bs.service_id, bs.price, bs.duration_minutes
    into v_service_id, v_primary_price, v_primary_duration
  from public.branch_services bs
  join public.branch_stylist_services bss
    on bss.branch_service_id = bs.id and bss.active
  join public.branch_stylists bst
    on bst.id = bss.branch_stylist_id
   and bst.stylist_id = v_stylist_id
   and bst.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = v_primary_branch
    and bs.active
  order by bs.created_at
  limit 1;

  select s.id into v_other_service_id
  from public.services s
  where s.tenant_id = v_tenant_id
    and s.active
    and s.id <> v_service_id
  order by s.created_at
  limit 1;

  select c.id into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id and c.active
  order by c.created_at
  limit 1;

  if v_owner_user is null or v_stylist_id is null or v_service_id is null
     or v_other_service_id is null or v_client_id is null then
    raise exception 'La prueba C2b requiere owner, stylist, dos servicios y cliente activos.';
  end if;

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_tenant_id, 'Sede A2 Tramo C2b', 'sede-a2-tramo-c2b',
    'America/Bogota', 'COP', false, true
  ) returning id into v_secondary_branch;

  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer, active
  ) values (
    v_tenant_id, v_secondary_branch, v_service_id,
    v_primary_price + 2000, v_primary_duration + 15, 15, true, true
  ) returning id into v_branch_service_id;

  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer, active
  ) values (
    v_tenant_id, v_secondary_branch, v_other_service_id,
    v_primary_price + 3000, v_primary_duration + 30, 15, true, true
  ) returning id into v_other_branch_service_id;

  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_id, true
  ) returning id into v_branch_stylist_id;

  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values
    (v_tenant_id, v_secondary_branch, v_branch_stylist_id, v_branch_service_id, true),
    (v_tenant_id, v_secondary_branch, v_branch_stylist_id, v_other_branch_service_id, true);

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_membership, true
  );

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open, active
  )
  select bh.tenant_id, v_secondary_branch, bh.day_of_week,
         bh.opens_at, bh.closes_at, bh.is_open, bh.active
  from public.business_hours bh
  where bh.tenant_id = v_tenant_id and bh.branch_id = v_primary_branch;

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_foreign_tenant, 'Tenant B Tramo C2b', 'test',
    'tenant-b-c2b@example.invalid', '+570000000203', true
  );
  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_foreign_tenant, 'Sede B1 Tramo C2b', 'sede-b1-tramo-c2b',
    'America/Bogota', 'COP', true, true
  ) returning id into v_foreign_branch;

  select d::date into v_date
  from generate_series(
    (now() at time zone 'America/Bogota')::date + 60,
    (now() at time zone 'America/Bogota')::date + 74,
    interval '1 day'
  ) d
  join public.business_hours bh
    on bh.tenant_id = v_tenant_id
   and bh.branch_id = v_secondary_branch
   and bh.day_of_week = extract(isodow from d)::integer
   and bh.active and bh.is_open and bh.closes_at > bh.opens_at
  order by d
  limit 1;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  select slots.starts_at into v_starts_at
  from public.get_available_appointment_slots_v2(
    v_secondary_branch, v_service_id, v_stylist_id, v_date
  ) slots
  order by slots.starts_at
  limit 1;

  select created.id into v_ticket_id
  from public.create_scheduled_ticket_with_service_v2(
    v_secondary_branch, v_client_id, v_service_id, v_stylist_id,
    v_starts_at, 'manual', 'Prueba C2b reversible'
  ) created;

  select m.ticket_service_id into v_main_ticket_service_id
  from public.get_ticket_services_for_management_v2(
    v_secondary_branch, v_ticket_id
  ) m
  where m.service_id = v_service_id
  order by m.ticket_service_id
  limit 1;

  if v_main_ticket_service_id is null then
    raise exception 'Diagnostico C2b: la reserva no devolvio su servicio principal (ticket %).',
      coalesce(v_ticket_id::text, 'null');
  end if;

  select added.id into v_added_ticket_service_id
  from public.add_ticket_service_v2(
    v_secondary_branch, v_ticket_id, v_other_service_id, v_stylist_id
  ) added;

  perform 1 from public.update_ticket_service_assignment_v2(
    v_secondary_branch, v_added_ticket_service_id,
    v_service_id, v_stylist_id, 'Prueba de cambio por sede'
  );

  perform 1 from public.remove_ticket_service_v2(
    v_secondary_branch, v_added_ticket_service_id, 'Prueba de retiro por sede'
  );

  execute 'reset role';

  -- La misma persona y hora en otra sede no debe ser un falso choque.
  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_primary_branch, v_client_id, v_starts_at,
    'solicitado', 'manual', 'Misma hora en A1 permitida'
  ) returning id into v_primary_ticket_id;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_primary_branch, v_primary_ticket_id, v_service_id,
    v_stylist_id, v_primary_price, v_primary_duration, 'pendiente'
  );

  -- El mismo cruce dentro de A2 debe seguir bloqueado por el trigger final.
  v_blocked := false;
  begin
    insert into public.tickets (
      tenant_id, branch_id, client_id, scheduled_at, status, channel, notes
    ) values (
      v_tenant_id, v_secondary_branch, v_client_id, v_starts_at,
      'solicitado', 'manual', 'Cruce A2 bloqueado'
    ) returning id into v_primary_ticket_id;
    insert into public.ticket_services (
      tenant_id, branch_id, ticket_id, service_id, stylist_id,
      price, duration_minutes, status
    ) values (
      v_tenant_id, v_secondary_branch, v_primary_ticket_id, v_service_id,
      v_stylist_id, v_primary_price, v_primary_duration, 'pendiente'
    );
  exception when raise_exception then
    v_blocked := position('Choque de agenda' in sqlerrm) > 0;
  end;
  if not v_blocked then
    raise exception 'La barrera final no rechazo el choque dentro de A2.';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  select slots.starts_at into v_new_starts_at
  from public.get_available_appointment_slots_v2(
    v_secondary_branch, v_service_id, v_stylist_id, v_date + 7
  ) slots
  order by slots.starts_at
  limit 1;

  perform 1 from public.reschedule_ticket_v2(
    v_secondary_branch, v_ticket_id, v_new_starts_at, 'Prueba de reprogramacion'
  );
  perform 1 from public.change_ticket_status_v2(
    v_secondary_branch, v_ticket_id, 'confirmado', null
  );

  select count(*) into v_count
  from public.get_ticket_services_for_management_v2(
    v_secondary_branch, v_ticket_id
  ) m
  where m.ticket_service_id = v_main_ticket_service_id;
  if v_count <> 1 then
    raise exception 'Diagnostico C2b: servicio principal no localizado antes de iniciar (%).',
      coalesce(v_main_ticket_service_id::text, 'null');
  end if;

  perform 1 from public.change_ticket_service_status_v2(
    v_secondary_branch, v_main_ticket_service_id, 'en_proceso'
  );
  perform 1 from public.change_ticket_service_status_v2(
    v_secondary_branch, v_main_ticket_service_id, 'finalizado'
  );

  select count(*) into v_count
  from public.get_ticket_services_for_correction_v2(v_secondary_branch, v_ticket_id);
  if v_count <> 1 then
    raise exception 'La correccion C2b no encontro el servicio finalizado.';
  end if;

  perform 1 from public.reopen_finished_ticket_service_v2(
    v_secondary_branch, v_main_ticket_service_id, 'Prueba de correccion'
  );
  perform 1 from public.change_ticket_service_status_v2(
    v_secondary_branch, v_main_ticket_service_id, 'finalizado'
  );

  select total_amount into v_total
  from public.get_ticket_payment_summary_v2(v_secondary_branch, v_ticket_id);

  select paid.id into v_payment_id
  from public.register_ticket_payment_v2(
    v_secondary_branch, v_ticket_id, v_total, 'efectivo', null, 'Prueba C2b'
  ) paid;

  select count(*) into v_count
  from public.get_ticket_payments_v2(v_secondary_branch, v_ticket_id)
  where status = 'registrado';
  if v_count <> 1 then
    raise exception 'El pago C2b no quedo visible en su sede.';
  end if;

  execute 'reset role';

  if not exists (
    select 1 from public.tickets t
    where t.id = v_ticket_id
      and t.branch_id = v_secondary_branch
      and t.status = 'cerrado'
  ) then
    raise exception 'El pago total C2b no cerro el ticket.';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  perform 1 from public.void_ticket_payment_v2(
    v_secondary_branch, v_payment_id, 'Prueba reversible de anulacion'
  );

  execute 'reset role';

  if not exists (
    select 1 from public.tickets t
    where t.id = v_ticket_id
      and t.branch_id = v_secondary_branch
      and t.status = 'finalizado'
  ) then
    raise exception 'La anulacion C2b no reabrio el saldo del ticket.';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  v_blocked := false;
  begin
    perform 1 from public.get_ticket_payments_v2(v_primary_branch, v_ticket_id);
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento C2b fallido: A1 leyo pagos del ticket A2.';
  end if;

  v_blocked := false;
  begin
    perform 1 from public.get_ticket_payments_v2(v_foreign_branch, v_ticket_id);
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento C2b fallido: Owner A uso la sede de Tenant B.';
  end if;

  execute 'reset role';

  if exists (
    select 1
    from (
      select branch_id from public.ticket_history where ticket_id = v_ticket_id
      union all
      select branch_id from public.ticket_service_history where ticket_id = v_ticket_id
      union all
      select branch_id from public.ticket_service_change_history where ticket_id = v_ticket_id
      union all
      select branch_id from public.ticket_payments where ticket_id = v_ticket_id
      union all
      select branch_id from public.stylist_commissions where ticket_id = v_ticket_id
    ) x
    where x.branch_id is distinct from v_secondary_branch
  ) then
    raise exception 'Un hijo historico o financiero no heredo la sede A2.';
  end if;
end;
$$;

rollback;
