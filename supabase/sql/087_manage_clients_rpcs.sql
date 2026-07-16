-- Paso 1039: edición y desactivación segura de clientes.
-- Los clientes no se eliminan: su historial de tickets permanece disponible.

create or replace function public.get_clients_management_summary()
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede administrar clientes.';
  end if;

  return query
  select
    c.id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    c.active,
    c.created_at
  from public.clients c
  where c.tenant_id = v_tenant_id
  order by c.active desc, lower(c.name) asc, c.created_at desc;
end;
$$;

create or replace function public.update_client(
  p_client_id uuid,
  p_name text,
  p_phone text,
  p_email text default null,
  p_notes text default null,
  p_active boolean default true
)
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede modificar clientes.';
  end if;

  if p_client_id is null then
    raise exception 'El cliente es obligatorio.';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del cliente es obligatorio.';
  end if;

  if length(trim(coalesce(p_phone, ''))) = 0 then
    raise exception 'El teléfono del cliente es obligatorio.';
  end if;

  if p_active is null then
    raise exception 'El estado del cliente es obligatorio.';
  end if;

  return query
  update public.clients c
     set name = trim(p_name),
         phone = trim(p_phone),
         email = nullif(trim(coalesce(p_email, '')), ''),
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         active = p_active
   where c.id = p_client_id
     and c.tenant_id = v_tenant_id
  returning
    c.id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    c.active,
    c.created_at;

  if not found then
    raise exception 'Cliente no encontrado o no pertenece al centro actual.';
  end if;
end;
$$;

revoke all on function public.get_clients_management_summary() from public;
revoke all on function public.get_clients_management_summary() from anon;
grant execute on function public.get_clients_management_summary() to authenticated;

revoke all on function public.update_client(uuid, text, text, text, text, boolean) from public;
revoke all on function public.update_client(uuid, text, text, text, text, boolean) from anon;
grant execute on function public.update_client(uuid, text, text, text, text, boolean) to authenticated;
