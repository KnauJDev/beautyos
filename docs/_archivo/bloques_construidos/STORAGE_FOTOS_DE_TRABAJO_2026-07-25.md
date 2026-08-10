# Infraestructura de Storage para fotos de trabajo

**Fecha:** 25 de julio de 2026
**Estado:** desplegado en el único proyecto real; política de autorización
verificada con `begin;...rollback;` contra datos reales y sintéticos

## 1. Objetivo

Sub-bloque 2 de 3 de "Reseñas y fotos de trabajo" (D-058/D-059). Primera
vez que el proyecto usa Supabase Storage: hasta ahora toda escritura
pasaba por una RPC `SECURITY DEFINER`, nunca directo a una tabla. La
subida a Storage es distinta por diseño (va directo del cliente al
bucket), así que la autorización vive en una política RLS sobre
`storage.objects` en vez de una RPC.

## 2. Decisiones del propietario

- Bucket **público** (URL directa y permanente), no privado con URLs
  firmadas — coherente con cómo `work_photos.photo_url` ya se lee hoy en
  `get_work_photos_summary_v2` (D3.2), y más simple.
- Suben fotos **solo** `tenant_owner`/`admin`/`stylist` — nunca el
  cliente (confirmado en D-059).
- Este sub-bloque no crea la fila en `work_photos` todavía (sub-bloque
  3); deja lista la infraestructura para subir un archivo y obtener su
  URL pública.

## 3. Diseño

- Bucket `work-photos`: público, límite 10 MB, solo
  `image/jpeg|png|webp`.
- `private.beautyos_can_upload_work_photo(p_tenant_id, p_branch_id)`:
  replica la misma regla de `beautyos_resolve_branch_access` —
  `tenant_owner` tiene acceso a todas sus sedes; `admin`/`stylist`
  necesitan una `branch_membership` activa para esa sede exacta.
- Política `work_photos_insert_staff` sobre `storage.objects` (`INSERT`,
  rol `authenticated`): exige `bucket_id = 'work-photos'` y que la ruta
  tenga exactamente 2 carpetas (`{tenant_id}/{branch_id}/archivo.ext`),
  validadas con la función anterior.
- Flutter: paquete `image_picker` (Web y Mobile) y `uuid`;
  `WorkPhotosUploadService` (`pickImage()` + `uploadWorkPhoto()`) sube el
  archivo y devuelve la URL pública.

## 4. Prueba

`begin;...rollback;` contra el proyecto real, probando la función de
autorización directamente (mockeando `auth.uid()` vía
`request.jwt.claim.sub`), 5 escenarios:

1. `tenant_owner` real (Yelimar, "Naguara de Uñas") puede subir a su
   propia sede sin `branch_membership` — ✓.
2. Ese mismo `tenant_owner` **no** puede subir a un tenant sintético
   ajeno — bloqueado ✓.
3. `stylist` sintético con membresía de tenant pero **sin**
   `branch_membership` para esa sede — bloqueado ✓.
4. El mismo `stylist`, tras agregarle la `branch_membership` — puede ✓.
5. Sin sesión (`auth.uid()` nulo) — bloqueado ✓.

No se probó la subida real de un archivo de extremo a extremo (requiere
una sesión autenticada real con contraseña, que este chat no tiene);
queda para el sub-bloque 3, donde la subida se conectará a crear la fila
en `work_photos` y sí será interactivamente verificable en el navegador
del propietario, igual que se hizo con reseñas.

`flutter analyze`: sin hallazgos.

## 5. Fuera de alcance / pendiente

- Crear la fila en `work_photos` y la UI para adjuntar una foto a un
  ticket (sub-bloque 3).
- Aprobar/publicar fotos, `approved_for_portfolio`, `visible_to_customer`
  (sub-bloque 3).
- Corrección de fotos por IA (`ai_status`) — bloque futuro aparte.
