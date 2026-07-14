begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

-- La regla se comprueba en la base, no solamente en Flutter.
do $$
begin
  perform public.change_ticket_status(
    '59a72637-42fc-4558-a2c0-c5135f5e7676',
    'cancelado',
    null
  );

  raise exception 'La prueba debía exigir un motivo de cancelación.';
exception
  when others then
    if position('Indica el motivo' in sqlerrm) = 0 then
      raise;
    end if;
end;
$$;

rollback;
