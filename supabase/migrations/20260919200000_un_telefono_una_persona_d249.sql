-- ============================================================================
-- MIGRACION: 20260919200000_un_telefono_una_persona_d249.sql
-- DESCRIPCION: El celular pasa a ser la llave de la clienta: uno por persona,
--              diez digitos, y la regla escrita en UN solo sitio (D-249,
--              paso 9.52).
--
-- POR QUE EXISTE, Y NO ES HIGIENE DE DATOS
--
-- Decision del propietario, 19-sep, despues de cerrar AW:
--
--   *"Un numero de telefono no se puede compartir (ni con la hermana ni con
--   la mama ni con nadie), ese numero sera nuestra llave de usuario... cuando
--   un usuario del numero autorice datos del otro, ahi que? Mejor cerrar esa
--   puerta."*
--
-- El argumento no es de orden, es de **consentimiento**. El celular ya es la
-- llave del portal de la clienta (D-167): con el y un PIN se ve su historial
-- y sus fotos. Si dos personas comparten esa llave, **una autoriza publicar
-- las fotos de la otra y ve sus citas**. Eso no se arregla avisando.
--
-- Y la segunda mitad de la decision mata el caso `+57` de raiz en vez de
-- parchearlo: **el campo exige diez digitos** y el indicativo lo pone el
-- sistema segun el pais. Un numero guardado es siempre diez digitos, asi que
-- `3506815629`, `350 681 56 29` y `+57 350 681 5629` dejan de ser tres cosas.
--
-- LO QUE SE MIRO ANTES DE TOCAR NADA
--
--   * Duplicados por digitos en toda la base: **cero**. El propietario le dio
--     su propio numero a cada ficha repetida antes de esto, asi que **no hizo
--     falta construir ninguna herramienta para fundir fichas**.
--   * Largos de los celulares guardados: **45 de diez digitos y UNO de nueve**
--     (`323456789`). Se dijo que no se tocaba, porque adivinarle un digito es
--     inventar el dato de una persona.
--
--     **El propietario lo corrigio a mano antes de aplicar esto, y estuvo
--     bien, pero por una razon concreta:** esa ficha era de *Naguara de Unyas*
--     -- correo `jhsxwf@cpodce.com`, notas `savcjewfdhewkmgdisjfv` --, o sea
--     de los datos que sembro el asistente (D-112), donde *"no hay una sola
--     persona real ahi dentro"*. Ahi completar un digito no le cambia el
--     numero a nadie.
--
--     **Con una clienta de verdad la regla sigue siendo preguntar, no
--     adivinar**, y por eso esta migracion nunca toca un celular corto: solo
--     lo ensenya y deja que la pantalla lo pida el dia que alguien edite esa
--     ficha.
--
-- DONDE VIVE EL "10", Y POR QUE IMPORTA
--
-- En **una sola funcion**: `private.beautyos_celular_valido`. No repartido por
-- cinco sitios. Esta semana ya costo dos veces escribir a mano un numero que
-- vive en otra parte: `'profesional'` en register_tenant (D-245, dieciseis
-- dias sin poder registrar a nadie) y el `6` del codigo de confirmacion
-- (hallazgo AY, cazado por el propietario en una hora).
--
-- El dia que haya un segundo pais, ese 10 pasa a ser un dato de la tabla de
-- paises y solo cambia esta funcion. Hoy hay un pais y sobra una tabla.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. La normalizacion: inmutable, sin opinar. Sirve para comparar y para
--    limpiar, y por ser IMMUTABLE se podria indexar si algun dia hace falta.
-- ---------------------------------------------------------------------------
create or replace function private.beautyos_celular_normalizado(p_phone text)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    -- Doce digitos que empiezan por 57 son un numero colombiano con su
    -- indicativo delante: es la MISMA persona. Es el caso que se colo en el
    -- control 216 y que destapo que faltaba resolverlo.
    when length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) = 12
     and left(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), 2) = '57'
    then right(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), 10)
    else nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), '')
  end;
$$;

comment on function private.beautyos_celular_normalizado(text) is
  'Deja un celular en su forma canonica: solo digitos, y sin el indicativo 57 '
  'cuando son doce. Devuelve null si no hay numero. INMUTABLE a proposito: se '
  'usa para comparar, para limpiar y para poder indexar (D-249).';

-- ---------------------------------------------------------------------------
-- 2. La regla, con su mensaje. EL UNICO SITIO donde esta escrito el 10.
-- ---------------------------------------------------------------------------
create or replace function private.beautyos_celular_valido(p_phone text)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_digitos text := private.beautyos_celular_normalizado(p_phone);
begin
  -- Sin numero se devuelve null y no se protesta: quien escribe la ficha
  -- decide si lo pide. Lo que no se admite es un numero A MEDIAS, porque ese
  -- si se convierte en la llave equivocada de una persona.
  if v_digitos is null then
    return null;
  end if;

  if length(v_digitos) <> 10 then
    raise exception 'El celular debe tener 10 digitos. Recibido: % (%).',
      v_digitos, length(v_digitos)
      using errcode = '22023';
  end if;

  return v_digitos;
end;
$$;

comment on function private.beautyos_celular_valido(text) is
  'La regla del celular, en UN solo sitio: diez digitos o se para. Vacio '
  'devuelve null, que es legitimo. Aqui vive el 10; no se escribe en ninguna '
  'otra parte, porque esta semana ya costo dos veces repartir un numero que '
  'vive en otro lado (D-245 y hallazgo AY). El dia que haya un segundo pais, '
  'solo cambia esta funcion (D-249).';

-- ---------------------------------------------------------------------------
-- 3. Poner en forma canonica lo que ya esta guardado.
--
-- Esto NO cambia el numero de nadie: le quita espacios, guiones y el
-- indicativo. La ficha de nueve digitos se queda en nueve, limpia.
-- ---------------------------------------------------------------------------
do $limpieza$
declare
  v_tocadas integer;
  v_raras   text;
begin
  update public.clients
     set phone = private.beautyos_celular_normalizado(phone)
   where phone is not null
     and phone is distinct from private.beautyos_celular_normalizado(phone);
  get diagnostics v_tocadas = row_count;
  raise notice 'Celulares puestos en forma canonica: %', v_tocadas;

  -- Las que no tienen diez digitos se ENSENYAN, no se tocan.
  select string_agg(format('%s (%s digitos)', phone, length(phone)), ', ')
    into v_raras
  from public.clients
  where active and phone is not null and length(phone) <> 10;

  if v_raras is not null then
    raise notice 'Fichas con un celular que no son 10 digitos, sin tocar: %', v_raras;
    raise notice 'Se quedan vivas. La regla las obligara a corregirse cuando alguien edite esa ficha.';
  end if;
end
$limpieza$;

-- ---------------------------------------------------------------------------
-- 4. Antes del candado: comprobar que nadie choque tras la limpieza.
--
-- La consulta de duplicados que se corrio antes usaba los digitos completos,
-- asi que NO habria visto un par como `+573001234567` y `3001234567`. Aqui se
-- mira con la forma canonica ya aplicada, que es la que va a mandar.
-- ---------------------------------------------------------------------------
do $choques$
declare
  v_choques text;
begin
  select string_agg(format('%s x%s', phone, n), ', ')
    into v_choques
  from (
    select tenant_id, phone, count(*) as n
    from public.clients
    where active and phone is not null
    group by tenant_id, phone
    having count(*) > 1
  ) d;

  if v_choques is not null then
    raise exception
      'No se pone el candado: al dejar los celulares en forma canonica quedan repetidos (%). Hay que resolverlos primero.',
      v_choques;
  end if;
end
$choques$;

-- ---------------------------------------------------------------------------
-- 5. El candado: un celular, una clienta, dentro de cada negocio.
--
-- Parcial sobre `active` a proposito: una ficha desactivada no debe impedir
-- que su numero se use otra vez. Y `phone is not null` deja pasar a la
-- clienta de mostrador que no quiso dar su numero: los nulos no chocan.
-- ---------------------------------------------------------------------------
create unique index if not exists clients_tenant_phone_uidx
  on public.clients (tenant_id, phone)
  where active and phone is not null;

comment on index public.clients_tenant_phone_uidx is
  'Un celular, una clienta, por negocio (D-249). No es orden: el celular es la '
  'llave del portal (D-167), y dos personas con la misma llave significa que '
  'una autoriza las fotos de la otra y ve sus citas. Parcial sobre active '
  'porque un numero liberado se puede reusar, y sobre phone not null porque '
  'la clienta de mostrador sin numero es legitima. NO ELIMINAR.';


-- ---------------------------------------------------------------------------
-- 6. create_client: la regla, y un mensaje que se entienda cuando choque.
--
-- **Pasa de `language sql` a `plpgsql` a proposito.** La version SQL no podia
-- explicar nada: si el celular faltaba, la fila simplemente no se insertaba y
-- la pantalla decia *"No se pudo crear el cliente. Verifica tus permisos"*,
-- que es falso y manda a la persona a buscar donde no es. Con el candado
-- nuevo eso se habria repetido con el duplicado.
-- ---------------------------------------------------------------------------
create or replace function public.create_client(
  p_name text,
  p_phone text,
  p_email text default null,
  p_notes text default null
)
returns setof public.clients
language plpgsql
security definer
set search_path = pg_catalog
as $fn$
declare
  v_tenant_id uuid;
  v_phone     text;
  v_duena     text;
begin
  select tm.tenant_id
    into v_tenant_id
  from public.tenant_memberships tm
  where tm.user_id = auth.uid()
    and tm.active
    and tm.starts_at <= now()
    and (tm.ends_at is null or tm.ends_at > now())
    and tm.role in ('tenant_owner', 'admin', 'assistant')
  order by tm.starts_at asc
  limit 1;

  if v_tenant_id is null then
    raise exception 'No tienes permiso para crear clientes en este negocio.';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Escribe el nombre de la clienta.';
  end if;

  -- La regla, en el unico sitio donde vive.
  v_phone := private.beautyos_celular_valido(p_phone);

  if v_phone is null then
    raise exception 'Escribe el celular de la clienta.';
  end if;

  -- El choque se explica ANTES de que lo explique el indice, porque el
  -- mensaje de un indice unico no le dice nada a nadie.
  select c.name into v_duena
  from public.clients c
  where c.tenant_id = v_tenant_id and c.active and c.phone = v_phone
  limit 1;

  if v_duena is not null then
    raise exception
      'Ese celular ya es de %. Un celular es de una sola persona: es con lo que entra a ver sus citas y sus fotos.',
      v_duena
      using errcode = '23505';
  end if;

  return query
  insert into public.clients (tenant_id, name, phone, email, notes)
  values (
    v_tenant_id,
    trim(p_name),
    v_phone,
    nullif(trim(coalesce(p_email, '')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning *;
end;
$fn$;

comment on function public.create_client(text, text, text, text) is
  'Crea una clienta. El celular pasa por private.beautyos_celular_valido y es '
  'unico dentro del negocio (D-249): es la llave con la que ella entra al '
  'portal a ver sus citas y sus fotos, y compartirla significa que una persona '
  'autoriza y ve lo de otra.';


-- ---------------------------------------------------------------------------
-- 7. update_client: la misma regla al editar. Un solo cambio sobre el texto
--    vigente -- `phone = trim(p_phone)` pasa a la funcion --, comprobado con
--    un diff antes de escribirlo (regla de D-119).
-- ---------------------------------------------------------------------------
create or replace function public.update_client(
  p_client_id uuid,
  p_name text,
  p_phone text,
  p_email text default null,
  p_notes text default null,
  p_active boolean default true
)
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  -- Se EXTIENDE la comprobacion original, no se reemplaza (D-095). Usar
  -- get_my_role() fue un error: devuelve UN perfil al azar (select ... limit 1
  -- sin orden), mientras is_owner_or_admin() usa exists y mira TODOS. Quien
  -- tiene mas de un perfil activo -- el propietario, sin ir mas lejos -- podia
  -- quedar fuera de su propio negocio. El asistente se suma con la misma
  -- semantica de exists, sin tocar a nadie mas.
  if not (
    public.is_owner_or_admin()
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.active = true
        and up.role = 'assistant'
    )
  ) then
    raise exception 'No autorizado. Solo owner, admin o asistente puede modificar clientes.';
  end if;

  if p_client_id is null then
    raise exception 'El cliente es obligatorio.';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del cliente es obligatorio.';
  end if;

  if length(trim(coalesce(p_phone, ''))) = 0 then
    raise exception 'El teléfono del cliente es obligatorio.';
  end if;

  if p_active is null then
    raise exception 'El estado del cliente es obligatorio.';
  end if;

  return query
  -- Mismo cuidado que al crear: el choque se explica ANTES de que lo explique
  -- el indice, porque "duplicate key value violates unique constraint" no le
  -- dice nada a quien esta editando una ficha.
  declare
    v_phone text := private.beautyos_celular_valido(p_phone);
    v_duena text;
  begin
    if v_phone is not null then
      select c2.name into v_duena
      from public.clients c2
      where c2.tenant_id = v_tenant_id
        and c2.active
        and c2.phone = v_phone
        and c2.id <> p_client_id
      limit 1;

      if v_duena is not null then
        raise exception
          'Ese celular ya es de %. Un celular es de una sola persona: es con lo que entra a ver sus citas y sus fotos.',
          v_duena
          using errcode = '23505';
      end if;
    end if;
  end;

  update public.clients c
     set name = trim(p_name),
         phone = private.beautyos_celular_valido(p_phone),
         email = nullif(trim(coalesce(p_email, '')), ''),
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         active = p_active
   where c.id = p_client_id
     and c.tenant_id = v_tenant_id
  returning
    c.id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    c.active,
    c.created_at;

  if not found then
    raise exception 'Cliente no encontrado o no pertenece al centro actual.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. public_create_booking: ahora lo guardado es canonico, asi que compara
--    directo contra `c.phone` y usa el indice unico nuevo. Cinco cambios
--    sobre el texto que dejo la migracion de AW de esta misma tarde.
-- ---------------------------------------------------------------------------
create or replace function public.public_create_booking(
  p_branch_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_scheduled_at timestamptz,
  p_client_name text,
  p_client_phone text,
  p_client_email text default null,
  p_notes text default null
)
returns table (
  ticket_id uuid,
  scheduled_at timestamptz,
  service_name text,
  stylist_name text,
  status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_service_price numeric;
  v_service_duration integer;
  v_client_id uuid;
  v_client_name text;
  v_client_phone text;
  v_phone_canonico text;
  v_ticket_id uuid;
  v_futuras integer;
  v_recientes integer;
begin
  select t.id, b.timezone
    into v_tenant_id, v_timezone
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;

  if not private.beautyos_tenant_accepts_new_commitments(v_tenant_id) then
    raise exception 'Este negocio no esta aceptando reservas nuevas en este momento.';
  end if;

  v_client_name := nullif(trim(coalesce(p_client_name, '')), '');
  v_client_phone := nullif(trim(coalesce(p_client_phone, '')), '');
  -- D-249: la regla del celular vive en UN sitio. Aqui solo se llama.
  -- Deja el numero en su forma canonica -- diez digitos, sin indicativo -- y
  -- se para si no lo es, que es lo que impide que nazca media llave.
  v_phone_canonico := private.beautyos_celular_valido(v_client_phone);

  if v_client_name is null then
    raise exception 'Escribe tu nombre para reservar.';
  end if;

  if v_phone_canonico is null then
    raise exception 'Escribe tu numero de celular para reservar.';
  end if;

  if p_scheduled_at is null or p_scheduled_at <= now() then
    raise exception 'Selecciona una fecha y hora futura para reservar.';
  end if;

  -- Tope de reservas por celular (H-02). Sin esto, cualquiera con el enlace
  -- publico puede llenar la agenda: cada reserva nace en 'solicitado' con su
  -- servicio en 'pendiente', y eso ya ocupa el horario para las funciones de
  -- disponibilidad y para el trigger de choque, sin que el negocio confirme
  -- nada. Solo se cuentan las reservas del canal publico: las que crea el
  -- propio negocio por telefono o mostrador no deben estorbar al cliente.
  select count(*)
    into v_futuras
  from public.tickets tk
  join public.clients c
    on c.id = tk.client_id
   and c.tenant_id = tk.tenant_id
  where tk.tenant_id = v_tenant_id
    and c.phone = v_phone_canonico
    and tk.channel = 'web_publico'
    and tk.scheduled_at > now()
    and tk.status in ('solicitado', 'confirmado', 'en_espera', 'en_proceso');

  if v_futuras >= 4 then
    raise exception 'Ya tienes 4 citas pendientes con este numero de celular. Si necesitas otra, comunicate con el negocio.';
  end if;

  -- Las canceladas si cuentan aqui, a proposito: es lo que frena el ciclo de
  -- reservar y cancelar en bucle para saturar la agenda.
  select count(*)
    into v_recientes
  from public.tickets tk
  join public.clients c
    on c.id = tk.client_id
   and c.tenant_id = tk.tenant_id
  where tk.tenant_id = v_tenant_id
    and c.phone = v_phone_canonico
    and tk.channel = 'web_publico'
    and tk.created_at > now() - interval '24 hours';

  if v_recientes >= 8 then
    raise exception 'Este numero de celular ya hizo varias reservas hoy. Intenta de nuevo manana o comunicate con el negocio.';
  end if;

  select bs.price, bs.duration_minutes
    into v_service_price, v_service_duration
  from public.branch_services bs
  join public.branch_stylist_services bss
    on bss.tenant_id = bs.tenant_id
   and bss.branch_id = bs.branch_id
   and bss.branch_service_id = bs.id
   and bss.active
  join public.branch_stylists bst
    on bst.tenant_id = bss.tenant_id
   and bst.branch_id = bss.branch_id
   and bst.id = bss.branch_stylist_id
   and bst.stylist_id = p_stylist_id
   and bst.active
   and bst.starts_at <= now()
   and (bst.ends_at is null or bst.ends_at > now())
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  join public.stylists st
    on st.tenant_id = bst.tenant_id
   and st.id = bst.stylist_id
   and st.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active
    and s.visible_to_customer
    and bs.visible_to_customer;

  if not found then
    raise exception 'El servicio o el profesional seleccionado ya no estan disponibles para reservar.';
  end if;

  if not exists (
    select 1
    from public.public_get_available_slots(
      p_branch_id, p_service_id, p_stylist_id,
      (p_scheduled_at at time zone v_timezone)::date
    ) slots
    where slots.starts_at = p_scheduled_at
  ) then
    raise exception 'Ese horario ya no esta disponible. Elige otro.';
  end if;

  select c.id
    into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id
    and c.phone = v_phone_canonico
    and c.active
  order by c.created_at
  limit 1;

  if v_client_id is null then
    insert into public.clients (tenant_id, name, phone, email)
    values (
      v_tenant_id,
      v_client_name,
      v_phone_canonico,
      nullif(trim(coalesce(p_client_email, '')), '')
    )
    returning id into v_client_id;
  end if;

  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id,
    p_branch_id,
    v_client_id,
    p_scheduled_at,
    'solicitado',
    'web_publico',
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_ticket_id;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id,
    p_branch_id,
    v_ticket_id,
    p_service_id,
    p_stylist_id,
    v_service_price,
    v_service_duration,
    'pendiente'
  );

  return query
  select
    tk.id,
    tk.scheduled_at,
    s.name,
    st.name,
    tk.status
  from public.tickets tk
  join public.services s on s.tenant_id = v_tenant_id and s.id = p_service_id
  join public.stylists st on st.tenant_id = v_tenant_id and st.id = p_stylist_id
  where tk.id = v_ticket_id;
end;
$$;

commit;
