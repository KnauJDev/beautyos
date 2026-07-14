begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

-- Se prepara una cita temporal de Sandra y se intenta ocupar su misma franja.
-- El bloque exige que la RPC rechace el choque; rollback deja la base intacta.
update public.tickets
   set status = 'confirmado',
       scheduled_at = '2026-08-21 15:00:00+00'
 where id = 'e8f8794d-adec-4d5e-8657-5a385a0720e2';

do $$
begin
  perform public.reschedule_ticket(
    '59a72637-42fc-4558-a2c0-c5135f5e7676',
    '2026-08-21 15:10:00+00',
    'Prueba controlada de choque'
  );

  raise exception 'La prueba debía rechazar el choque de agenda.';
exception
  when others then
    if position('choque de agenda' in sqlerrm) = 0 then
      raise;
    end if;
end;
$$;

rollback;
