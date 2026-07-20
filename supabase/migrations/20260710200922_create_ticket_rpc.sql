create or replace function public.create_ticket(
  p_client_id uuid,
  p_scheduled_at timestamptz default null,
  p_channel text default 'manual',
  p_notes text default null
)
returns setof public.tickets
language sql
security definer
set search_path = public
as $$
  insert into public.tickets (
    tenant_id,
    client_id,
    scheduled_at,
    status,
    channel,
    notes
  )
  select
    up.tenant_id,
    c.id,
    p_scheduled_at,
    'solicitado',
    nullif(trim(coalesce(p_channel, 'manual')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  from public.user_profiles up
  join public.clients c
    on c.id = p_client_id
   and c.tenant_id = up.tenant_id
   and c.active = true
  where up.user_id = auth.uid()
    and up.active = true
    and up.role in ('owner', 'admin', 'assistant')
  limit 1
  returning *;
$$;

revoke all on function public.create_ticket(uuid, timestamptz, text, text) from public;
revoke all on function public.create_ticket(uuid, timestamptz, text, text) from anon;
grant execute on function public.create_ticket(uuid, timestamptz, text, text) to authenticated;
