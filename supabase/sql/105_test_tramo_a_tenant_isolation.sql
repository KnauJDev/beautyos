-- BeautyOS - Pruebas negativas del Tramo A.
-- Ejecutar exclusivamente en ensayo: toda la prueba termina con ROLLBACK.

begin;

do $$
declare
  v_source_service uuid;
  v_source_membership uuid;
  v_other_tenant uuid := gen_random_uuid();
  v_other_branch uuid;
  v_blocked boolean;
begin
  select id into v_source_service from public.services order by id limit 1;
  select id into v_source_membership from public.tenant_memberships order by id limit 1;

  if v_source_service is null or v_source_membership is null then
    raise exception 'La prueba requiere al menos un servicio y una membresia existentes.';
  end if;

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_other_tenant,
    'Tenant aislado de prueba',
    'test',
    'test@example.invalid',
    '+570000000000',
    true
  );

  insert into public.branches (
    tenant_id, name, slug, is_primary
  ) values (
    v_other_tenant, 'Sede aislada', 'sede-aislada', true
  ) returning id into v_other_branch;

  v_blocked := false;
  begin
    insert into public.branch_services (
      tenant_id, branch_id, service_id, price, duration_minutes
    ) values (
      v_other_tenant, v_other_branch, v_source_service, 1, 15
    );
  exception when foreign_key_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Fallo de aislamiento: se acepto un servicio de otro tenant.';
  end if;

  v_blocked := false;
  begin
    insert into public.branch_memberships (
      tenant_id, branch_id, tenant_membership_id
    ) values (
      v_other_tenant, v_other_branch, v_source_membership
    );
  exception when foreign_key_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Fallo de aislamiento: se acepto una membresia de otro tenant.';
  end if;

  v_blocked := false;
  begin
    insert into public.tenant_memberships (
      tenant_id, user_id, role
    )
    select v_other_tenant, user_id, 'rol_invalido'
    from public.tenant_memberships
    limit 1;
  exception when check_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Fallo de integridad: se acepto un rol no permitido.';
  end if;
end;
$$;

rollback;

