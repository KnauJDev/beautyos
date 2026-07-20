-- BeautyOS - Pruebas de contexto y aislamiento del Tramo C1.
-- Ejecutar exclusivamente en ensayo. Todo termina con ROLLBACK.

begin;

do $$
declare
  v_tenant_id uuid;
  v_primary_branch uuid;
  v_secondary_branch uuid;
  v_owner_user uuid;
  v_owner_membership uuid;
  v_stylist_user uuid;
  v_stylist_membership uuid;
  v_stylist_id uuid;
  v_foreign_tenant uuid := gen_random_uuid();
  v_foreign_branch uuid;
  v_count integer;
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
  order by tm.created_at
  limit 1;

  if v_tenant_id is null or v_owner_user is null or v_stylist_user is null then
    raise exception 'La prueba C1 requiere owner y stylist activos en el tenant restaurado.';
  end if;

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_tenant_id, 'Sede A2 Tramo C1', 'sede-a2-tramo-c1',
    'America/Bogota', 'COP', false, true
  ) returning id into v_secondary_branch;

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_foreign_tenant, 'Tenant B Tramo C1', 'test',
    'tenant-b-c1@example.invalid', '+570000000201', true
  );
  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_foreign_tenant, 'Sede B1 Tramo C1', 'sede-b1-tramo-c1',
    'America/Bogota', 'COP', true, true
  ) returning id into v_foreign_branch;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select count(*) into v_count
  from public.get_my_branch_context_v2();
  if v_count <> 2 then
    raise exception 'Owner A debio recibir exactamente A1 y A2; obtuvo %.', v_count;
  end if;

  perform 1
  from private.beautyos_resolve_branch_access(
    v_secondary_branch,
    array['tenant_owner','admin'],
    true
  );

  v_blocked := false;
  begin
    perform 1
    from private.beautyos_resolve_branch_access(
      v_foreign_branch,
      array['tenant_owner','admin'],
      true
    );
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento C1 fallido: Owner A accedio a Tenant B.';
  end if;

  -- El mismo usuario se convierte temporalmente en admin dentro del rollback.
  update public.tenant_memberships
  set role = 'admin'
  where id = v_owner_membership;

  select count(*) into v_count
  from public.get_my_branch_context_v2();
  if v_count <> 1 then
    raise exception 'Admin A1 debio recibir solo su sede asignada; obtuvo %.', v_count;
  end if;

  v_blocked := false;
  begin
    perform 1
    from private.beautyos_resolve_branch_access(
      v_secondary_branch,
      array['admin'],
      true
    );
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento C1 fallido: Admin A1 accedio a A2.';
  end if;

  update public.tenant_memberships
  set role = 'tenant_owner'
  where id = v_owner_membership;

  -- El estilista conserva su sede y no recibe A2 sin membresia y vinculo.
  perform set_config('request.jwt.claim.sub', v_stylist_user::text, true);
  select count(*) into v_count
  from public.get_my_branch_context_v2();
  if v_count <> 1 then
    raise exception 'Stylist A1 debio recibir solo A1; obtuvo %.', v_count;
  end if;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_membership, true
  );

  select count(*) into v_count
  from public.get_my_branch_context_v2();
  if v_count <> 1 then
    raise exception 'Stylist sin vinculo profesional A2 no debe verla; obtuvo %.', v_count;
  end if;

  update public.tenant_memberships
  set active = false
  where id = v_stylist_membership;

  select count(*) into v_count
  from public.get_my_branch_context_v2();
  if v_count <> 0 then
    raise exception 'Membresia desactivada debio perder acceso inmediato.';
  end if;
end;
$$;

-- Repite el acceso publico con el mismo rol que usa Flutter.
-- La funcion privada debe seguir siendo inaccesible directamente.
do $$
declare
  v_owner_user uuid;
  v_primary_branch uuid;
  v_count integer;
  v_private_blocked boolean := false;
begin
  select tm.user_id, b.id
    into v_owner_user, v_primary_branch
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
   and b.is_primary
   and b.active
  where tm.role = 'tenant_owner'
    and tm.active
  order by tm.created_at
  limit 1;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  execute 'set local role authenticated';

  select count(*) into v_count
  from public.get_my_branch_context_v2();
  if v_count <> 2 then
    raise exception 'Authenticated owner debio recibir A1 y A2; obtuvo %.', v_count;
  end if;

  begin
    perform 1
    from private.beautyos_resolve_branch_access(
      v_primary_branch,
      array['tenant_owner'],
      true
    );
  exception when insufficient_privilege then
    v_private_blocked := true;
  end;

  if not v_private_blocked then
    raise exception 'La funcion privada C1 no debe ser invocable por authenticated.';
  end if;

  execute 'reset role';
end;
$$;

rollback;
