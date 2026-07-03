create or replace function public.get_business_settings()
returns table (
  id uuid,
  name text,
  business_type text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text
)
language sql
security definer
set search_path = public
as $$
  select
    tenants.id,
    tenants.name,
    tenants.business_type,
    tenants.contact_email,
    tenants.contact_phone,
    tenants.whatsapp,
    tenants.instagram,
    tenants.facebook
  from public.tenants
  where tenants.active = true
  order by tenants.created_at asc
  limit 1;
$$;

grant execute on function public.get_business_settings() to anon, authenticated;
