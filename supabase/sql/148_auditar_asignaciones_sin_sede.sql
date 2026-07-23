select
  t.name as tenant_name,
  st.name as stylist_name,
  s.name as service_name
from public.stylist_services ss
join public.tenants t on t.id = ss.tenant_id
join public.stylists st on st.id = ss.stylist_id
join public.services s on s.id = ss.service_id
where ss.active = true
  and not exists (
    select 1
    from public.branch_stylist_services bss
    join public.branch_services bs on bs.id = bss.branch_service_id
    join public.branch_stylists bst on bst.id = bss.branch_stylist_id
    where bss.tenant_id = ss.tenant_id
      and bs.service_id = ss.service_id
      and bst.stylist_id = ss.stylist_id
      and bss.active = true
  )
order by t.name, st.name;
