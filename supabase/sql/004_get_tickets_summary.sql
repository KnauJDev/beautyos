-- ============================================================
-- 004_get_tickets_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar tickets resumidos sin
-- exponer directamente toda la tabla public.tickets.
--
-- Version endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- ============================================================

create or replace function public.get_tickets_summary()
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  channel text,
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
    raise exception 'No autorizado. Solo owner o admin puede ver tickets.';
  end if;

  return query
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre') as client_name,
    tk.scheduled_at,
    tk.status,
    tk.channel,
    coalesce(
      string_agg(distinct s.name, ', ' order by s.name),
      'Sin servicios'
    ) as service_names,
    coalesce(
      string_agg(distinct st.name, ', ' order by st.name),
      'Sin estilista'
    ) as stylist_names,
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
  left join public.services s
    on s.id = ts.service_id
   and s.tenant_id = current_tenant_id
   and s.active = true
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = current_tenant_id
   and st.active = true
  where tk.tenant_id = current_tenant_id
  group by
    tk.id,
    c.name,
    tk.scheduled_at,
    tk.status,
    tk.channel,
    tk.created_at
  order by
    tk.scheduled_at desc nulls last,
    tk.created_at desc;
end;
$$;

revoke execute on function public.get_tickets_summary() from anon;
revoke execute on function public.get_tickets_summary() from public;

grant execute on function public.get_tickets_summary() to authenticated;
