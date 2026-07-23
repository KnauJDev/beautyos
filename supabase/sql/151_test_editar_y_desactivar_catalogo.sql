-- BeautyOS - Prueba real (con rollback) de editar/desactivar servicios y
-- estilistas contra el tenant real "Cortes y Barbas".

begin;

do $$
declare
  v_service_id uuid := 'a4dc68f3-51c5-4cdc-bb2f-598ed65127a7'; -- Corte de Pelo
  v_stylist_id uuid := 'db2bbd57-0b7c-4818-95b7-f578f231c5e6'; -- Nicolas Alonso
  v_branch_id uuid := 'a12dcc83-c6fd-4f87-a824-2c4e98e11f33';
  v_owner_id uuid := '54403360-f1e3-4475-95c5-607368f3e8a7'; -- amanteperfumes@gmail.com
  v_other_user_id uuid := '2975e198-2f33-4cd3-a3f2-4d93eb517118';
  v_name text;
  v_duration integer;
  v_price numeric;
  v_branch_duration integer;
  v_branch_price numeric;
  v_tenant_active boolean;
  v_branch_active boolean;
  v_phone text;
  v_specialty text;
  v_filas integer;
begin
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);

  -- 1. Editar el servicio actualiza catalogo y sede a la vez.
  perform public.update_service(
    v_branch_id, v_service_id, 'Corte clasico editado', 'Cabello', 45, 25000, true
  );

  select name, duration_minutes, price into v_name, v_duration, v_price
  from public.services where id = v_service_id;

  select duration_minutes, price into v_branch_duration, v_branch_price
  from public.branch_services
  where service_id = v_service_id and branch_id = v_branch_id;

  if v_name <> 'Corte clasico editado' or v_duration <> 45 or v_price <> 25000 then
    raise exception 'FALLA 1: services no quedo actualizado (% % %)', v_name, v_duration, v_price;
  end if;
  if v_branch_duration <> 45 or v_branch_price <> 25000 then
    raise exception 'FALLA 2: branch_services no quedo sincronizado (% %)', v_branch_duration, v_branch_price;
  end if;

  -- 2. Desactivar deja active=false en ambas tablas.
  perform public.set_service_active(v_branch_id, v_service_id, false);

  select s.active, bs.active into v_tenant_active, v_branch_active
  from public.services s
  join public.branch_services bs on bs.service_id = s.id and bs.branch_id = v_branch_id
  where s.id = v_service_id;

  if v_tenant_active or v_branch_active then
    raise exception 'FALLA 3: el servicio debio quedar inactivo en ambas tablas.';
  end if;

  -- 3. get_services_for_management SI debe mostrarlo, inactivo incluido.
  select count(*) into v_filas
  from public.get_services_for_management(v_branch_id)
  where service_id = v_service_id and active = false;

  if v_filas <> 1 then
    raise exception 'FALLA 4: get_services_for_management debio mostrar el servicio inactivo.';
  end if;

  -- 4. Reactivar vuelve a dejarlo disponible.
  perform public.set_service_active(v_branch_id, v_service_id, true);

  select s.active into v_tenant_active
  from public.services s where s.id = v_service_id;

  if not v_tenant_active then
    raise exception 'FALLA 5: el servicio debio reactivarse.';
  end if;

  -- 5. Editar y desactivar/reactivar el estilista real.
  perform public.update_stylist(
    v_branch_id, v_stylist_id, 'Nicolas Alonso Editado', '3009999999', 'Barba y color'
  );

  select name, phone, specialty into v_name, v_phone, v_specialty
  from public.stylists where id = v_stylist_id;

  if v_name <> 'Nicolas Alonso Editado' or v_phone <> '3009999999' then
    raise exception 'FALLA 6: stylists no quedo actualizado (% %)', v_name, v_phone;
  end if;

  perform public.set_stylist_active(v_branch_id, v_stylist_id, false);

  select st.active, bst.active into v_tenant_active, v_branch_active
  from public.stylists st
  join public.branch_stylists bst on bst.stylist_id = st.id and bst.branch_id = v_branch_id
  where st.id = v_stylist_id;

  if v_tenant_active or v_branch_active then
    raise exception 'FALLA 7: el estilista debio quedar inactivo en ambas tablas.';
  end if;

  perform public.set_stylist_active(v_branch_id, v_stylist_id, true);

  -- 6. Un usuario de otro tenant no puede editar nada aqui.
  perform set_config('request.jwt.claim.sub', v_other_user_id::text, true);

  begin
    perform public.update_service(
      v_branch_id, v_service_id, 'Intento ajeno', 'Cabello', 30, 10000, true
    );
    raise exception 'FALLA 8: un usuario de otro tenant no debio poder editar aqui.';
  exception
    when others then
      if sqlerrm not ilike '%contexto de sede no esta disponible%' then
        raise;
      end if;
  end;

  raise notice 'Editar/desactivar catalogo: 8 de 8 verificaciones aprobadas.';
end;
$$;

rollback;
