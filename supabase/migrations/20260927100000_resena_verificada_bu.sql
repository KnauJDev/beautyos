-- ============================================================================
-- MIGRACIÓN: 20260927100000_resena_verificada_bu.sql
-- Hallazgo BU (D-283): la reseña de quien no autorizó su nombre salía como
-- "Clienta verificada" -- también la de un hombre. Lo vio el propietario el
-- 27-sep probando el 9.48 con Juan Carlos Rodriguez, y el producto se vende
-- también a barberías. Decidió "Reseña verificada": no dice nada del género
-- de nadie y describe lo que es.
--
-- GENERADA DESDE EL TEXTO VIVO: las dos funciones son las del Bloque 2
-- (20260926170000, aplicada el 26-sep, control 230 en verde). Contra ese
-- texto cambia SOLO el literal. Mismas firmas y mismas columnas que las
-- vivas: create or replace basta, sin drop, y los permisos se conservan.
-- ============================================================================

begin;

create or replace function public.get_public_salon_reviews(p_tenant_id uuid)
returns table (
  avg_rating numeric,
  total_reviews integer,
  client_name text,
  rating integer,
  comment text,
  business_reply text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric;
  v_total integer;
begin
  select coalesce(avg(r.rating), 0)::numeric(3, 2), count(*)::integer
    into v_avg, v_total
  from public.reviews r
  join public.tenants t
    on t.id = r.tenant_id
   and t.active = true
  where r.tenant_id = p_tenant_id
    and r.visible_to_public = true
    and r.active = true;

  return query
  select
    v_avg,
    v_total,
    case when r.client_name_consent then coalesce(r.client_display_name, c.name) else 'Reseña verificada' end,
    r.rating,
    r.comment,
    r.business_reply,
    r.created_at
  from public.reviews r
  join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  where r.tenant_id = p_tenant_id
    and r.visible_to_public = true
    and r.active = true
  order by r.created_at desc
  limit 10;
end;
$$;

create or replace function public.get_reviews_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  service_name text,
  rating integer,
  comment text,
  moderation_status text,
  visible_to_public boolean,
  business_reply text,
  business_reply_at timestamptz,
  created_at timestamptz,
  public_name text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  return query
  select
    r.id,
    r.ticket_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
    coalesce(s.name, 'Servicio no asociado') as service_name,
    r.rating,
    r.comment,
    r.moderation_status,
    r.visible_to_public,
    r.business_reply,
    r.business_reply_at,
    r.created_at,
    case
      when r.client_name_consent then coalesce(r.client_display_name, c.name, 'Reseña verificada')
      else 'Reseña verificada'
    end as public_name
  from public.reviews r
  left join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  left join public.stylists st
    on st.tenant_id = r.tenant_id
   and st.id = r.stylist_id
  left join public.services s
    on s.tenant_id = r.tenant_id
   and s.id = r.service_id
  where r.tenant_id = v_access.tenant_id
    and r.branch_id = v_access.branch_id
    and r.active
  order by r.created_at desc, r.id;
end;
$$;

revoke all on function public.get_reviews_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_reviews_summary_v2(uuid)
  to authenticated;

comment on function public.get_reviews_summary_v2(uuid) is
  'Cola de reseñas del panel del salon, con la respuesta del negocio si existe (paso 6.3, D-170) y el nombre con el que la reseña sale en público (public_name, D-282; "Reseña verificada" si no autorizó su nombre, D-283).';

commit;
