-- BeautyOS - Visibilidad publica de resenas desacoplada de la moderacion.
--
-- Decision del propietario (2026-07-25): aprobar/rechazar (moderate_review,
-- sub-bloque 1) sigue fijando visible_to_public como antes, pero ademas se
-- necesita poder ocultar/mostrar una resena YA aprobada sin cambiar su
-- veredicto de moderacion (ej. un cliente se queja en privado, o la resena
-- menciona a un ex-empleado) -- rechazarla no serviria porque eso tambien
-- la marca como invalida, no solo oculta.

begin;

create or replace function public.set_review_visibility(
  p_branch_id uuid,
  p_review_id uuid,
  p_visible boolean
)
returns void
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

  update public.reviews r
  set
    visible_to_public = p_visible,
    updated_at = now()
  where r.id = p_review_id
    and r.tenant_id = v_access.tenant_id
    and r.branch_id = v_access.branch_id
    and r.active
    and r.moderation_status = 'approved';

  if not found then
    raise exception 'La resena no existe, no pertenece a esta sede, o no esta aprobada.';
  end if;
end;
$$;

revoke all on function public.set_review_visibility(uuid, uuid, boolean)
  from public, anon;

grant execute on function public.set_review_visibility(uuid, uuid, boolean)
  to authenticated, service_role;

comment on function public.set_review_visibility(uuid, uuid, boolean)
  is 'Muestra/oculta una resena ya aprobada sin cambiar su veredicto de moderacion; solo tenant_owner/admin de la sede.';

commit;
