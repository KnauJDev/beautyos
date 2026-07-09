select
  wp.id,
  wp.ticket_id,
  wp.client_id,
  c.name as client_name,
  wp.stylist_id,
  s.name as stylist_name,
  wp.photo_type,
  wp.caption,
  wp.ai_status,
  wp.visible_to_customer,
  wp.approved_for_portfolio,
  wp.created_at
from public.work_photos wp
left join public.clients c
  on c.id = wp.client_id
left join public.stylists s
  on s.id = wp.stylist_id
order by wp.created_at desc;
