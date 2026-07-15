-- Paso 1038: prueba transaccional de permisos y actualización de usuarios.

begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

do $$
declare
  v_user_count integer;
  v_history_count integer;
  v_result record;
begin
  select count(*) into v_user_count
  from public.get_tenant_users();

  if v_user_count < 2 then
    raise exception 'El propietario no pudo consultar los usuarios del centro.';
  end if;

  select * into v_result
  from public.update_tenant_user_access(
    '0d1902b8-3958-4dc2-a1ff-d1b127f9efad',
    'stylist',
    true
  );

  select count(*) into v_history_count
  from public.user_profile_access_history h
  where h.profile_id = '0d1902b8-3958-4dc2-a1ff-d1b127f9efad'
    and h.changed_by = auth.uid();

  if v_result.role <> 'stylist'
     or v_result.active is not true
     or v_history_count <> 1 then
    raise exception 'La actualización del usuario o su auditoría falló.';
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
    perform * from public.get_tenant_users();
    raise exception 'La consulta de usuarios debió ser rechazada para un estilista.';
  exception
    when others then
      if position('Solo el propietario puede administrar usuarios' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end;
$$;

rollback;
