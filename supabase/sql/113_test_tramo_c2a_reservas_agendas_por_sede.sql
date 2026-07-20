-- BeautyOS - Prueba integral C2a en ensayo restaurado.
-- Crea A2 y Tenant B temporalmente; todo termina con ROLLBACK.

begin;

do $$
declare
  v_tenant_id uuid;
  v_owner_user uuid;
  v_primary_branch uuid;
  v_secondary_branch uuid;
  v_foreign_tenant uuid := gen_random_uuid();
  v_foreign_branch uuid;
  v_stylist_user uuid;
  v_stylist_membership uuid;
  v_stylist_id uuid;
  v_service_id uuid;
  v_other_service_id uuid;
  v_client_id uuid;
  v_base_price numeric;
  v_base_duration integer;
  v_branch_service_id uuid;
  v_branch_stylist_id uuid;
  v_date date;
  v_starts_at timestamptz;
  v_ticket_id uuid;
  v_count integer;
  v_price numeric;
  v_duration integer;
  v_blocked boolean;
begin
  select tm.tenant_id, tm.user_id, b.id
    into v_tenant_id, v_owner_user, v_primary_branch
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

  select
    bs.service_id,
    bs.price,
    bs.duration_minutes
    into v_service_id, v_base_price, v_base_duration
  from public.branch_services bs
  join public.branch_stylist_services bss
    on bss.branch_service_id = bs.id
   and bss.active
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
  where c.tenant_id = v_tenant_id
    and c.active
  order by c.created_at
  limit 1;

  if v_owner_user is null
     or v_stylist_user is null
     or v_service_id is null
     or v_client_id is null then
    raise exception 'La prueba C2a requiere owner, stylist, servicio y cliente activos.';
  end if;

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_tenant_id, 'Sede A2 Tramo C2a', 'sede-a2-tramo-c2a',
    'America/Bogota', 'COP', false, true
  ) returning id into v_secondary_branch;

  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer, active
  ) values (
    v_tenant_id, v_secondary_branch, v_service_id,
    v_base_price + 1234, v_base_duration + 15,
    15, true, true
  ) returning id into v_branch_service_id;

  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_id, true
  ) returning id into v_branch_stylist_id;

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
  )
  select
    bh.tenant_id,
    v_secondary_branch,
    bh.day_of_week,
    bh.opens_at,
    bh.closes_at,
    bh.is_open,
    bh.active
  from public.business_hours bh
  where bh.tenant_id = v_tenant_id
    and bh.branch_id = v_primary_branch;

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_foreign_tenant, 'Tenant B Tramo C2a', 'test',
    'tenant-b-c2a@example.invalid', '+570000000202', true
  );

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_foreign_tenant, 'Sede B1 Tramo C2a', 'sede-b1-tramo-c2a',
    'America/Bogota', 'COP', true, true
  ) returning id into v_foreign_branch;

  select d::date into v_date
  from generate_series(
    (now() at time zone 'America/Bogota')::date + 1,
    (now() at time zone 'America/Bogota')::date + 14,
    interval '1 day'
  ) d
  join public.business_hours bh
    on bh.tenant_id = v_tenant_id
   and bh.branch_id = v_secondary_branch
   and bh.day_of_week = extract(isodow from d)::integer
   and bh.active
   and bh.is_open
   and bh.closes_at > bh.opens_at
  order by d
  limit 1;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  select count(*) into v_count
  from public.get_ticket_service_options_v2(v_secondary_branch);
  if v_count <> 1 then
    raise exception 'A2 debio publicar exactamente una opcion; obtuvo %.', v_count;
  end if;

  select slots.starts_at into v_starts_at
  from public.get_available_appointment_slots_v2(
    v_secondary_branch,
    v_service_id,
    v_stylist_id,
    v_date
  ) slots
  order by slots.starts_at
  limit 1;

  if v_starts_at is null then
    raise exception 'A2 debio ofrecer al menos un horario futuro.';
  end if;

  select created.id into v_ticket_id
  from public.create_scheduled_ticket_with_service_v2(
    v_secondary_branch,
    v_client_id,
    v_service_id,
    v_stylist_id,
    v_starts_at,
    'manual',
    'Prueba C2a reversible'
  ) created;

  execute 'reset role';

  select ts.price, ts.duration_minutes
    into v_price, v_duration
  from public.ticket_services ts
  where ts.ticket_id = v_ticket_id;

  if v_price <> v_base_price + 1234
     or v_duration <> v_base_duration + 15 then
    raise exception 'La reserva no conservo precio/duracion configurados en A2.';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  select count(*) into v_count
  from public.get_available_appointment_slots_v2(
    v_secondary_branch,
    v_service_id,
    v_stylist_id,
    v_date
  ) slots
  where slots.starts_at = v_starts_at;
  if v_count <> 0 then
    raise exception 'El horario ocupado en A2 siguio apareciendo disponible.';
  end if;

  select count(*) into v_count
  from public.get_tickets_summary_v2(v_secondary_branch) t
  where t.id = v_ticket_id;
  if v_count <> 1 then
    raise exception 'El ticket C2a no aparecio en el resumen A2.';
  end if;

  select count(*) into v_count
  from public.get_tickets_summary_v2(v_primary_branch) t
  where t.id = v_ticket_id;
  if v_count <> 0 then
    raise exception 'Aislamiento C2a fallido: ticket A2 aparecio en A1.';
  end if;

  if v_other_service_id is not null then
    v_blocked := false;
    begin
      perform 1
      from public.get_available_appointment_slots_v2(
        v_secondary_branch,
        v_other_service_id,
        v_stylist_id,
        v_date
      );
    exception when raise_exception then
      v_blocked := true;
    end;
    if not v_blocked then
      raise exception 'A2 acepto un servicio no configurado en esa sede.';
    end if;
  end if;

  v_blocked := false;
  begin
    perform 1 from public.get_tickets_summary_v2(v_foreign_branch);
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento C2a fallido: Owner A leyo Tenant B.';
  end if;

  execute 'reset role';

  update public.tickets
  set status = 'confirmado'
  where id = v_ticket_id;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  select count(*) into v_count
  from public.get_agenda_summary_v2(v_secondary_branch) a
  where a.id = v_ticket_id;
  if v_count <> 1 then
    raise exception 'La agenda administrativa A2 no recibio su ticket confirmado.';
  end if;

  select count(*) into v_count
  from public.get_agenda_summary_v2(v_primary_branch) a
  where a.id = v_ticket_id;
  if v_count <> 0 then
    raise exception 'Aislamiento C2a fallido: agenda A1 mostro ticket A2.';
  end if;

  execute 'reset role';
  perform set_config('request.jwt.claim.sub', v_stylist_user::text, true);
  execute 'set local role authenticated';

  select count(*) into v_count
  from public.get_my_stylist_agenda_by_date_v2(
    v_secondary_branch,
    v_date
  ) a
  where a.ticket_id = v_ticket_id;
  if v_count <> 1 then
    raise exception 'La agenda Stylist A2 no recibio su servicio confirmado.';
  end if;

  execute 'reset role';
end;
$$;

rollback;
