-- Paso 1040: prueba transaccional de edición, desactivación y permisos.

begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

do $$
declare
  v_client public.clients%rowtype;
  v_updated record;
  v_active_count integer;
  v_management_count integer;
begin
  select *
    into v_client
  from public.create_client(
    'Cliente prueba edición',
    '3000000001',
    'edicion@example.com',
    'Registro temporal para validar edición y desactivación.'
  );

  select *
    into v_updated
  from public.update_client(
    v_client.id,
    'Cliente prueba actualizado',
    '3000000002',
    'actualizado@example.com',
    'Cliente desactivado para la prueba.',
    false
  );

  select count(*)
    into v_active_count
  from public.get_clients_summary() c
  where c.id = v_client.id;

  select count(*)
    into v_management_count
  from public.get_clients_management_summary() c
  where c.id = v_client.id
    and c.active = false;

  if v_updated.name <> 'Cliente prueba actualizado'
     or v_updated.phone <> '3000000002'
     or v_updated.active is not false
     or v_active_count <> 0
     or v_management_count <> 1 then
    raise exception 'La edición o desactivación del cliente falló.';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '067dd2e6-9a10-4965-a804-4601c60d724f',
  true
);

do $$
begin
  begin
    perform * from public.get_clients_management_summary();
    raise exception 'La consulta de gestión debía ser rechazada para un estilista.';
  exception
    when others then
      if position('Solo owner o admin puede administrar clientes' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end;
$$;

rollback;
