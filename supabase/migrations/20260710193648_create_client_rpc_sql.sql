create or replace function public.create_client(
  p_name text,
  p_phone text,
  p_email text default null,
  p_notes text default null
)
returns setof public.clients
language sql
security definer
set search_path = public
as $$
  insert into public.clients (
    tenant_id,
    name,
    phone,
    email,
    notes
  )
  select
    up.tenant_id,
    trim(p_name),
    trim(p_phone),
    nullif(trim(coalesce(p_email, '')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
    and up.role in ('owner', 'admin', 'assistant')
    and length(trim(coalesce(p_name, ''))) > 0
    and length(trim(coalesce(p_phone, ''))) > 0
  limit 1
  returning *;
$$;

revoke all on function public.create_client(text, text, text, text) from public;
revoke all on function public.create_client(text, text, text, text) from anon;
grant execute on function public.create_client(text, text, text, text) to authenticated;
