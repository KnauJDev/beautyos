-- Paso 1026A: mantener las agendas alineadas con los estados operativos.
-- Estados visibles en agenda: confirmado, en_espera y en_proceso.
-- Los tickets y servicios terminales no deben aparecer como trabajo pendiente.

create or replace function public.get_agenda_summary()
returns table(
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver agenda.';
  end if;

  return query
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre') as client_name,
    tk.scheduled_at,
    tk.status,
    coalesce(string_agg(distinct s.name, ', ' order by s.name), 'Sin servicios') as service_names,
    coalesce(string_agg(distinct st.name, ', ' order by st.name), 'Sin estilista') as stylist_names,
    coalesce(sum(ts.price), 0)::numeric as total_price,
    coalesce(sum(ts.duration_minutes), 0)::integer as total_duration_minutes
  from public.tickets tk
  left join public.clients c
    on c.id = tk.client_id
   and c.tenant_id = current_tenant_id
   and c.active = true
  left join public.ticket_services ts
    on ts.ticket_id = tk.id
   and ts.tenant_id = current_tenant_id
   and lower(ts.status) <> 'cancelado'
  left join public.services s
    on s.id = ts.service_id
   and s.tenant_id = current_tenant_id
   and s.active = true
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = current_tenant_id
   and st.active = true
  where tk.tenant_id = current_tenant_id
    and tk.scheduled_at is not null
    and lower(tk.status) in ('confirmado', 'en_espera', 'en_proceso')
  group by tk.id, c.name, tk.scheduled_at, tk.status
  order by tk.scheduled_at asc;
end;
$$;

create or replace function public.get_my_stylist_agenda()
returns table(
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
language sql
security definer
set search_path = public
as $$
  with my_profile as (
    select up.tenant_id, up.stylist_id
    from public.user_profiles up
    where up.user_id = auth.uid()
      and up.active = true
      and up.role = 'stylist'
      and up.stylist_id is not null
    limit 1
  )
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
  from my_profile mp
  join public.ticket_services ts
    on ts.tenant_id = mp.tenant_id
   and ts.stylist_id = mp.stylist_id
   and lower(ts.status) in ('pendiente', 'en_proceso')
  join public.tickets t
    on t.id = ts.ticket_id
   and t.tenant_id = mp.tenant_id
   and lower(t.status) in ('confirmado', 'en_espera', 'en_proceso')
  join public.clients c
    on c.id = t.client_id
   and c.tenant_id = mp.tenant_id
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = mp.tenant_id
  order by t.scheduled_at desc nulls last, ts.created_at desc
  limit 100;
$$;

revoke all on function public.get_agenda_summary() from public;
revoke all on function public.get_agenda_summary() from anon;
grant execute on function public.get_agenda_summary() to authenticated;

revoke all on function public.get_my_stylist_agenda() from public;
revoke all on function public.get_my_stylist_agenda() from anon;
grant execute on function public.get_my_stylist_agenda() to authenticated;
