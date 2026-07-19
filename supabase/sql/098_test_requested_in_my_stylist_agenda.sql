-- Prueba de lectura segura. No modifica datos del negocio.

begin;

select set_config(
  'request.jwt.claim.sub',
  (
    select up.user_id::text
    from public.user_profiles up
    where up.active = true
      and up.role = 'stylist'
      and up.stylist_id is not null
    limit 1
  ),
  true
);

select
  ticket_status,
  count(*) as services_count
from public.get_my_stylist_agenda_by_date(
  (now() at time zone 'America/Bogota')::date
)
group by ticket_status
order by ticket_status;

rollback;
