-- Salon y Mas - Las fotos de trabajo son privadas hasta que se aprueban
-- (accion A4 de la Etapa A, cierra H-09).
--
-- EL PROBLEMA, DICHO CON PRECISION
--
-- No era que las fotos fueran publicas. **El destino de una foto aprobada ES
-- ser publica**, y eso esta bien: el portafolio existe para que una clienta
-- que no conoce a nadie vea el trabajo de un estilista y se decida, y mas
-- adelante esa misma foto sale publicada con la resena en redes sociales
-- (tarea 4.3 del plan).
--
-- El hueco real es otro: **la aprobacion no controlaba el archivo**. Una foto
-- se subia al bucket publico y quedaba alcanzable desde ese instante, con los
-- dos interruptores (`approved_for_portfolio`, `visible_to_customer`) todavia
-- apagados. Los interruptores gobernaban lo que se ve en la aplicacion, no el
-- archivo. Consecuencia: una foto de una clienta real que nadie habia
-- revisado -- y que quiza nunca dio permiso -- ya era publica, y "ocultarla"
-- no la quitaba de internet.
--
-- LA SOLUCION: DOS ALMACENES, Y APROBAR ES LO QUE MUEVE EL ARCHIVO
--
--   work-photos-private  (nuevo, privado)  Toda foto recien subida.
--   work-photos          (el que ya existe) Solo las aprobadas.
--
-- Aprobar mueve la foto al publico y le da una direccion **permanente**.
-- Retirar la aprobacion la devuelve al privado y desaparece de internet.
--
-- POR QUE NO SE USARON DIRECCIONES QUE CADUCAN PARA TODO
--
-- Era mi primera propuesta y el propietario la corrigio con razon: una red
-- social necesita una direccion permanente para ir a buscar la imagen. Con
-- una que caduca, la publicacion se ve rota a los pocos dias. Habria
-- construido hoy justo lo que habria que deshacer en la Etapa 4. Las
-- direcciones que caducan quedan **solo para lo que es de una sola persona**:
-- ver dentro de la app una foto que aun no se publica.
--
-- QUE INTERRUPTOR PUBLICA (decidido por el propietario el 09-ago)
--
--   approved_for_portfolio -> SI publica. Es el escaparate.
--   visible_to_customer    -> NO publica. Es para que la clienta vea SU foto,
--                             una persona y no el mundo; cuando se construya
--                             esa pantalla usara una direccion que caduca.
--
-- LA OTRA MITAD DE H-09: LOS HUERFANOS
--
-- Los cuatro almacenes tenian **solo politica de insercion**: cada vez que se
-- reemplazaba un logo, una portada o la foto de un profesional, el archivo
-- anterior quedaba guardado para siempre sin forma de borrarlo desde la app.
-- Se agregan politicas de borrado con la misma autorizacion que ya tenia la
-- subida -- se extiende, no se reescribe (regla de D-095).
--
-- ORDEN DE LAS OPERACIONES, QUE NO ES UN DETALLE
--
-- Mover un archivo y actualizar la base son dos pasos y uno puede fallar. La
-- regla que sigue la aplicacion es que **cualquier fallo a medias deje la foto
-- oculta, nunca publicada**:
--   Aprobar        -> primero la base, despues mover. Si falla el movimiento,
--                     la foto no aparece. Molesto, no grave.
--   Quitar aprobado-> primero mover, despues la base. Si falla la base, la
--                     foto ya salio de internet.
-- Al reves, un fallo dejaria el archivo publico con la base diciendo que no.
-- Eso si seria una fuga.

begin;

-- ---------------------------------------------------------------------------
-- 1. El almacen privado.
--    Mismos limites que `work-photos` (D-060): 10 MB y solo imagenes.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'work-photos-private',
  'work-photos-private',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 2. Donde vive cada foto.
--
--    Hasta hoy `work_photos.photo_url` guardaba la direccion publica completa.
--    Eso deja de bastar: una foto sin aprobar no tiene direccion publica. Se
--    guarda **donde esta** (almacen y ruta), que es el dato verdadero, y
--    `photo_url` pasa a ser la direccion publica **solo mientras esta
--    aprobada** -- nula el resto del tiempo.
-- ---------------------------------------------------------------------------

alter table public.work_photos
  add column if not exists storage_bucket text not null default 'work-photos';

alter table public.work_photos
  add column if not exists storage_path text;

comment on column public.work_photos.storage_bucket
  is 'En que almacen esta el archivo ahora mismo. work-photos = publicada; work-photos-private = esperando aprobacion (H-09).';

comment on column public.work_photos.storage_path
  is 'Ruta del archivo dentro de su almacen. Es el dato verdadero; photo_url se deriva de aqui cuando la foto esta aprobada.';

comment on column public.work_photos.photo_url
  is 'Direccion publica permanente. Solo tiene valor mientras approved_for_portfolio es cierto; nula mientras la foto espera aprobacion (H-09).';

-- Se rescata la ruta de las direcciones que ya existen. El formato de Supabase
-- es .../object/public/<bucket>/<ruta>, asi que la ruta es todo lo que sigue
-- al nombre del bucket.
update public.work_photos
set storage_path = split_part(photo_url, '/object/public/work-photos/', 2)
where storage_path is null
  and photo_url like '%/object/public/work-photos/%';

-- Si alguna quedara sin ruta reconocible, se deja marcada en vez de
-- inventarsela: mejor una foto que no se ve y se nota, que una ruta falsa.
alter table public.work_photos
  alter column photo_url drop not null;

-- ---------------------------------------------------------------------------
-- 3. Politicas del almacen privado.
--
--    Misma autorizacion que ya tenia subir (`beautyos_can_upload_work_photo`,
--    D-060): dueno en cualquier sede propia, admin y estilista con membresia
--    activa en esa sede exacta. No se inventa un criterio nuevo.
--
--    SELECT hace falta de verdad: sin el, el propio negocio no podria ver la
--    foto que tiene que revisar antes de aprobarla.
-- ---------------------------------------------------------------------------

drop policy if exists work_photos_private_insert_staff on storage.objects;
create policy work_photos_private_insert_staff
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'work-photos-private'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_work_photo(
      (storage.foldername(name))[1]::uuid
    )
  );

drop policy if exists work_photos_private_select_staff on storage.objects;
create policy work_photos_private_select_staff
  on storage.objects for select to authenticated
  using (
    bucket_id = 'work-photos-private'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_work_photo(
      (storage.foldername(name))[1]::uuid
    )
  );

drop policy if exists work_photos_private_delete_staff on storage.objects;
create policy work_photos_private_delete_staff
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'work-photos-private'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_work_photo(
      (storage.foldername(name))[1]::uuid
    )
  );

-- ---------------------------------------------------------------------------
-- 4. El almacen publico necesita leer y borrar para que el movimiento
--    funcione en los dos sentidos.
--
--    Que el bucket sea publico permite LEER la imagen por su direccion, pero
--    mover un archivo se hace con sesion y pasa por estas politicas.
-- ---------------------------------------------------------------------------

drop policy if exists work_photos_select_staff on storage.objects;
create policy work_photos_select_staff
  on storage.objects for select to authenticated
  using (
    bucket_id = 'work-photos'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_work_photo(
      (storage.foldername(name))[1]::uuid
    )
  );

drop policy if exists work_photos_delete_staff on storage.objects;
create policy work_photos_delete_staff
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'work-photos'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_work_photo(
      (storage.foldername(name))[1]::uuid
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Borrar el archivo viejo al reemplazar logo, portada o foto del
--    profesional. Es la otra mitad de H-09: sin esto crecen sin techo.
--
--    Estos tres almacenes SIGUEN siendo publicos a proposito: son material de
--    mercadeo y se pintan en la pagina publica de reservas. Aqui no hay nada
--    que ocultar, solo que limpiar.
-- ---------------------------------------------------------------------------

drop policy if exists tenant_logos_delete_owner on storage.objects;
create policy tenant_logos_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tenant-logos'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_tenant_logo(
      (storage.foldername(name))[1]::uuid
    )
  );

drop policy if exists tenant_covers_delete_owner on storage.objects;
create policy tenant_covers_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tenant-covers'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_upload_tenant_logo(
      (storage.foldername(name))[1]::uuid
    )
  );

drop policy if exists stylist_photos_delete_owner_admin on storage.objects;
create policy stylist_photos_delete_owner_admin
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'stylist-photos'
    and array_length(storage.foldername(name), 1) = 2
    and private.beautyos_can_manage_stylist_photo(
      (storage.foldername(name))[1]::uuid,
      (storage.foldername(name))[2]::uuid
    )
  );

-- ---------------------------------------------------------------------------
-- 6. Crear una foto: ahora nace PRIVADA y sin direccion publica.
--
--    Cambia la firma (`p_storage_path` en lugar de `p_photo_url`), asi que se
--    elimina la vieja antes de recrear -- leccion de D-084 y D-086: dos
--    versiones sobrecargadas confunden a PostgREST al resolver la llamada.
--
--    De paso desaparece un problema silencioso: hasta hoy la direccion la
--    escribia el cliente y el servidor la guardaba tal cual.
-- ---------------------------------------------------------------------------

drop function if exists public.create_work_photo(uuid, uuid, text, text, text, uuid);

create or replace function public.create_work_photo(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_storage_path text,
  p_photo_type text,
  p_caption text default null,
  p_stylist_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_tenant_id uuid;
  v_client_id uuid;
  v_ticket_status text;
  v_stylist_id uuid;
  v_photo_id uuid;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  -- Se conserva intacta la verificacion de plan de D-069: el portafolio es
  -- una funcionalidad diferenciada y un plan Basico no puede agregar fotos
  -- nuevas. Reescribir una funcion no es excusa para perder lo que ya hacia.
  perform private.beautyos_require_entitlement(
    v_access.tenant_id, 'portfolio',
    'Tu plan actual no incluye fotos de trabajo. Mejora tu plan para agregar fotos nuevas.'
  );

  select tk.tenant_id, tk.client_id, tk.status
    into v_tenant_id, v_client_id, v_ticket_status
  from public.tickets tk
  where tk.id = p_ticket_id
    and tk.tenant_id = v_access.tenant_id
    and tk.branch_id = v_access.branch_id;

  if not found then
    raise exception 'El ticket no existe o no pertenece a esta sede.';
  end if;

  if v_ticket_status in ('cancelado', 'no_asistio') then
    raise exception 'No se pueden agregar fotos a un ticket cancelado o no asistido.';
  end if;

  if p_photo_type not in ('before', 'after', 'final', 'portfolio') then
    raise exception 'Tipo de foto invalido.';
  end if;

  if p_storage_path is null or btrim(p_storage_path) = '' then
    raise exception 'La foto no trae ruta de archivo.';
  end if;

  -- Comprobacion nueva, que la version anterior no podia hacer porque recibia
  -- una direccion completa escrita por el cliente: la ruta tiene que estar
  -- dentro de la carpeta de ESTA sede.
  if split_part(btrim(p_storage_path), '/', 1) <> p_branch_id::text then
    raise exception 'La ruta del archivo no corresponde a esta sede.';
  end if;

  -- Un estilista siempre se autoatribuye la foto (D-061): no puede atribuirla
  -- a otra persona aunque lo intente por parametro.
  if v_access.role = 'stylist' then
    v_stylist_id := v_access.stylist_id;
  elsif p_stylist_id is not null then
    if not exists (
      select 1
      from public.ticket_services ts
      where ts.ticket_id = p_ticket_id
        and ts.stylist_id = p_stylist_id
    ) then
      raise exception 'El estilista seleccionado no corresponde a este ticket.';
    end if;
    v_stylist_id := p_stylist_id;
  else
    v_stylist_id := null;
  end if;

  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    storage_bucket, storage_path, photo_url,
    photo_type, caption,
    visible_to_customer, approved_for_portfolio
  )
  values (
    v_tenant_id, p_branch_id, p_ticket_id, v_client_id, v_stylist_id,
    -- Nace privada y sin direccion publica. Publicarla es una decision
    -- explicita, no el estado por defecto (H-09).
    'work-photos-private', btrim(p_storage_path), null,
    p_photo_type,
    nullif(trim(coalesce(p_caption, '')), ''),
    false, false
  )
  returning id into v_photo_id;

  return v_photo_id;
end;
$$;

revoke all on function public.create_work_photo(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.create_work_photo(uuid, uuid, text, text, text, uuid)
  to authenticated;

comment on function public.create_work_photo(uuid, uuid, text, text, text, uuid)
  is 'Registra una foto de trabajo. Nace en el almacen privado y sin direccion publica: publicarla exige aprobarla (H-09).';

-- ---------------------------------------------------------------------------
-- 7. Aprobar es lo que publica.
--
--    La aplicacion mueve el archivo y llama aqui para dejar constancia. La
--    direccion publica la construye el cliente porque es una concatenacion
--    fija del dominio de Supabase, que la base no conoce; se valida su forma
--    aqui para que no entre cualquier cosa.
-- ---------------------------------------------------------------------------

drop function if exists public.set_work_photo_portfolio_approval(uuid, uuid, boolean);

create or replace function public.set_work_photo_portfolio_approval(
  p_branch_id uuid,
  p_photo_id uuid,
  p_approved boolean,
  p_public_url text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_path text;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  select wp.storage_path into v_path
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'La foto no existe o no pertenece a esta sede.';
  end if;

  if p_approved then
    if p_public_url is null or p_public_url !~ '/object/public/work-photos/' then
      raise exception
        'Para publicar una foto hace falta su direccion publica del almacen work-photos.';
    end if;

    -- La direccion tiene que apuntar a ESTE archivo. Sin esto, se podria
    -- guardar la direccion de una foto de otro negocio.
    if split_part(p_public_url, '/object/public/work-photos/', 2) <> v_path then
      raise exception 'La direccion publica no corresponde a esta foto.';
    end if;

    update public.work_photos
    set approved_for_portfolio = true,
        storage_bucket = 'work-photos',
        photo_url = p_public_url,
        updated_at = now()
    where id = p_photo_id;
  else
    update public.work_photos
    set approved_for_portfolio = false,
        storage_bucket = 'work-photos-private',
        photo_url = null,
        updated_at = now()
    where id = p_photo_id;
  end if;
end;
$$;

revoke all on function public.set_work_photo_portfolio_approval(uuid, uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.set_work_photo_portfolio_approval(uuid, uuid, boolean, text)
  to authenticated;

comment on function public.set_work_photo_portfolio_approval(uuid, uuid, boolean, text)
  is 'Publica o retira una foto del portafolio. Aprobar la mueve al almacen publico con direccion permanente; retirarla la devuelve al privado (H-09). Solo tenant_owner/admin.';

-- ---------------------------------------------------------------------------
-- 8. Las tres lecturas devuelven donde esta la foto, para que la aplicacion
--    sepa si usar la direccion permanente o pedir una temporal.
--    DROP requerido: no se pueden agregar columnas a RETURNS TABLE.
-- ---------------------------------------------------------------------------

drop function if exists public.get_work_photos_summary_v2(uuid);

create or replace function public.get_work_photos_summary_v2(p_branch_id uuid)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  photo_url text,
  storage_bucket text,
  storage_path text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
  created_at timestamptz
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
    wp.id,
    wp.ticket_id,
    c.name,
    st.name,
    wp.photo_url,
    wp.storage_bucket,
    wp.storage_path,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join public.stylists st
    on st.tenant_id = wp.tenant_id
   and st.id = wp.stylist_id
  where wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active
  order by wp.created_at desc;
end;
$$;

revoke all on function public.get_work_photos_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_work_photos_summary_v2(uuid)
  to authenticated;

drop function if exists public.get_my_stylist_work_photos_v2(uuid);

create or replace function public.get_my_stylist_work_photos_v2(p_branch_id uuid)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  service_name text,
  photo_url text,
  storage_bucket text,
  storage_path text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
  created_at timestamptz
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
    array['stylist']::text[],
    true
  );

  return query
  select
    wp.id,
    wp.ticket_id,
    c.name,
    svc.service_name,
    wp.photo_url,
    wp.storage_bucket,
    wp.storage_path,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join lateral (
    select s.name as service_name
    from public.ticket_services ts
    join public.services s
      on s.tenant_id = ts.tenant_id
     and s.id = ts.service_id
    where ts.tenant_id = wp.tenant_id
      and ts.branch_id = wp.branch_id
      and ts.ticket_id = wp.ticket_id
      and ts.stylist_id = wp.stylist_id
    order by ts.created_at desc, ts.id
    limit 1
  ) svc on true
  where wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.stylist_id = v_access.stylist_id
    and wp.active
  order by wp.created_at desc;
end;
$$;

revoke all on function public.get_my_stylist_work_photos_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_my_stylist_work_photos_v2(uuid)
  to authenticated;

commit;
