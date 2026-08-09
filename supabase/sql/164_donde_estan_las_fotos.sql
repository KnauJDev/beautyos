-- Diagnostico: donde quedo cada foto de trabajo.
--
-- SOLO LECTURA. Responde la pregunta del propietario del 09-ago: "subi fotos
-- en ambos perfiles y no las encuentro en el menu de fotos".
--
-- La galeria del dueno filtra por **sede activa**, y "Mis fotos" del estilista
-- filtra ademas por **su propio identificador de estilista**. Si una foto no
-- aparece, casi siempre es una de esas dos cosas.

-- ---------------------------------------------------------------------------
-- 1. Todas las fotos, con su sede, su estilista y donde vive el archivo.
-- ---------------------------------------------------------------------------
select
  wp.created_at,
  b.name           as sede,
  coalesce(st.name, '(sin estilista)')  as estilista,
  coalesce(c.name, '(sin cliente)')     as cliente,
  wp.photo_type    as tipo,
  wp.caption       as descripcion,
  wp.active        as visible_en_la_app,
  wp.approved_for_portfolio as aprobada,
  wp.storage_bucket as almacen
from public.work_photos wp
join public.branches b on b.id = wp.branch_id
left join public.stylists st on st.tenant_id = wp.tenant_id and st.id = wp.stylist_id
left join public.clients  c  on c.tenant_id = wp.tenant_id and c.id = wp.client_id
order by wp.created_at desc;

-- ---------------------------------------------------------------------------
-- 2. Cuantas fotos hay por sede.
--
--    Si una sede tiene fotos y la otra no, el motivo de "no las encuentro" es
--    que la pantalla esta mirando la sede equivocada: el selector de sede de
--    la barra superior decide que se ve.
-- ---------------------------------------------------------------------------
select b.name as sede, count(wp.id) as fotos
from public.branches b
left join public.work_photos wp on wp.branch_id = b.id and wp.active
group by b.name
order by b.name;

-- ---------------------------------------------------------------------------
-- 3. Fotos por estilista.
--
--    "Mis fotos" solo muestra las del estilista que inicio sesion. Una foto
--    sin estilista asignado no aparece en la pantalla de NADIE, solo en la
--    galeria del dueno.
-- ---------------------------------------------------------------------------
select
  coalesce(st.name, '(sin estilista asignado)') as estilista,
  count(wp.id) as fotos
from public.work_photos wp
left join public.stylists st on st.tenant_id = wp.tenant_id and st.id = wp.stylist_id
where wp.active
group by st.name
order by 1;
