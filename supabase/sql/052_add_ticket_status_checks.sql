do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class rel
      on rel.oid = c.conrelid
    join pg_namespace nsp
      on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'tickets'
      and c.conname = 'tickets_status_check'
  ) then
    alter table public.tickets
    add constraint tickets_status_check
    check (
      status in (
        'solicitado',
        'cotizado',
        'apartado',
        'confirmado',
        'en_espera',
        'en_proceso',
        'finalizado',
        'cerrado',
        'cancelado',
        'no_asistio'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class rel
      on rel.oid = c.conrelid
    join pg_namespace nsp
      on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'ticket_services'
      and c.conname = 'ticket_services_status_check'
  ) then
    alter table public.ticket_services
    add constraint ticket_services_status_check
    check (
      status in (
        'pendiente',
        'en_proceso',
        'finalizado',
        'cancelado'
      )
    );
  end if;
end $$;

select
  rel.relname as table_name,
  c.conname as constraint_name,
  pg_get_constraintdef(c.oid) as constraint_definition
from pg_constraint c
join pg_class rel
  on rel.oid = c.conrelid
join pg_namespace nsp
  on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('tickets', 'ticket_services')
  and c.contype = 'c'
order by rel.relname, c.conname;
