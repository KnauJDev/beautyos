-- CONTROL 212: El salon edita la sede en la que esta (D-242, paso 9.43).
--
-- POR QUE ESTE ARCHIVO
--
-- Hasta hoy, Configuracion leia y escribia SIEMPRE la sede principal:
--
--     get_business_settings():       left join branches ... is_primary = true
--     update_tenant_contact_info():  update branches ... is_primary = true
--
-- Estando dentro de la sede secundaria, la pantalla ensenyaba la direccion de
-- la principal -- y si la corregias, **la sobrescribias sin aviso**. Con un
-- solo local no se nota; con dos, se corrompe en silencio.
--
-- Lo que mas importa vigilar aqui NO es que guarde. Es:
--
--   * que la direccion **ya no se escriba ni se lea desde el negocio**. Si
--     alguien la devuelve a su sitio de antes, vuelve el pisado silencioso; y
--   * que el permiso sea **POR SEDE y no por negocio**. `is_owner_or_admin()`
--     solo pregunta "mandas en ALGUN sitio de este negocio?", y con esa
--     pregunta un admin de la sede A puede escribir la sede B.
--
-- Que valida, transaccionalmente:
--   1. Las dos funciones nuevas existen y son SECURITY DEFINER.
--   2. **`update_tenant_contact_info` ya NO acepta direccion** (la firma de 7
--      parametros desaparecio).
--   3. **`get_business_settings` ya NO devuelve direccion.**
--   4. El duenyo escribe cualquiera de sus sedes, y el lector lo confirma.
--   5. **Un admin SOLO alcanza la sede donde tiene membresia.** La importante.
--   6. Alguien de otro negocio no alcanza ninguna.
--   7. Escribir vacio VACIA (misma semantica que D-241).
--   8. Un correo sin arroba se rechaza.
--   9. `anon` no alcanza ninguna de las dos.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\212_test_la_sede_se_edita_desde_su_salon.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.
--
-- NOTA para quien anada fixtures: el guardian exige `tenant_memberships` con
-- `role` permitido y, **si el rol no es `tenant_owner`**, ademas una fila de
-- `branch_memberships` para ESA sede. `branches.slug` es NOT NULL y unico por
-- negocio, y un disparador ya crea la suscripcion de cada sede (D-190).

begin;

do $ctrl$
declare
  v_duenyo   uuid := gen_random_uuid();
  v_admin    uuid := gen_random_uuid();
  v_ajeno    uuid := gen_random_uuid();
  v_plan     uuid;
  v_tenant   uuid;
  v_otro     uuid;
  v_sede_a   uuid;
  v_sede_b   uuid;
  v_mem_adm  uuid;
  v_def      text;
  v_capturo  boolean;
  v_error    text;
  r          record;
begin
  -- 1. Las funciones nuevas existen y estan blindadas
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'update_branch_info';

  if v_def is null then
    raise exception 'FALLO 1: public.update_branch_info no existe';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: update_branch_info no es SECURITY DEFINER';
  end if;
  if v_def not ilike '%beautyos_resolve_branch_access%' then
    raise exception 'FALLO 1c: update_branch_info no usa el guardian POR SEDE. Con is_owner_or_admin un admin de la sede A escribiria la B.';
  end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_branch_info'
  ) then
    raise exception 'FALLO 1d: public.get_branch_info no existe';
  end if;
  raise notice 'OK 1   las dos funciones existen, blindadas y con guardian por sede';

  -- 2. LA CORRECCION: el negocio ya no escribe direcciones.
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'update_tenant_contact_info'
      and pg_get_function_identity_arguments(p.oid) = 'text, text, text, text, text, text, text'
  ) then
    raise exception 'FALLO 2: update_tenant_contact_info sigue aceptando direccion. Escribia SIEMPRE en la sede principal, asi que corregir la direccion desde una sede secundaria pisaba la de la otra sin aviso (D-242).';
  end if;
  raise notice 'OK 2   update_tenant_contact_info ya no acepta direccion';

  -- 3. Y tampoco la devuelve.
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral unnest(p.proargnames) as col(nombre)
    where n.nspname = 'public'
      and p.proname = 'get_business_settings'
      and col.nombre = 'address'
  ) then
    raise exception 'FALLO 3: get_business_settings sigue devolviendo address. Devolvia la de la sede principal mirases la sede que mirases (D-242).';
  end if;
  raise notice 'OK 3   get_business_settings ya no devuelve direccion';

  -- Fixtures
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_duenyo, 'duenyo_test212@salonymas.com'),
    (v_admin,  'admin_test212@salonymas.com'),
    (v_ajeno,  'ajeno_test212@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 212', 'barberia', 'c212@salonymas.com', '3000000214', true, true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C212 principal', 'c212-principal', true, true) returning id into v_sede_a;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C212 segunda', 'c212-segunda', false, true) returning id into v_sede_b;

  -- El duenyo: `tenant_owner` alcanza TODAS sus sedes sin branch_membership.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_duenyo, 'tenant_owner', true);

  -- El admin: solo la sede A. Ese `branch_memberships` es todo el control 5.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_admin, 'admin', true)
  returning id into v_mem_adm;

  insert into public.branch_memberships (tenant_id, branch_id, tenant_membership_id, active)
  values (v_tenant, v_sede_a, v_mem_adm, true);

  -- Un negocio ajeno, con su duenyo.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 212 ajeno', 'barberia', 'c212x@salonymas.com', '3000000215', true, true)
  returning id into v_otro;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_otro, v_plan, 'active', now() + interval '30 days');
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_otro, v_ajeno, 'tenant_owner', true);

  -- 4. El duenyo escribe su SEGUNDA sede, que es lo que antes era imposible
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_duenyo::text, 'role', 'authenticated')::text, true);

  perform public.update_branch_info(
    v_sede_b, 'Marta Encargada', 'marta@c212.com', '6011234567',
    '3001234567', 'Calle de la segunda 14-70', 'Bogota', 'Cundinamarca'
  );

  select * into r from public.get_branch_info(v_sede_b);
  if r.address is distinct from 'Calle de la segunda 14-70' then
    raise exception 'FALLO 4: la direccion de la segunda sede no volvio: %', r.address;
  end if;
  if r.manager_name is distinct from 'Marta Encargada' then
    raise exception 'FALLO 4b: el encargado no volvio: %', r.manager_name;
  end if;

  -- Y NO se toco la principal, que es lo que pasaba antes.
  select * into r from public.get_branch_info(v_sede_a);
  if r.address is not null then
    raise exception 'FALLO 4c: escribir la segunda sede toco la PRINCIPAL. Es exactamente el fallo de D-242: la direccion iba siempre a is_primary = true.';
  end if;
  raise notice 'OK 4   el duenyo escribe la sede que quiere, y no salpica a las otras';

  -- 5. LA IMPORTANTE: el admin solo alcanza SU sede.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);

  perform public.update_branch_info(
    v_sede_a, 'Admin de la A', null, null, null, 'Calle A 1-1', null, null
  );

  v_capturo := false;
  begin
    perform public.update_branch_info(
      v_sede_b, 'Intruso', null, null, null, 'Calle robada', null, null
    );
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 5: un admin con membresia SOLO de la sede A escribio la sede B. El permiso esta preguntando por negocio en vez de por sede (D-242).';
  end if;

  -- Y tampoco puede LEERLA.
  v_capturo := false;
  begin
    perform * from public.get_branch_info(v_sede_b);
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 5b: un admin de la sede A puede LEER los datos de la sede B';
  end if;
  raise notice 'OK 5   un admin solo alcanza la sede donde tiene membresia';

  -- 6. Alguien de otro negocio no alcanza nada
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ajeno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.update_branch_info(
      v_sede_a, 'Ajeno', null, null, null, null, null, null
    );
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 6: el duenyo de otro negocio escribio una sede ajena';
  end if;
  raise notice 'OK 6   otro negocio no alcanza estas sedes';

  -- 7. Escribir vacio VACIA (misma semantica que D-241, y por el mismo motivo:
  --    en D-237 un coalesce dejaba una funcion que sabia poner pero no quitar)
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_duenyo::text, 'role', 'authenticated')::text, true);

  perform public.update_branch_info(
    v_sede_b, 'Marta Encargada', null, null, null, null, null, null
  );
  select * into r from public.get_branch_info(v_sede_b);
  if r.address is not null then
    raise exception 'FALLO 7: se mando la direccion vacia y la CONSERVO (%). Alguien puso un coalesce (D-237, D-241).', r.address;
  end if;
  if r.manager_name is distinct from 'Marta Encargada' then
    raise exception 'FALLO 7b: se vacio un campo que SI se mando con valor';
  end if;
  raise notice 'OK 7   escribir vacio vacia, y lo que va con valor se respeta';

  -- 8. Un correo sin arroba se rechaza
  v_capturo := false;
  begin
    perform public.update_branch_info(
      v_sede_b, null, 'sin-arroba', null, null, null, null, null
    );
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 8: guardo un correo sin arroba';
  end if;
  if v_error not like '%correo%' then
    raise exception 'FALLO 8b: se rechazo, pero el mensaje no dice que es el correo: %', v_error;
  end if;
  raise notice 'OK 8   un correo sin arroba se rechaza, y el mensaje lo explica';

  -- 9. anon no alcanza ninguna de las dos
  if has_function_privilege('anon', 'public.get_branch_info(uuid)', 'execute') then
    raise exception 'FALLO 9: anon puede leer los datos de una sede';
  end if;
  if has_function_privilege('anon',
       'public.update_branch_info(uuid, text, text, text, text, text, text, text)',
       'execute') then
    raise exception 'FALLO 9b: anon puede escribir los datos de una sede';
  end if;
  raise notice 'OK 9   anon no alcanza ninguna de las dos';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 212 COMPLETO: 9 de 9 en verde.';
end
$ctrl$;

rollback;
