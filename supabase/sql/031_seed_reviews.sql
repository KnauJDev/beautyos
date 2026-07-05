-- ============================================================
-- BeautyOS - Paso 683
-- Datos demo para reseñas
-- Archivo: supabase/sql/031_seed_reviews.sql
-- ============================================================

with bella as (
  select id
  from public.tenants
  where name = 'Bella Mujer'
  limit 1
),
maria as (
  select id
  from public.clients
  where name = 'María Rodríguez'
  limit 1
),
laura as (
  select id
  from public.clients
  where name = 'Laura Martínez'
  limit 1
),
sandra as (
  select id
  from public.stylists
  where name = 'Sandra Gómez'
  limit 1
),
paola as (
  select id
  from public.stylists
  where name = 'Paola Ruiz'
  limit 1
),
corte as (
  select id
  from public.services
  where name = 'Corte de cabello'
  limit 1
),
tinte as (
  select id
  from public.services
  where name = 'Tinte básico'
  limit 1
),
cepillado as (
  select id
  from public.services
  where name = 'Cepillado'
  limit 1
),
maria_ticket as (
  select id
  from public.tickets
  where client_id = (select id from maria)
  order by created_at desc
  limit 1
)
insert into public.reviews (
  tenant_id,
  ticket_id,
  client_id,
  stylist_id,
  service_id,
  rating,
  comment,
  moderation_status,
  visible_to_public,
  active
)
select
  (select id from bella),
  (select id from maria_ticket),
  (select id from maria),
  (select id from sandra),
  (select id from corte),
  5,
  'Me encantó el corte, Sandra fue muy amable y puntual.',
  'approved',
  true,
  true
where not exists (
  select 1
  from public.reviews
  where tenant_id = (select id from bella)
    and comment = 'Me encantó el corte, Sandra fue muy amable y puntual.'
)

union all

select
  (select id from bella),
  null,
  (select id from laura),
  (select id from paola),
  (select id from tinte),
  4,
  'El color quedó muy bonito, volvería nuevamente.',
  'pending',
  false,
  true
where not exists (
  select 1
  from public.reviews
  where tenant_id = (select id from bella)
    and comment = 'El color quedó muy bonito, volvería nuevamente.'
)

union all

select
  (select id from bella),
  null,
  (select id from maria),
  (select id from sandra),
  (select id from cepillado),
  5,
  'Excelente atención y el cepillado duró bastante.',
  'approved',
  true,
  true
where not exists (
  select 1
  from public.reviews
  where tenant_id = (select id from bella)
    and comment = 'Excelente atención y el cepillado duró bastante.'
);
