-- BeautyOS - Prueba transaccional D3.5.1.
-- Ejecutar solo en ensayo. Toda escritura termina con ROLLBACK.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_resolved uuid;
  v_definition text;
  v_arguments text;
  v_public_execute boolean;
  v_trigger_count integer;
begin
  select b.tenant_id, b.id
    into strict v_tenant_id, v_branch_id
  from public.branches b
  where b.active
  order by b.is_primary desc, b.created_at, b.id
  limit 1;

  if to_regprocedure('private.beautyos_resolve_branch(uuid,uuid)') is null then
    raise exception 'D3.5.1: falta private.beautyos_resolve_branch(uuid,uuid).';
  end if;

  select pg_get_functiondef(to_regprocedure(
           'private.beautyos_resolve_branch(uuid,uuid)'
         )),
         pg_get_function_arguments(to_regprocedure(
           'private.beautyos_resolve_branch(uuid,uuid)'
         ))
    into v_definition, v_arguments;

  if position('SECURITY DEFINER' in v_definition) = 0
     or position('SET search_path TO ''pg_catalog''' in v_definition) = 0
     or position('p_branch_id is null' in lower(v_definition)) = 0
     or position('is_primary' in lower(v_definition)) > 0 then
    raise exception 'D3.5.1: el helper no conserva el patron estricto esperado.';
  end if;

  if has_function_privilege('anon',
       'private.beautyos_resolve_branch(uuid,uuid)', 'EXECUTE')
     or has_function_privilege('authenticated',
       'private.beautyos_resolve_branch(uuid,uuid)', 'EXECUTE') then
    raise exception 'D3.5.1: un rol cliente puede ejecutar el helper privado.';
  end if;

  select exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) acl
    where p.oid = to_regprocedure(
            'private.beautyos_resolve_branch(uuid,uuid)'
          )
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ) into v_public_execute;

  if v_public_execute then
    raise exception 'D3.5.1: PUBLIC conserva EXECUTE sobre el helper privado.';
  end if;

  v_resolved := private.beautyos_resolve_branch(v_tenant_id, v_branch_id);
  if v_resolved is distinct from v_branch_id then
    raise exception 'D3.5.1: una sede valida no se resolvio correctamente.';
  end if;

  begin
    perform private.beautyos_resolve_branch(v_tenant_id, null);
    raise exception 'D3.5.1: el helper acepto branch_id nulo.';
  exception
    when not_null_violation then
      if position('sede es obligatoria' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  begin
    perform private.beautyos_resolve_branch(v_tenant_id);
    raise exception 'D3.5.1: el helper acepto la omision de branch_id.';
  exception
    when not_null_violation then
      if position('sede es obligatoria' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  begin
    perform private.beautyos_resolve_branch(v_tenant_id, gen_random_uuid());
    raise exception 'D3.5.1: el helper acepto una sede ajena o inexistente.';
  exception
    when foreign_key_violation then
      if position('sede no pertenece' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  with expected(trigger_name, table_name, function_name) as (
    values
      ('business_hours_set_branch', 'business_hours', 'beautyos_set_root_branch'),
      ('appointment_policies_set_branch', 'appointment_policies', 'beautyos_set_root_branch'),
      ('tickets_set_branch', 'tickets', 'beautyos_set_root_branch'),
      ('inventory_movements_set_branch', 'inventory_movements', 'beautyos_set_root_branch'),
      ('purchases_set_branch', 'purchases', 'beautyos_set_root_branch'),
      ('expenses_set_branch', 'expenses', 'beautyos_set_root_branch'),
      ('ticket_services_set_branch', 'ticket_services', 'beautyos_set_ticket_branch'),
      ('ticket_history_set_branch', 'ticket_history', 'beautyos_set_ticket_branch'),
      ('ticket_service_history_set_branch', 'ticket_service_history', 'beautyos_set_ticket_branch'),
      ('ticket_service_change_history_set_branch', 'ticket_service_change_history', 'beautyos_set_ticket_branch'),
      ('ticket_payments_set_branch', 'ticket_payments', 'beautyos_set_ticket_branch'),
      ('stylist_commissions_set_branch', 'stylist_commissions', 'beautyos_set_ticket_branch'),
      ('purchase_items_set_branch', 'purchase_items', 'beautyos_set_purchase_branch'),
      ('work_photos_set_branch', 'work_photos', 'beautyos_set_optional_ticket_branch'),
      ('reviews_set_branch', 'reviews', 'beautyos_set_optional_ticket_branch')
  )
  select count(*)
    into v_trigger_count
  from expected e
  join pg_class c
    on c.relname = e.table_name
  join pg_namespace n
    on n.oid = c.relnamespace
   and n.nspname = 'public'
  join pg_trigger t
    on t.tgrelid = c.oid
   and t.tgname = e.trigger_name
   and not t.tgisinternal
   and t.tgenabled <> 'D'
  join pg_proc p
    on p.oid = t.tgfoid
   and p.proname = e.function_name;

  if v_trigger_count <> 15 then
    raise exception 'D3.5.1: solo % de 15 triggers conservan su funcion esperada.',
      v_trigger_count;
  end if;

  begin
    insert into public.expenses (
      id, tenant_id, expense_date, category, description, amount,
      payment_method, notes, active, created_at, updated_at, branch_id
    )
    select
      gen_random_uuid(), e.tenant_id, e.expense_date, e.category,
      e.description, e.amount, e.payment_method, e.notes, e.active,
      now(), now(), null
    from public.expenses e
    where e.tenant_id = v_tenant_id
    order by e.created_at, e.id
    limit 1;

    raise exception 'D3.5.1: un trigger raiz acepto branch_id nulo.';
  exception
    when not_null_violation then
      if position('sede es obligatoria' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  insert into public.expenses (
    id, tenant_id, expense_date, category, description, amount,
    payment_method, notes, active, created_at, updated_at, branch_id
  )
  select
    gen_random_uuid(), e.tenant_id, e.expense_date, e.category,
    e.description, e.amount, e.payment_method, e.notes, e.active,
    now(), now(), v_branch_id
  from public.expenses e
  where e.tenant_id = v_tenant_id
  order by e.created_at, e.id
  limit 1;

  begin
    insert into public.work_photos (
      id, tenant_id, ticket_id, client_id, stylist_id, photo_url,
      photo_type, caption, ai_status, visible_to_customer,
      approved_for_portfolio, active, created_at, updated_at, branch_id
    )
    select
      gen_random_uuid(), wp.tenant_id, null, wp.client_id, wp.stylist_id,
      wp.photo_url, wp.photo_type, wp.caption, wp.ai_status,
      wp.visible_to_customer, wp.approved_for_portfolio, wp.active,
      now(), now(), null
    from public.work_photos wp
    where wp.tenant_id = v_tenant_id
    order by wp.created_at, wp.id
    limit 1;

    raise exception 'D3.5.1: un trigger opcional acepto branch_id nulo sin ticket.';
  exception
    when not_null_violation then
      if position('sede es obligatoria' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  update public.ticket_services ts
     set branch_id = null
   where ts.id = (
     select x.id
     from public.ticket_services x
     where x.tenant_id = v_tenant_id
     order by x.created_at, x.id
     limit 1
   );

  if exists (
    select 1
    from public.ticket_services ts
    where ts.tenant_id = v_tenant_id
      and ts.branch_id is null
  ) then
    raise exception 'D3.5.1: el trigger derivado de ticket no repuso la sede.';
  end if;

  update public.purchase_items pi
     set branch_id = null
   where pi.id = (
     select x.id
     from public.purchase_items x
     where x.tenant_id = v_tenant_id
     order by x.created_at, x.id
     limit 1
   );

  if exists (
    select 1
    from public.purchase_items pi
    where pi.tenant_id = v_tenant_id
      and pi.branch_id is null
  ) then
    raise exception 'D3.5.1: el trigger derivado de compra no repuso la sede.';
  end if;
end;
$$;

select
  t.tgname as trigger_name,
  c.relname as table_name,
  p.proname as function_name,
  t.tgenabled
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
where n.nspname = 'public'
  and t.tgname like '%\_set\_branch' escape '\'
  and not t.tgisinternal
order by t.tgname;

rollback;
