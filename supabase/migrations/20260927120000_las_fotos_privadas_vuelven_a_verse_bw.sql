-- ============================================================================
-- MIGRACIÓN: 20260927120000_las_fotos_privadas_vuelven_a_verse_bw.sql
-- Hallazgo BW (D-284). Corrige a BC (20260924100000, D-275 a D-277).
--
-- QUÉ PASÓ, CON PRUEBAS (verificar_portafolio_exito.sql, 27-sep):
--   * La política viva `work_photos_private_select_staff` usa
--     private.beautyos_current_platform_role(), que BC le agregó el 24-sep.
--   * Esa función la ejecuta SOLO service_role (22-jul): authenticated =
--     false. Storage evalúa la política como `authenticated`, así que desde
--     el 24-sep NINGUNA persona con sesión podía leer el almacén privado:
--     el salón no veía sus fotos ("Vista no disponible") ni podía
--     publicarlas ("permission denied for function
--     beautyos_current_platform_role", visto por el propietario al aprobar).
--   * Aprobar anota "publicada" ANTES de mover el archivo. Al fallar el
--     movimiento, quedaron DOS fotos (Peluquería Éxito, las dos del 27-sep)
--     con la base diciendo "publicada" y el archivo en el almacén privado:
--     el cuadro roto del portafolio. Ningún otro negocio quedó así.
--
-- QUÉ SE HACE:
--   1. Reparar esas fotos: se dejan como realmente están -- sin publicar --,
--      con las mismas columnas que set_work_photo_portfolio_approval(false)
--      (D-167). Sin ids escritos a mano: repara cualquier foto que la base dé
--      por publicada con su archivo en el privado y NO en el público, y no
--      toca ninguna otra. El consentimiento de la clienta no se toca.
--   2. La política: la misma de BC, letra por letra, cambiando SOLO la
--      función privada por public.get_my_platform_role(), que devuelve lo
--      mismo (llama a la privada por dentro, security definer) y que
--      authenticated SÍ puede ejecutar desde el 22-jul. No se abre ningún
--      permiso nuevo, y soporte sigue viendo las fotos, que era lo que BC
--      quería.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Las fotos que la base da por publicadas sin estarlo.
-- ---------------------------------------------------------------------------

do $reparar$
declare
  v_reparadas integer;
begin
  update public.work_photos wp
  set approved_for_portfolio = false,
      storage_bucket = 'work-photos-private',
      photo_url = null,
      updated_at = now()
  where wp.active
    and wp.approved_for_portfolio
    and wp.storage_path is not null
    and exists (
      select 1 from storage.objects o
      where o.bucket_id = 'work-photos-private' and o.name = wp.storage_path)
    and not exists (
      select 1 from storage.objects o
      where o.bucket_id = 'work-photos' and o.name = wp.storage_path);

  get diagnostics v_reparadas = row_count;
  raise notice 'Fotos reparadas (publicadas en la base, privadas en el almacen): %', v_reparadas;
end
$reparar$;

-- ---------------------------------------------------------------------------
-- 2. La política. Texto vivo (pg_policies, 27-sep):
--    ((bucket_id = 'work-photos-private') AND
--     (array_length(storage.foldername(name), 1) = 1) AND
--     (private.beautyos_can_upload_work_photo(((storage.foldername(name))[1])::uuid)
--      OR (private.beautyos_current_platform_role() IS NOT NULL)))
--    Cambia SOLO la segunda función.
-- ---------------------------------------------------------------------------

alter policy work_photos_private_select_staff on storage.objects
  using (
    bucket_id = 'work-photos-private'
    and array_length(storage.foldername(name), 1) = 1
    and (
      private.beautyos_can_upload_work_photo((storage.foldername(name))[1]::uuid)
      or public.get_my_platform_role() is not null
    )
  );

commit;
