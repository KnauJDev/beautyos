-- ============================================================
-- BeautyOS - Paso 658
-- Seed demo para fotos de trabajos
-- Archivo: supabase/sql/029_seed_work_photos.sql
-- ============================================================

with demo_data as (
  select
    tenants.id as tenant_id,
    tickets.id as ticket_id,
    clients.id as client_id,
    stylists.id as stylist_id
  from public.tenants
  left join public.clients
    on clients.tenant_id = tenants.id
    and clients.name = 'María Rodríguez'
  left join public.stylists
    on stylists.tenant_id = tenants.id
    and stylists.name = 'Sandra Gómez'
  left join public.tickets
    on tickets.tenant_id = tenants.id
    and tickets.client_id = clients.id
  where tenants.name = 'Bella Mujer'
  order by tickets.created_at desc nulls last
  limit 1
),
demo_photos as (
  select *
  from (
    values
      (
        'https://placehold.co/600x800/png?text=Antes+BeautyOS',
        'before',
        'Foto demo antes del servicio de corte de cabello.',
        'not_required',
        false,
        false
      ),
      (
        'https://placehold.co/600x800/png?text=Despues+BeautyOS',
        'after',
        'Foto demo después del servicio de corte de cabello.',
        'pending',
        true,
        false
      ),
      (
        'https://placehold.co/600x800/png?text=Portafolio+BeautyOS',
        'portfolio',
        'Foto demo aprobada para portafolio del centro de belleza.',
        'processed',
        true,
        true
      )
  ) as photos (
    photo_url,
    photo_type,
    caption,
    ai_status,
    visible_to_customer,
    approved_for_portfolio
  )
)
insert into public.work_photos (
  tenant_id,
  ticket_id,
  client_id,
  stylist_id,
  photo_url,
  photo_type,
  caption,
  ai_status,
  visible_to_customer,
  approved_for_portfolio
)
select
  demo_data.tenant_id,
  demo_data.ticket_id,
  demo_data.client_id,
  demo_data.stylist_id,
  demo_photos.photo_url,
  demo_photos.photo_type,
  demo_photos.caption,
  demo_photos.ai_status,
  demo_photos.visible_to_customer,
  demo_photos.approved_for_portfolio
from demo_data
cross join demo_photos
where not exists (
  select 1
  from public.work_photos
  where work_photos.tenant_id = demo_data.tenant_id
    and work_photos.caption = demo_photos.caption
);
