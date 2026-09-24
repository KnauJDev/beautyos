-- ==============================================================================
-- HALLAZGO BC: las fotos vuelven a verse desde el Panel de plataforma
-- Decision del propietario del 24-sep: "arregla las fotos y dejalo como
-- julio" (D-076, D-274).
-- ==============================================================================
--
-- QUE PASABA
--
-- `platform_get_tenant_work_photos` nacio el 27-jul (D-076), ANTES de que el
-- 09-ago las fotos pendientes se volvieran privadas (H-09, D-119). Solo
-- seleccionaba `photo_url`, y desde esa fecha esa columna es NULL hasta que
-- el negocio aprueba la foto para portafolio. La pantalla de soporte
-- (`platform_tenant_detail_page.dart`) enseñaba "Vista no disponible" para
-- CUALQUIER foto que un negocio no hubiera aprobado todavia -- que es
-- exactamente lo que D-076 autorizaba ver.
--
-- El texto vivo confirma que nadie la habia tocado desde julio: es la unica
-- migracion que aparece al buscarla.
--
-- QUE CAMBIA, Y QUE NO
--
-- Dos piezas, generadas desde su texto vivo, cambiando solo lo pedido:
--
--   1. `platform_get_tenant_work_photos` ahora tambien devuelve
--      `storage_bucket` y `storage_path` (0 lineas quitadas, 6 anadidas).
--      Con eso Flutter sabe si la foto ya tiene direccion publica o necesita
--      pedir una temporal.
--   2. La politica `work_photos_private_select_staff` del almacen privado
--      gana UNA condicion mas, con `or`: ademas de quien pertenece al
--      negocio, tambien puede leer (para firmar una direccion temporal)
--      quien tiene rol de plataforma (`beautyos_current_platform_role() is
--      not null`) -- el mismo candado que ya usan `platform_get_tenant_
--      reviews`, `platform_get_tenant_clients` y las demas RPC de soporte.
--      **No se toca nada mas de la politica**, y el negocio conserva
--      exactamente el mismo acceso que tenia.
--
-- Deliberadamente NO se construye ningun mecanismo nuevo (Edge Function,
-- tabla de solicitudes): D-076 decia "solo lectura y sin rastro", y eso es
-- justo lo que esto entrega, reutilizando el candado que ya protege las
-- otras cinco pestañas de esta misma pantalla.
--
-- Lo que sigue siendo una decision aparte, sin resolver aqui (regla 20): que
-- pasa con este acceso el dia que entre el primer cliente real. D-076 decia
-- "mientras la plataforma no tenga clientes reales"; esta migracion no toca
-- esa condicion.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\228_test_las_fotos_vuelven_a_verse.sql
--   3. Verificacion en pantalla (regla 21): Panel de plataforma -> un
--      negocio con una foto pendiente de aprobar -> pestaña Fotos.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

CREATE OR REPLACE FUNCTION public.platform_get_tenant_work_photos(p_tenant_id uuid)
 RETURNS TABLE(photo_id uuid, branch_name text, client_name text, stylist_name text, photo_url text, photo_type text, caption text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone, storage_bucket text, storage_path text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    wp.id,
    b.name,
    coalesce(c.name, 'Cliente no asociado'),
    coalesce(st.name, 'Estilista no asociado'),
    wp.photo_url,
    wp.photo_type,
    wp.caption,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at,
    -- BC (D-076, restaurado el 24-sep): antes solo se seleccionaba
    -- photo_url, que desde el 09-ago (H-09) es NULL hasta que el negocio
    -- aprueba la foto. Con esto Flutter puede pedir una direccion temporal
    -- para las que aun esperan aprobacion, igual que ya hace el propio
    -- negocio (WorkPhotoStorage.firmar).
    wp.storage_bucket,
    wp.storage_path
  from public.work_photos wp
  join public.branches b
    on b.tenant_id = wp.tenant_id
   and b.id = wp.branch_id
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join public.stylists st
    on st.tenant_id = wp.tenant_id
   and st.id = wp.stylist_id
  where wp.tenant_id = p_tenant_id
    and wp.active
  order by wp.created_at desc;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. La politica del almacen privado: una condicion mas, nada se quita
-- ---------------------------------------------------------------------------

alter policy work_photos_private_select_staff on storage.objects
  using (
    bucket_id = 'work-photos-private'
    and array_length(storage.foldername(name), 1) = 1
    and (
      private.beautyos_can_upload_work_photo((storage.foldername(name))[1]::uuid)
      or private.beautyos_current_platform_role() is not null
    )
  );

commit;
