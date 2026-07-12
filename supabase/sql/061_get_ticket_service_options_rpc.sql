create or replace function public.get_ticket_service_options()
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  stylist_id uuid,
  stylist_name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  select up.tenant_id
    into v_tenant_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
    and up.role in ('owner', 'admin', 'assistant')
  limit 1;

  if v_tenant_id is null then
    raise exception 'No tienes permisos para consultar opciones de tickets.';
  end if;

  return query
  select
    s.id as service_id,
    s.name as service_name,
    coalesce(s.category, 'Sin categoría') as category,
    s.price,
    s.duration_minutes,
    st.id as stylist_id,
    st.name as stylist_name
  from public.services s
  left join (
    public.stylist_services ss
    join public.stylists st
      on st.id = ss.stylist_id
     and st.tenant_id = ss.tenant_id
     and st.active = true
  )
    on ss.service_id = s.id
   and ss.tenant_id = s.tenant_id
   and ss.active = true
  where s.tenant_id = v_tenant_id
    and s.active = true
  order by s.name, st.name nulls last;
end;
$$;

revoke all on function public.get_ticket_service_options() from public;
revoke all on function public.get_ticket_service_options() from anon;
grant execute on function public.get_ticket_service_options() to authenticated;

select
  routine_schema,
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'get_ticket_service_options';
