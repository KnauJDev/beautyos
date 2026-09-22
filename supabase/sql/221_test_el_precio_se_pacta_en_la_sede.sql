-- CONTROL 221: El precio se pacta en la sede, por las DOS puertas.
--              Hallazgo AG, parte 2.
--
-- POR QUE ESTE ARCHIVO EXISTE, Y POR QUE VIGILA DOS PUERTAS
--
-- D-221 decidio el 07-sep que **el pionero es una etiqueta, no un 50%**, y
-- quito la asignacion automatica de `platform_update_tenant_pricing`. Nacio
-- el **control 207** para vigilarlo, y hace bien su trabajo.
--
-- Pero el mismo 50% vivia en **`platform_approve_tenant`**, que nadie miro:
--
--   if p_is_founder is true then
--     v_discount_percent := coalesce(v_discount_percent, 50.00);
--     ...
--
-- Sobrevivio quince dias. Se encontro el 22-sep respondiendo a una pregunta
-- del propietario -- *"puedo seguir definiendo precios como yo quiera a
-- quienes entren en adelante?"* --, y es lo que habria hecho que el primer
-- pionero de los diez socios naciera con la mitad prometida y la tarifa
-- completa cobrada.
--
-- **La leccion, y es la razon de ser de este archivo:** un control que
-- vigila una funcion no vigila una regla. Este mira las dos puertas por las
-- que se fija dinero, y falla si el 50% reaparece por cualquiera.
--
-- Que valida, transaccionalmente:
--   1. **Aprobar un pionero sin decir cuanto paga se niega**, y el mensaje
--      pide el precio en vez de inventarlo.
--   2. **Aprobar NO inventa ningun descuento.** Ni el 50%, ni ninguno.
--   3. **El precio negociado al aprobar aterriza en la SEDE**, no en el
--      negocio, y con su motivo.
--   4. Y la sede cobra ese precio de verdad.
--   5. **El descuento porcentual se rechaza por las dos puertas**, diciendo
--      como expresarlo.
--   6. **Modificar la tarifa del negocio ya no acepta precio**, y lo dice.
--   7. Pero si deja cambiar el plan y la etiqueta de pionero.
--   8. **Y NO borra el acuerdo historico** de un negocio que ya lo tenia.
--   9. El 50% no esta escrito en ninguna de las dos funciones.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\221_test_el_precio_se_pacta_en_la_sede.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan       uuid;
  v_tenant     uuid;
  v_branch     uuid;
  v_dueno      uuid := gen_random_uuid();
  v_capturo    boolean;
  v_error      text;
  v_precio     bigint;
  v_motivo     text;
  v_monto      bigint;
  v_pionero    boolean;
  v_cuerpo     text;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  -- Quien aprueba es el duenyo de la plataforma.
  insert into auth.users (id, email) values (v_dueno, 'plataforma_test221@salonymas.com')
  on conflict (id) do nothing;

  -- La tabla es `platform_operators`. El fixture se copio del control 207,
  -- que ya lo hace bien, en vez de escribirlo de memoria: al escribir este
  -- archivo se invento `platform_admins`, que no existe.
  insert into public.platform_operators (user_id, role, active)
  values (v_dueno, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  -- Un negocio pendiente de aprobar, con su sede principal.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 221', 'barberia', 'c221@salonymas.com', '3000000221', false)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status)
  values (v_tenant, v_plan, 'pending');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C221 sede principal', 'c221-principal', true, true)
  returning id into v_branch;

  -- 1. Un pionero sin precio se niega
  v_capturo := false;
  begin
    perform public.platform_approve_tenant(
      v_tenant, 'pro', true, null, null, null, null, 21);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception
      'FALLO 1: se aprobo un pionero sin decir cuanto paga. Antes eso le ponia un 50%% en silencio, que es el fallo entero.';
  end if;
  if v_error not ilike '%precio%' then
    raise exception 'FALLO 1b: se nego, pero sin pedir el precio. Dijo: %', v_error;
  end if;
  raise notice 'OK 1   aprobar un pionero sin precio se niega, y pide el precio';

  -- 5a. El descuento porcentual se rechaza al aprobar
  v_capturo := false;
  begin
    perform public.platform_approve_tenant(
      v_tenant, 'pro', false, null, 50, null, 'Descuento de prueba', 21);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception
      'FALLO 5: se acepto un descuento porcentual al aprobar. Desde AG el precio de la sede se pacta en pesos y ese descuento no cobraria nada.';
  end if;
  raise notice 'OK 5a  el descuento porcentual se rechaza al aprobar';

  -- 2 y 3. Aprobar con precio: no inventa descuento, y el precio va a la sede
  perform public.platform_approve_tenant(
    v_tenant, 'pro', true, 75000, null, null, 'Pionero fundador, control 221', 21);

  select ts.discount_percent, ts.price_cop, ts.is_founder
    into v_precio, v_motivo, v_pionero
  from public.tenant_subscriptions ts where ts.tenant_id = v_tenant;

  if v_precio is not null then
    raise exception 'FALLO 2: aprobar invento un descuento de %. D-221 lo retiro el 07-sep.', v_precio;
  end if;
  if v_motivo is not null then
    raise exception 'FALLO 2b: el precio se escribio en el NEGOCIO (%). Tiene que ir a la sede: es quien cobra desde D-239.', v_motivo;
  end if;
  if not v_pionero then
    raise exception 'FALLO 2c: se perdio la etiqueta de pionero. Es una etiqueta, pero es la etiqueta correcta.';
  end if;
  raise notice 'OK 2   aprobar no inventa descuento, y el negocio queda sin precio';

  select bs.price_cop, bs.price_reason
    into v_precio, v_motivo
  from public.branch_subscriptions bs where bs.branch_id = v_branch;

  if v_precio is distinct from 75000 then
    raise exception
      'FALLO 3: la sede principal quedo con precio % y se aprobo con 75.000. Si no aterriza aqui, el cliente arranca a tarifa completa.',
      coalesce(v_precio::text, 'ninguno');
  end if;
  if v_motivo is null or v_motivo not ilike '%pionero%' then
    raise exception 'FALLO 3b: el precio de la sede quedo sin motivo, o sin el que se escribio. Dijo: %', coalesce(v_motivo, 'nada');
  end if;
  raise notice 'OK 3   el precio negociado aterriza en la sede, con su motivo';

  -- 4. Y la sede cobra ese precio
  select c.monto_cop into v_monto
  from private.beautyos_calcular_cargo_sede(v_branch) c;

  if v_monto is distinct from 75000 then
    raise exception 'FALLO 4: la sede calculo un cargo de % y su precio pactado es 75.000.', coalesce(v_monto::text, 'nada');
  end if;
  raise notice 'OK 4   la sede cobra el precio que se pacto al aprobar';

  -- 5b. El descuento tambien se rechaza por la otra puerta
  v_capturo := false;
  begin
    perform public.platform_update_tenant_pricing(v_tenant, 'pro', true, null, 50, 'Otro intento');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 5b: la otra puerta si acepto un descuento porcentual.';
  end if;
  raise notice 'OK 5b  el descuento porcentual se rechaza tambien al modificar';

  -- 6. Modificar la tarifa ya no acepta precio
  v_capturo := false;
  begin
    perform public.platform_update_tenant_pricing(v_tenant, 'pro', true, 60000, null, 'Precio del negocio');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception
      'FALLO 6: todavia se puede pactar un precio de negocio. Ese precio no cobra nada desde AG: aceptarlo en silencio es prometer algo que no pasa.';
  end if;
  if v_error not ilike '%sede%' then
    raise exception 'FALLO 6b: se nego, pero sin decir donde se pacta ahora. Dijo: %', v_error;
  end if;
  raise notice 'OK 6   modificar la tarifa ya no acepta precio, y dice donde va';

  -- 7. Pero si deja cambiar plan y etiqueta
  perform public.platform_update_tenant_pricing(v_tenant, 'pro', false, null, null, null);

  select ts.is_founder into v_pionero
  from public.tenant_subscriptions ts where ts.tenant_id = v_tenant;
  if v_pionero then
    raise exception 'FALLO 7: no se pudo quitar la etiqueta de pionero.';
  end if;
  raise notice 'OK 7   el plan y la etiqueta si se pueden cambiar';

  -- 8. Y no borra el acuerdo historico de quien ya lo tenia
  update public.tenant_subscriptions
     set price_cop = 12345, price_reason = 'Acuerdo historico del control 221'
   where tenant_id = v_tenant;

  perform public.platform_update_tenant_pricing(v_tenant, 'pro', true, null, null, null);

  select ts.price_cop, ts.price_reason into v_precio, v_motivo
  from public.tenant_subscriptions ts where ts.tenant_id = v_tenant;

  if v_precio is distinct from 12345 then
    raise exception
      'FALLO 8: cambiar el plan borro el acuerdo historico del negocio (quedo %). Dejar de administrar un dato no es permiso para borrarlo.',
      coalesce(v_precio::text, 'nulo');
  end if;
  raise notice 'OK 8   cambiar el plan no borra el acuerdo historico';

  -- 9. El 50% no esta escrito en ninguna de las dos
  --
  -- Se mira el CUERPO, pero solo para el 50: un numero magico no se puede
  -- ejercitar sin aprobar un pionero de verdad, y eso ya lo hace la 2. Es la
  -- misma mezcla que el control 207, que tambien mira su texto.
  select string_agg(pg_get_functiondef(p.oid), chr(10))
    into v_cuerpo
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('platform_approve_tenant', 'platform_update_tenant_pricing');

  if v_cuerpo ~ 'coalesce\s*\(\s*v_discount_percent\s*,\s*50' then
    raise exception
      'FALLO 9: el 50%% automatico volvio a alguna de las dos puertas. Es el que D-221 quito y el que sobrevivio quince dias en la que nadie miraba.';
  end if;
  raise notice 'OK 9   el 50%% no esta en ninguna de las dos puertas';

  raise notice ' ';
  raise notice 'CONTROL 221: 9 de 9 en verde';
end
$ctrl$;

rollback;
