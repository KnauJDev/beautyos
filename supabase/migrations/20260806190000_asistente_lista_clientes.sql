-- Cierra el ultimo hueco de lectura del asistente (D-095).
--
-- get_clients_summary seguia exigiendo owner o admin. La usa la pantalla de
-- Clientes y tambien Tickets, para elegir a que cliente se le abre el ticket:
-- sin ella el asistente no podia crear tickets, que es la mitad de su trabajo.
--
-- Se conserva la funcion heredada tal cual y solo se extiende su guarda, con
-- la misma semantica de exists que usa is_owner_or_admin().

create or replace function public.get_clients_summary()
returns table (
  id uuid,
  name text,
  phone text,
  created_at timestamptz
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

  -- Misma regla que en D-095: se EXTIENDE la guarda original, no se reemplaza.
  -- El asistente necesita esta lista en dos sitios: la pantalla de Clientes y,
  -- sobre todo, al elegir cliente para abrir un ticket. Sin esto no podia
  -- crear tickets, que es la mitad de su trabajo.
  if not (
    public.is_owner_or_admin()
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.active = true
        and up.role = 'assistant'
    )
  ) then
    raise exception 'No autorizado. Solo owner, admin o asistente puede ver clientes.';
  end if;

  return query
  select
    c.id,
    c.name,
    c.phone,
    c.created_at
  from public.clients c
  where c.tenant_id = current_tenant_id
    and c.active = true
  order by c.created_at desc;
end;
$$;
