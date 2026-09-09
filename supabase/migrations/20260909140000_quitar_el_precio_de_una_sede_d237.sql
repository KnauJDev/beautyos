-- ============================================================================
-- MIGRACIÓN: 20260909140000_quitar_el_precio_de_una_sede_d237.sql
-- DESCRIPCIÓN: Se puede QUITAR el precio pactado de una sede (D-237, paso 9.37).
--
-- POR QUÉ EXISTE
--
-- El 09-sep, recién estrenado el botón de D-236, el propietario intentó lo
-- primero que D-222 promete: dejar una sede adicional **a tarifa vigente**.
-- Borró el precio, guardó, y **no pasó nada**.
--
-- La causa estaba en `platform_set_branch_subscription` desde D-190:
--
--     price_cop = coalesce(p_price_cop, price_cop),
--
-- Pasar `null` **conserva** el valor. La función sabía poner un precio y
-- cambiarlo, pero **nunca quitarlo**. Y el diálogo de D-236 dice literalmente
-- *"Vacío = tarifa vigente del plan"*: una promesa que la base no cumplía.
--
-- Es la regla 16-ter al revés — normalmente la pantalla se queda atrás cuando
-- cambia el servidor; aquí la pantalla prometió algo que el servidor nunca
-- supo hacer.
--
-- QUÉ CAMBIA
--
-- Un parámetro explícito, `p_limpiar_precio`, en vez de darle a `null` un
-- significado nuevo: la función tiene un solo llamador hoy, pero cambiar en
-- silencio lo que significa un `null` es la clase de cosa que muerde meses
-- después. Limpiar y fijar a la vez se rechaza en vez de adivinar cuál gana.
--
-- **Se hace DROP de la firma anterior a propósito.** Añadir un parámetro con
-- valor por defecto crea una función NUEVA y deja viva la vieja: una llamada
-- con cinco argumentos encajaría en las dos y Postgres la rechazaría por
-- ambigua.
--
-- CÓMO SE ESCRIBIÓ
--
-- El cuerpo se **extrajo de la migración de D-190** y solo se le insertó lo
-- nuevo, como en D-232. La regla 10 del apartado 8 existe porque reescribir
-- una función es donde se cuelan los errores.
-- ============================================================================

begin;

drop function if exists public.platform_set_branch_subscription(
  uuid, text, bigint, text, timestamptz
);

create or replace function public.platform_set_branch_subscription(
  p_branch_id uuid,
  p_status text,
  p_price_cop bigint default null,
  p_price_reason text default null,
  p_period_end timestamptz default null,
  -- D-237: sin esto NO habia forma de QUITAR un precio pactado. El coalesce
  -- de abajo conserva el valor cuando llega null, asi que la funcion sabia
  -- poner y cambiar, nunca limpiar. Y D-222 promete que una sede adicional va
  -- a tarifa vigente, que es justo lo que no se podia hacer.
  p_limpiar_precio boolean default false
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: solo la plataforma puede cambiar el estado de pago de una sede.';
  end if;

  if p_status is null or p_status not in (
    'pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled'
  ) then
    raise exception 'Estado invalido: %.', coalesce(p_status, 'null');
  end if;

  if p_price_cop is not null
     and (p_price_reason is null or length(trim(p_price_reason)) = 0) then
    raise exception 'Un precio pactado exige motivo. Mismo criterio que D-136.';
  end if;

  -- Quitar el precio y fijar uno a la vez es contradictorio: se rechaza en
  -- vez de adivinar cual gana.
  if p_limpiar_precio and p_price_cop is not null then
    raise exception 'No se puede limpiar el precio y fijar uno en la misma operacion.';
  end if;

  select tenant_id into v_tenant_id
  from public.branches where id = p_branch_id;

  if v_tenant_id is null then
    raise exception 'La sede no existe.';
  end if;

  update public.branch_subscriptions
  set status = p_status,
      price_cop = case when p_limpiar_precio then null
                       else coalesce(p_price_cop, price_cop) end,
      price_reason = case when p_limpiar_precio then null
                          else coalesce(p_price_reason, price_reason) end,
      current_period_end = coalesce(p_period_end, current_period_end),
      -- La primera activacion se sella una sola vez: sirve para saber si una
      -- sede nunca llego a pagarse o si se cayo despues.
      activated_at = case
        when p_status in ('active', 'trialing') then coalesce(activated_at, now())
        else activated_at
      end,
      updated_at = now()
  where branch_id = p_branch_id;

  if not found then
    raise exception 'La sede no tiene suscripcion registrada.';
  end if;
end;
$$;
revoke all on function public.platform_set_branch_subscription(
  uuid, text, bigint, text, timestamptz, boolean
) from public, anon;

grant execute on function public.platform_set_branch_subscription(
  uuid, text, bigint, text, timestamptz, boolean
) to authenticated;

comment on function public.platform_set_branch_subscription(
  uuid, text, bigint, text, timestamptz, boolean
) is
  'Estado de pago y precio de UNA sede, solo para el dueño de plataforma (D-190). '
  'Desde D-237 admite `p_limpiar_precio` para devolver la sede a la tarifa vigente '
  'del plan, que es lo que promete D-222 para las sedes adicionales. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- Y el lector dice si el precio es PACTADO o el de lista.
--
-- Sin esto, la pantalla no puede distinguir "pactado 150.000" de "sin pactar,
-- lista 150.000": la funcion devuelve el precio EFECTIVO. La unica pista era
-- el texto "Precio de lista" del motivo, y **comparar una cadena pensada para
-- leerse, para decidir sobre dinero, es fragil**: el dia que alguien la
-- traduzca o le quite una tilde, la logica se rompe en silencio.
-- ---------------------------------------------------------------------------

create or replace function public.platform_get_tenant_branches(
  p_tenant_id uuid
)
returns table (
  branch_id uuid,
  branch_name text,
  is_primary boolean,
  branch_active boolean,
  status text,
  al_dia boolean,
  precio_cop bigint,
  motivo_precio text,
  tiene_precio_pactado boolean,
  current_period_end timestamptz,
  activated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    b.id,
    b.name,
    b.is_primary,
    b.active,
    bs.status,
    -- Misma regla que ve el salon en su Configuracion (D-190). "Al dia" no es
    -- lo mismo que "activa": una sede puede estar operando y en mora.
    bs.status in ('active', 'trialing'),
    coalesce(bs.price_cop, p.price_cop),
    coalesce(bs.price_reason, 'Precio de lista'),
    bs.price_cop is not null,
    bs.current_period_end,
    bs.activated_at
  from public.branches b
  join public.branch_subscriptions bs on bs.branch_id = b.id
  join public.tenant_subscriptions ts on ts.tenant_id = b.tenant_id
  join public.plans p on p.id = ts.plan_id
  where b.tenant_id = p_tenant_id
  order by b.is_primary desc, b.created_at;
end;
$$;

revoke all on function public.platform_get_tenant_branches(uuid) from public, anon;
grant execute on function public.platform_get_tenant_branches(uuid) to authenticated;

comment on function public.platform_get_tenant_branches(uuid) is
  'Estado de pago de las sedes de un negocio, para el dueño de plataforma (D-235). '
  'Desde D-237 dice ademas si el precio es PACTADO o el de lista, para que la '
  'pantalla no tenga que deducirlo comparando un texto. NO ELIMINAR.';

commit;
