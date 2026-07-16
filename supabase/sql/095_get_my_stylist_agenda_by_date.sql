-- Agenda diaria del usuario estilista, aislada por tenant, perfil y fecha
-- local del centro (America/Bogota).

create or replace function public.get_my_stylist_agenda_by_date(
  p_date date
)
returns table (
  ticket_service_id uuid,
  ticket_id uuid,
  scheduled_at timestamptz,
  client_name text,
  service_name text,
  ticket_status text,
  service_status text,
  price numeric,
  duration_minutes integer,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date date := coalesce(
    p_date,
    (now() at time zone 'America/Bogota')::date
  );
  v_tenant_id uuid;
  v_stylist_id uuid;
begin
  select up.tenant_id, up.stylist_id
    into v_tenant_id, v_stylist_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
    and up.role = 'stylist'
    and up.stylist_id is not null
  limit 1;

  if v_tenant_id is null or v_stylist_id is null then
    raise exception 'No existe un perfil estilista activo asociado al usuario actual.';
  end if;

  return query
  select
    ts.id,
    t.id,
    t.scheduled_at,
    c.name,
    s.name,
    t.status,
    ts.status,
    ts.price,
    ts.duration_minutes,
    t.notes
  from public.ticket_services ts
  join public.tickets t
    on t.id = ts.ticket_id
   and t.tenant_id = v_tenant_id
   and t.status in ('confirmado', 'en_espera', 'en_proceso')
   and (t.scheduled_at at time zone 'America/Bogota')::date = v_date
  join public.clients c
    on c.id = t.client_id
   and c.tenant_id = v_tenant_id
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = v_tenant_id
  where ts.tenant_id = v_tenant_id
    and ts.stylist_id = v_stylist_id
    and ts.status in ('pendiente', 'en_proceso')
  order by t.scheduled_at asc, ts.created_at asc;
end;
$$;

revoke all on function public.get_my_stylist_agenda_by_date(date) from public;
revoke all on function public.get_my_stylist_agenda_by_date(date) from anon;
grant execute on function public.get_my_stylist_agenda_by_date(date) to authenticated;
