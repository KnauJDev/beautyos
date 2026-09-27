-- ============================================================================
-- MIGRACIÓN: 20260927140000_publicar_fotos_por_el_servidor_bx.sql
-- Hallazgo BX (D-285).
--
-- EL FALLO: publicar una foto es MOVER su archivo del almacén privado al
-- público, y mover exige permiso de UPDATE en storage.objects. No existe
-- ninguna política de UPDATE (lectura del 27-sep): desde el 09-ago (D-119)
-- ninguna foto ha llegado al almacén público -- está vacío --, y retirarla
-- del portafolio (el movimiento inverso) tampoco podía funcionar.
--
-- LA DECISIÓN DEL PROPIETARIO (27-sep): NO se agrega una política de UPDATE.
-- Mismo criterio que en AS (D-278): mover lo hace una función de servidor
-- con service_role, y nadie gana permiso nuevo sobre el almacenamiento. Si
-- se diera UPDATE al dueño y al administrador, podrían pasar una foto a
-- público sin aprobación ni consentimiento de la clienta.
--
-- ESTA FUNCIÓN es la mitad SQL: decide si quien llama puede mover ESA foto
-- a ESE destino, y devuelve su ruta. La Edge Function `move-work-photo` la
-- llama con la sesión de la persona (no con service_role) y solo después
-- mueve el archivo. La autorización vive entera aquí, como en el 9.48.
--   * 'publico': solo si la foto YA está aprobada para portafolio y tiene
--     el consentimiento de la clienta (D-167). Mover no aprueba: sigue a
--     una aprobación que ya pasó por set_work_photo_portfolio_approval.
--   * 'privado': siempre que sea dueño o administrador de la sede. Sacar
--     algo de internet nunca necesita más permiso.
-- ============================================================================

begin;

create or replace function public.work_photo_authorize_move(
  p_branch_id uuid,
  p_photo_id uuid,
  p_destino text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_path text;
  v_aprobada boolean;
  v_consent boolean;
begin
  if p_destino is null or p_destino not in ('publico', 'privado') then
    raise exception 'Destino invalido: tiene que ser publico o privado.';
  end if;

  -- Mismo permiso que aprobar para el portafolio (D-167): dueño y
  -- administrador de la sede. Un estilista sube fotos, pero no publica.
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  select wp.storage_path, wp.approved_for_portfolio, wp.client_consent
    into v_path, v_aprobada, v_consent
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'La foto no existe o no pertenece a esta sede.';
  end if;

  if v_path is null or btrim(v_path) = '' then
    raise exception 'La foto no tiene archivo.';
  end if;

  if p_destino = 'publico'
     and not (coalesce(v_aprobada, false) and coalesce(v_consent, false))
  then
    raise exception 'Solo se publica una foto aprobada para portafolio y con consentimiento de la clienta (Ley 1581).';
  end if;

  return v_path;
end;
$$;

revoke all on function public.work_photo_authorize_move(uuid, uuid, text)
  from public, anon;
grant execute on function public.work_photo_authorize_move(uuid, uuid, text)
  to authenticated;

comment on function public.work_photo_authorize_move(uuid, uuid, text) is
  'Autoriza mover el archivo de una foto de trabajo entre el almacén privado y el público (D-285, hallazgo BX). A público, solo si ya está aprobada y con consentimiento; a privado, siempre para dueño y administrador. La mueve la Edge Function move-work-photo, con service_role, DESPUÉS de esta autorización.';

commit;
