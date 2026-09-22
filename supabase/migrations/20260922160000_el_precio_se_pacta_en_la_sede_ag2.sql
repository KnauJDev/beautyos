-- AG (parte 2 de 2): el precio se pacta en la sede, tambien al aprobar.
--
-- LO QUE LA PARTE 1 DEJO ABIERTO
--
-- La parte 1 cerro la puerta del cobro por negocio y bajo los tres acuerdos a
-- sus sedes. Pero el panel seguia dejando fijar un precio de negocio, y --lo
-- grave-- **la funcion que aprueba clientes nuevos seguia escribiendo un 50%
-- de descuento en silencio**:
--
--   if p_is_founder is true then
--     v_discount_percent := coalesce(v_discount_percent, 50.00);
--     if v_price_reason is null then
--       v_price_reason := 'Pionero (50% de por vida)';
--     end if;
--   end if;
--
-- Es el 50% que **D-221 quito el 07-sep**, y para el que existe el control
-- 207... que vigila `platform_update_tenant_pricing`. **Nadie miro esta otra
-- puerta**, y por eso sobrevivio quince dias.
--
-- Y explica el dato raro que aparecio midiendo AG: *Prueba Barberia Elite*
-- lleva el motivo `'Pionero (50% de por vida)'` con `is_founder` en false.
-- **No lo escribio nadie a mano: lo escribio esta funcion al aprobarlo.**
--
-- LA CONSECUENCIA, QUE NO ERA TEORICA
--
-- Desde la parte 1 el descuento del negocio no cobra nada. Asi que aprobar a
-- un pionero le habria prometido la mitad, dejado escrito en su ficha que se
-- la dieron, y cobrado los $150.000 completos en su sede. **El desajuste de
-- AG naciendo de nuevo con cada cliente**, justo antes de invitar a los diez
-- socios.
--
-- LO QUE SE DECIDIO, Y POR QUE
--
-- **Aprobar sigue aceptando un precio, pero lo escribe en la sede principal.**
-- Se descarto obligar a un segundo paso ("aprueba y luego fija el precio"):
-- negociar el precio es parte de aprobar, y el dia que se olvidara el segundo
-- paso ese cliente arrancaria a tarifa completa -- el mismo fallo, movido de
-- sitio.
--
-- **El descuento porcentual se rechaza, no se convierte.** El precio de una
-- sede se pacta en pesos: `beautyos_precio_efectivo_sede` es
-- `coalesce(bs.price_cop, lista)` y no tiene donde guardar un porcentaje.
-- Convertirlo (un 50% de $150.000 en $75.000 pactados) parece util y **pierde
-- el significado**: un descuento sigue a la tarifa cuando la tarifa cambia, y
-- un precio pactado no. Asi que se para y se dice como expresarlo.
--
-- **`is_founder` se queda como etiqueta pura**, que es lo que D-221 dijo que
-- era. Marca quien es pionero; no inventa ningun porcentaje. Si se marca
-- pionero sin decir cuanto paga, **se para y lo pide**.
--
-- COMO SE ESCRIBIO
--
-- Texto vivo extraido con
-- `supabase/sql/intervenciones/extraer_aprobacion_y_precio_de_sede.sql` y
-- comparado linea por linea (D-119, D-122, D-123).
--
-- Lo prueba el **control 221**, que vigila **las dos puertas** -- que es justo
-- lo que al 207 le falto.

begin;

-- ---------------------------------------------------------------------------
-- 1. Aprobar un negocio: el precio va a su sede principal
-- ---------------------------------------------------------------------------

create or replace function public.platform_approve_tenant(
  p_tenant_id uuid,
  p_plan_code text default 'pro',
  p_is_founder boolean default false,
  p_price_cop bigint default null,
  p_discount_percent numeric default null,
  p_discount_ends_at timestamptz default null,
  p_price_reason text default null,
  p_trial_days integer default 21
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_plan_id uuid;
  v_trial_days integer := greatest(1, coalesce(p_trial_days, 21));
  v_trial_ends_at timestamptz := now() + (v_trial_days || ' days')::interval;
  v_subscription public.tenant_subscriptions%rowtype;
  v_current_status text;
  v_price_reason text := nullif(trim(coalesce(p_price_reason, '')), '');
  v_branch_id uuid;   -- AG: la sede donde de verdad vive el precio
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede aprobar negocios.';
  end if;

  -- Guard de Estado (D-139 / Auditoría Claude):
  -- Solo se pueden aprobar solicitudes en estado 'pending' o 'rejected'.
  select ts.status into v_current_status
  from public.tenant_subscriptions ts
  where ts.tenant_id = p_tenant_id;

  if v_current_status is null then
    raise exception 'No se encontro la suscripcion para el negocio indicado.';
  end if;

  if v_current_status not in ('pending', 'rejected') then
    raise exception 'No se puede aprobar un negocio con estado "%". Solo se pueden aprobar solicitudes pendientes o previamente rechazadas.', v_current_status;
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = lower(trim(p_plan_code)) and p.status = 'active';

  if v_plan_id is null then
    raise exception 'El plan especificado (%) no existe o no esta activo.', p_plan_code;
  end if;

  -- AG: AQUI ESTABA EL 50%. Se retira entero. D-221 ya lo habia quitado de
  -- `platform_update_tenant_pricing` el 07-sep; esta puerta se quedo abierta.
  -- Lo que queda en su lugar es la misma exigencia de aquella decision: un
  -- pionero necesita que se diga cuanto paga.
  if p_is_founder is true and p_price_cop is null then
    raise exception
      'Un negocio pionero necesita su precio pactado. La tarifa de pionero se negocia una a una (D-188, D-189); no hay un porcentaje por defecto. Indica cuanto paga su sede al mes.';
  end if;

  -- AG: el descuento porcentual se retira. El precio de una sede se pacta en
  -- pesos, y convertir el porcentaje perderia su significado -- un descuento
  -- sigue a la tarifa cuando la tarifa cambia, un precio pactado no.
  if p_discount_percent is not null or p_discount_ends_at is not null then
    raise exception
      'El descuento porcentual se retiro (AG): el precio de cada sede se pacta en pesos. Para un %% de descuento, calcula el importe y pactalo como precio de la sede.';
  end if;

  if p_price_cop is not null and v_price_reason is null then
    raise exception 'Debes ingresar un motivo para el precio especial.';
  end if;

  -- AG: el negocio deja de llevar precio. Se escriben nulos a proposito, no
  -- se "conservan": desde la parte 1 esos campos no cobran nada, y dejar un
  -- numero ahi es volver a tener dos precios para lo mismo.
  update public.tenant_subscriptions
  set
    plan_id = v_plan_id,
    status = 'trialing',
    trial_ends_at = v_trial_ends_at,
    current_period_start = now(),
    is_founder = coalesce(p_is_founder, false),
    price_cop = null,
    discount_percent = null,
    discount_ends_at = null,
    price_reason = null,
    updated_at = now()
  where tenant_id = p_tenant_id
  returning * into v_subscription;

  if not found then
    raise exception 'No se encontro la suscripcion para el negocio indicado.';
  end if;

  update public.tenants
  set
    active = true,
    rejection_reason = null
  where id = p_tenant_id;

  -- AG: y el precio negociado baja a la sede principal, que es quien cobra
  -- desde D-239.
  if p_price_cop is not null then
    select b.id into v_branch_id
    from public.branches b
    where b.tenant_id = p_tenant_id
      and b.is_primary
    order by b.created_at
    limit 1;

    if v_branch_id is null then
      raise exception
        'El negocio no tiene sede principal, y el precio se pacta en la sede. Revisar antes de aprobar: aprobar sin poder guardar el precio dejaria al cliente a tarifa completa.';
    end if;

    -- La suscripcion de la sede puede no existir todavia. Se crea antes de
    -- escribir en vez de dar por hecho que el disparador ya corrio.
    insert into public.branch_subscriptions (tenant_id, branch_id, status)
    select p_tenant_id, v_branch_id, 'pending'
    where not exists (
      select 1 from public.branch_subscriptions bs where bs.branch_id = v_branch_id
    );

    update public.branch_subscriptions
       set price_cop = p_price_cop,
           price_reason = v_price_reason,
           updated_at = now()
     where branch_id = v_branch_id;
  end if;

  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    payload,
    created_by
  ) values (
    p_tenant_id,
    v_subscription.id,
    'tenant_approved',
    jsonb_build_object(
      'plan_code', p_plan_code,
      'is_founder', coalesce(p_is_founder, false),
      'trial_days', v_trial_days,
      'trial_ends_at', v_trial_ends_at,
      'price_cop', p_price_cop,
      'price_reason', v_price_reason,
      'branch_id', v_branch_id,
      'previous_status', v_current_status
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

comment on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer) is
  'Aprueba un negocio. Desde AG (22-sep) el precio negociado se escribe en la SEDE PRINCIPAL, no en el negocio: desde D-239 quien cobra es la sede. Ya no inventa el 50% de pionero que D-221 habia quitado de la otra puerta. El descuento porcentual se rechaza: el precio de una sede se pacta en pesos. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. Modificar tarifa desde el panel: plan y etiqueta, no precio
-- ---------------------------------------------------------------------------

create or replace function public.platform_update_tenant_pricing(
  p_tenant_id uuid,
  p_plan_code text default 'pro',
  p_is_founder boolean default false,
  p_price_cop bigint default null,
  p_discount_percent numeric default null,
  p_price_reason text default null
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_plan_id uuid;
  v_subscription public.tenant_subscriptions%rowtype;
  v_normalized_plan text := lower(trim(coalesce(p_plan_code, 'pro')));
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede modificar tarifas y planes.';
  end if;

  -- Mapeo de códigos legacy (D-188): los planes anteriores retirados
  -- (profesional, basico, business) resuelven al plan único activo 'pro'.
  if v_normalized_plan in ('profesional', 'basico', 'business', 'pro', '') then
    v_normalized_plan := 'pro';
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = v_normalized_plan and p.status = 'active';

  -- Fallback de plan (D-212): si el código no existe, se usa el 'pro' activo.
  -- Esto SÍ se conserva: resolver un plan retirado a su sustituto no inventa
  -- dinero, solo apunta al único plan que queda.
  if v_plan_id is null then
    select p.id into v_plan_id
    from public.plans p
    where p.code = 'pro' and p.status = 'active'
    limit 1;
  end if;

  if v_plan_id is null then
    raise exception 'No hay un plan activo disponible en la plataforma.';
  end if;

  -- AG: el precio del negocio se retiro. Aqui ya no se guarda ninguno, y se
  -- dice a la cara en vez de aceptarlo y no cobrarlo -- que es lo que pasaba
  -- entre la parte 1 y esta.
  if p_price_cop is not null or p_discount_percent is not null then
    raise exception
      'El precio ya no se pacta por negocio (AG, 22-sep): se pacta en cada sede, que es quien cobra desde D-239. Usa el boton Pago de la sede que quieras cambiar.';
  end if;

  -- D-221 sigue en pie y aqui se simplifica: el pionero es una etiqueta. La
  -- guarda que exigia precio o descuento vivia aqui porque aqui se fijaba el
  -- precio; ahora se fija en la sede y esa exigencia se mudo con el, a
  -- `platform_approve_tenant`.
  --
  -- **Las tres columnas del precio NO se tocan, y es deliberado.** Escribir
  -- nulos aqui borraria el acuerdo historico de un negocio que ya existe --el
  -- que la ficha ensenya rotulado como "no se cobra"-- cada vez que se le
  -- cambiara el plan. Esta funcion dejo de administrar el precio; eso no es
  -- lo mismo que tener permiso para borrarlo.
  update public.tenant_subscriptions
  set
    plan_id = v_plan_id,
    is_founder = p_is_founder,
    updated_at = now()
  where tenant_id = p_tenant_id
  returning * into v_subscription;

  if not found then
    raise exception 'No se encontró suscripción para el tenant especificado.';
  end if;

  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    provider,
    payload,
    created_by
  ) values (
    p_tenant_id,
    v_subscription.id,
    'pricing_updated',
    'platform_admin',
    jsonb_build_object(
      'plan_code', v_normalized_plan,
      'is_founder', p_is_founder,
      'price_reason', nullif(trim(coalesce(p_price_reason, '')), '')
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

comment on function public.platform_update_tenant_pricing(uuid, text, boolean, bigint, numeric, text) is
  'Cambia el plan y la etiqueta de pionero de un negocio. Desde AG (22-sep) NO acepta precio ni descuento: eso se pacta en cada sede con platform_set_branch_subscription, porque desde D-239 quien cobra es la sede. Se niega en vez de aceptarlo en silencio. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. El rastro que dejo el 50% automatico: se senyala, no se borra
-- ---------------------------------------------------------------------------
--
-- *Prueba Barberia Elite* lleva el motivo `'Pionero (50% de por vida)'` que
-- escribio esta misma aprobacion, sin descuento y con `is_founder` en false.
-- El propietario confirmo el 22-sep que **su dato real es el precio pactado
-- de $10.000**, ya trasladado a su sede en la parte 1.
--
-- **Aqui se escribio un UPDATE que lo limpiaba y se retiro antes de aplicar
-- nada**, por dos razones que conviene dejar escritas:
--
--   1. **No habria funcionado.** Filtraba por `price_cop is null and
--      discount_percent is null`, y ese negocio tiene pactado 10.000: no
--      habria tocado ni una fila. Un UPDATE que no alcanza lo que dice
--      limpiar es peor que no tenerlo, porque el registro afirma que se
--      limpio.
--   2. **No se pidio.** El propietario dijo cual es el dato verdadero; no
--      dijo que se borrara el otro. Un motivo historico en un campo que ya
--      no cobra es un rastro, y los rastros se leen -- es la misma razon por
--      la que el celular de nueve digitos de D-249 se senyalo en vez de
--      adivinarse.
--
-- Ese texto ahora se ensenya bajo el rotulo *"Acuerdo del negocio -- no se
-- cobra"*, que es exactamente lo que es.

commit;
