-- Paso 6.2 del Plan Maestro (D-169): "Estudio de publicacion" -- version
-- determinista, sin IA externa (decision del propietario: empezar por ahi,
-- dejar la mejora con IA real para cuando exista un proveedor elegido).
--
-- Compone en el propio Flutter (RepaintBoundary, sin servidor de imagenes)
-- una tarjeta 1080x1080 lista para Instagram: la foto ya aprobada para
-- portafolio + logo del negocio + nombre del servicio + una reseña real
-- (opcional) + WhatsApp de contacto.
--
-- Esta migracion solo agrega el RPC que junta los datos que Flutter no
-- tiene sueltos en ningun otro lado: el nombre del servicio (via
-- ticket_services -> services, la foto no lo guarda) y la reseña que
-- corresponde a ese mismo ticket, si existe una aprobada y de buena
-- calificacion. Nombre del negocio, logo y whatsapp ya via
-- get_business_settings(), no se duplican aqui.
--
-- Decision de producto explicita del propietario: por ahora esta funcion
-- NO esta restringida al plan Profesional (D-124 la definia como
-- exclusiva de ese plan, con tope de 50/mes, pensando en la version con
-- costo real de IA). Sin costo por uso hoy, se deja abierta a todos los
-- planes; el candado de plan se agrega el dia que se sume la mejora con
-- IA real y el tope tenga sentido.

begin;

create or replace function public.get_publication_studio_data(
  p_branch_id uuid,
  p_photo_id uuid
)
returns table (
  photo_url text,
  service_names text,
  review_rating integer,
  review_comment text,
  review_client_name text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_ticket_id uuid;
  v_photo_url text;
  v_approved boolean;
  v_consent boolean;
  v_service_names text;
  v_review_rating integer;
  v_review_comment text;
  v_review_client_name text;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  select wp.ticket_id, wp.photo_url, wp.approved_for_portfolio, wp.client_consent
    into v_ticket_id, v_photo_url, v_approved, v_consent
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'Esta foto no existe o no pertenece a esta sede.';
  end if;

  -- Misma condicion que ya exige el portafolio publico (D-167): una foto
  -- que no puede salir al portafolio tampoco puede usarse en una pieza de
  -- marketing armada a partir de ella.
  if not coalesce(v_approved, false) or not coalesce(v_consent, false) then
    raise exception 'Esta foto no esta aprobada para portafolio o no tiene consentimiento de la clienta -- no se puede usar en una publicacion.';
  end if;

  select string_agg(s.name, ', ' order by s.name)
    into v_service_names
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id
  where ts.ticket_id = v_ticket_id
    and ts.tenant_id = v_access.tenant_id
    and ts.status <> 'cancelado';

  -- Solo una reseña con buena calificación tiene sentido en una pieza de
  -- marketing -- una de 1-3 estrellas no se ofrece, aunque exista.
  select r.rating, r.comment, c.name
    into v_review_rating, v_review_comment, v_review_client_name
  from public.reviews r
  join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  where r.ticket_id = v_ticket_id
    and r.tenant_id = v_access.tenant_id
    and r.active = true
    and r.visible_to_public = true
    and r.rating >= 4
  order by r.created_at desc
  limit 1;

  return query
  select
    v_photo_url,
    v_service_names,
    v_review_rating,
    v_review_comment,
    v_review_client_name;
end;
$$;

revoke all on function public.get_publication_studio_data(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.get_publication_studio_data(uuid, uuid)
  to authenticated;

comment on function public.get_publication_studio_data(uuid, uuid) is
  'Datos para componer la tarjeta del Estudio de publicacion (paso 6.2, D-169): exige que la foto ya este aprobada para portafolio y con consentimiento de la clienta, igual que el portafolio publico.';

commit;
