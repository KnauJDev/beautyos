-- BeautyOS - Verificacion repetible del Tramo A multisede.
-- Solo lectura: no modifica datos ni estructura.

do $$
declare
  v_count bigint;
begin
  select count(*) into v_count
  from public.tenants t
  where not exists (
    select 1
    from public.branches b
    where b.tenant_id = t.id
      and b.is_primary
  );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % tenant(s) sin Sede principal.', v_count;
  end if;

  select count(*) into v_count
  from public.user_profiles up
  where up.tenant_id is not null
    and up.role in ('owner', 'admin', 'assistant', 'stylist')
    and not exists (
      select 1
      from public.tenant_memberships tm
      where tm.tenant_id = up.tenant_id
        and tm.user_id = up.user_id
    );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % perfil(es) de equipo sin membresia tenant.', v_count;
  end if;

  select count(*) into v_count
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
   and b.is_primary
  where not exists (
    select 1
    from public.branch_memberships bm
    where bm.tenant_id = tm.tenant_id
      and bm.branch_id = b.id
      and bm.tenant_membership_id = tm.id
  );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % membresia(s) sin acceso a la Sede principal.', v_count;
  end if;

  select count(*) into v_count
  from public.services s
  join public.branches b on b.tenant_id = s.tenant_id and b.is_primary
  where not exists (
    select 1 from public.branch_services bs
    where bs.tenant_id = s.tenant_id
      and bs.branch_id = b.id
      and bs.service_id = s.id
  );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % servicio(s) sin configuracion en Sede principal.', v_count;
  end if;

  select count(*) into v_count
  from public.stylists s
  join public.branches b on b.tenant_id = s.tenant_id and b.is_primary
  where not exists (
    select 1 from public.branch_stylists bs
    where bs.tenant_id = s.tenant_id
      and bs.branch_id = b.id
      and bs.stylist_id = s.id
  );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % estilista(s) sin asignacion a Sede principal.', v_count;
  end if;

  select count(*) into v_count
  from public.stylist_services ss
  where not exists (
    select 1
    from public.branch_stylist_services bss
    join public.branch_stylists bst
      on bst.id = bss.branch_stylist_id
     and bst.tenant_id = bss.tenant_id
     and bst.branch_id = bss.branch_id
    join public.branch_services bsv
      on bsv.id = bss.branch_service_id
     and bsv.tenant_id = bss.tenant_id
     and bsv.branch_id = bss.branch_id
    join public.branches b
      on b.id = bss.branch_id
     and b.tenant_id = bss.tenant_id
     and b.is_primary
    where bss.tenant_id = ss.tenant_id
      and bst.stylist_id = ss.stylist_id
      and bsv.service_id = ss.service_id
  );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % capacidad(es) sin correspondencia por sede.', v_count;
  end if;

  select count(*) into v_count
  from public.products p
  join public.branches b on b.tenant_id = p.tenant_id and b.is_primary
  where not exists (
    select 1 from public.branch_products bp
    where bp.tenant_id = p.tenant_id
      and bp.branch_id = b.id
      and bp.product_id = p.id
  );
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % producto(s) sin inventario de Sede principal.', v_count;
  end if;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'branches', 'tenant_memberships', 'branch_memberships',
      'branch_services', 'branch_stylists', 'branch_stylist_services',
      'branch_products'
    )
    and not c.relrowsecurity;
  if v_count <> 0 then
    raise exception 'Tramo A invalido: % tabla(s) nuevas sin RLS.', v_count;
  end if;

  select count(*) into v_count
  from information_schema.role_table_grants g
  where g.table_schema = 'public'
    and g.table_name in (
      'branches', 'tenant_memberships', 'branch_memberships',
      'branch_services', 'branch_stylists', 'branch_stylist_services',
      'branch_products'
    )
    and g.grantee in ('anon', 'authenticated');
  if v_count <> 0 then
    raise exception 'Tramo A invalido: existen % grant(s) directos para clientes.', v_count;
  end if;
end;
$$;

select
  (select count(*) from public.tenants) as tenants,
  (select count(*) from public.branches where is_primary) as primary_branches,
  (select count(*) from public.tenant_memberships) as tenant_memberships,
  (select count(*) from public.branch_memberships) as branch_memberships,
  (select count(*) from public.services) as legacy_services,
  (select count(*) from public.branch_services) as branch_services,
  (select count(*) from public.stylists) as legacy_stylists,
  (select count(*) from public.branch_stylists) as branch_stylists,
  (select count(*) from public.stylist_services) as legacy_capabilities,
  (select count(*) from public.branch_stylist_services) as branch_capabilities,
  (select count(*) from public.products) as legacy_products,
  (select count(*) from public.branch_products) as branch_products;

select
  (select count(*) from public.tickets) as tickets,
  (select count(*) from public.ticket_services) as ticket_services,
  (select coalesce(sum(amount), 0) from public.ticket_payments where status = 'registrado') as active_payments,
  (select coalesce(sum(amount), 0) from public.ticket_payments where status = 'anulado') as voided_payments,
  (select coalesce(sum(commission_amount), 0) from public.stylist_commissions where status = 'generada') as active_commissions,
  (select coalesce(sum(commission_amount), 0) from public.stylist_commissions where status = 'anulada') as voided_commissions,
  (select coalesce(sum(current_stock), 0) from public.products where active) as legacy_active_stock,
  (select coalesce(sum(current_stock), 0) from public.branch_products where active) as branch_active_stock;

