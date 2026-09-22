-- AG (parte 1 de 2): el precio es de la sede, y el camino del negocio se cierra.
--
-- DE DONDE SALE
--
-- El hallazgo AG decia que la ficha del negocio ensenya cifras que ya no
-- deciden nada, y ofrecia dos caminos: rotularlas o retirarlas. El propietario
-- eligio un tercero, mas grande y mejor, el 22-sep:
--
--   "que tan complicado es retirar el precio acordado por negocio y dejarlo
--    por sede, al final es asi como se haria en la realidad"
--
-- Tiene razon: un salon no negocia "un precio del negocio", negocia cada
-- local. Desde D-239 quien cobra es la sede; el precio del negocio quedo
-- flotando sin cobrar nada.
--
-- LO QUE SE MIDIO ANTES DE TOCAR NADA
--
--   * **11 funciones vivas** tocan el precio del negocio, pero solo **3**
--     estan en el camino del dinero.
--   * **Los tres negocios de la base tienen exactamente una sede sin precio
--     pactado**, y esa sede cobraria $150.000 mientras el negocio dice otra
--     cosa. Peluqueria Exito decia $4.500 (97% de descuento) y su unica sede
--     habria cobrado $150.000.
--   * **2 cobros hechos en toda la historia**, los dos por el camino del
--     negocio, los dos de $10.000, los dos de negocios de prueba del
--     propietario. **Cero clientes reales afectados.**
--
-- Esa ultima cifra es la que hace este trabajo barato hoy y caro manyana, y
-- es exactamente lo que la regla "NO PAGAR NADA" vino comprando.
--
-- DOS COSAS QUE APARECIERON AL PREGUNTAR, Y NINGUNA ESTABA EN EL REPOSITORIO
--
--   1. **Hay TRES versiones vivas de `beautyos_calcular_cargo_epayco`**: dos
--      en `private` (una recibe el uuid, otra la fila entera) y el envoltorio
--      de `public` (D-214). Se descubrio porque `::regproc` se nego a elegir.
--   2. **El webhook tambien usa ese calculo**, con la version de fila. Si se
--      hubiera "retirado la funcion" a ciegas, un pago confirmado por ePayco
--      habria dejado de registrarse: la clienta paga y el sistema no se
--      entera.
--
-- Por eso aqui **no se retira la funcion: se cierra la puerta**. Se bloquea el
-- unico punto por donde se INICIA un cobro de negocio -- el envoltorio publico
-- que llama `create-epayco-session` -- y se deja intacta toda la maquinaria
-- que LIQUIDA, para que un pago rezagado se registre bien en vez de perderse.
--
--   Negocio (se cierra la entrada): calcular_cargo_epayco -> procesar_evento_epayco
--   Sede    (intacta, es la buena): calcular_cargo_sede   -> procesar_pago_de_sede
--
-- QUE HACE ESTA MIGRACION, Y QUE NO
--
-- Hace: mueve los tres acuerdos a sus sedes y cierra la entrada del cobro por
-- negocio. Con esto **nadie puede cobrar ni ser cobrado por un importe que no
-- corresponde**, que es el peligro entero de AG.
--
-- NO hace, y es deliberado: `platform_approve_tenant` y
-- `platform_update_tenant_pricing` siguen aceptando un precio de negocio. Ya
-- no cobra nada, pero deja volver a crear el desajuste desde el panel. Eso es
-- la **parte 2**, que toca dos funciones de ~100 lineas y la pantalla del
-- panel. Se parte en dos a proposito: esta mitad es la que quita el peligro y
-- se puede verificar sola.
--
-- LOS TRES PRECIOS LOS DECIDIO EL PROPIETARIO, no se dedujeron. Adivinar el
-- precio de un cliente es la misma falta que adivinarle un digito al telefono
-- (D-249).
--
-- Lo prueba el **control 220**.

begin;

-- ---------------------------------------------------------------------------
-- 1. Los tres acuerdos bajan del negocio a su sede
-- ---------------------------------------------------------------------------

do $mover$
declare
  v_filas integer;
  v_huerfanas text;
begin
  -- Peluqueria Exito Prueba: el 97% de descuento del negocio, convertido en
  -- precio pactado de su unica sede. Decision del propietario, 22-sep.
  update public.branch_subscriptions bs
     set price_cop = 4500,
         price_reason = 'Acuerdo del negocio trasladado a su sede: 97% de descuento. AG, 22-sep.',
         updated_at = now()
  from public.branches b
  join public.tenants t on t.id = b.tenant_id
  where bs.branch_id = b.id
    and t.name = 'Peluquería Éxito Prueba'
    and bs.price_cop is null;
  get diagnostics v_filas = row_count;
  if v_filas <> 1 then
    raise exception
      'FALLO al mover el acuerdo de Peluqueria Exito: se esperaba 1 sede sin precio y se tocaron %. La base cambio desde que se midio: revisar antes de seguir.',
      v_filas;
  end if;

  -- Naguara de Unyas: la segunda sede al mismo precio que su hermana.
  update public.branch_subscriptions bs
     set price_cop = 10000,
         price_reason = 'Acuerdo del negocio trasladado a su sede: igual que su sede hermana. AG, 22-sep.',
         updated_at = now()
  from public.branches b
  join public.tenants t on t.id = b.tenant_id
  where bs.branch_id = b.id
    and t.name = 'Naguara de Uñas'
    and bs.price_cop is null;
  get diagnostics v_filas = row_count;
  if v_filas <> 1 then
    raise exception
      'FALLO al mover el acuerdo de Naguara de Unyas: se esperaba 1 sede sin precio y se tocaron %.',
      v_filas;
  end if;

  -- Prueba Barberia Elite: $10.000, que es el dato que el propietario
  -- confirmo como real el 22-sep. **Su motivo de negocio dice "Pionero (50%
  -- de por vida)" y su bandera `is_founder` esta en false**: el texto y el
  -- dato no cuadran, y eso queda SENYALADO, no corregido -- no se arregla un
  -- dato adivinando cual de los dos era verdad.
  update public.branch_subscriptions bs
     set price_cop = 10000,
         price_reason = 'Acuerdo del negocio trasladado a su sede: precio confirmado por el propietario. AG, 22-sep.',
         updated_at = now()
  from public.branches b
  join public.tenants t on t.id = b.tenant_id
  where bs.branch_id = b.id
    and t.name = 'Prueba Barberia Elite'
    and bs.price_cop is null;
  get diagnostics v_filas = row_count;
  if v_filas <> 1 then
    raise exception
      'FALLO al mover el acuerdo de Prueba Barberia Elite: se esperaba 1 sede sin precio y se tocaron %.',
      v_filas;
  end if;

  -- LA GUARDIA. Que no quede ninguna sede viva cobrando tarifa de lista
  -- mientras su negocio tiene un acuerdo: eso es exactamente el desajuste de
  -- AG, y si queda alguna hay que decir cual en vez de dar el trabajo por
  -- hecho. Mismo patron que la guardia de colisiones de D-249.
  select string_agg(t.name || ' / ' || b.name, ', ')
    into v_huerfanas
  from public.branch_subscriptions bs
  join public.branches b on b.id = bs.branch_id
  join public.tenants t on t.id = b.tenant_id
  join public.tenant_subscriptions ts on ts.tenant_id = t.id
  where t.active
    and b.active
    and bs.price_cop is null
    and (ts.price_cop is not null or ts.discount_percent is not null);

  if v_huerfanas is not null then
    raise exception
      'FALLO: estas sedes siguen a tarifa de lista mientras su negocio tiene un acuerdo: %. Hay que decidir su precio antes de cerrar AG.',
      v_huerfanas;
  end if;

  raise notice 'Los tres acuerdos bajaron a su sede, y no queda ninguna sede huerfana.';
end
$mover$;

-- ---------------------------------------------------------------------------
-- 2. La puerta de cobro del negocio se cierra
-- ---------------------------------------------------------------------------
--
-- Se conserva la firma y el tipo de retorno para no romper nada
-- estructuralmente; lo que cambia es que ya no calcula: se niega.
--
-- **Solo el envoltorio publico**, que es lo unico que `create-epayco-session`
-- alcanza. Las dos versiones de `private` se quedan como estan porque de una
-- de ellas cuelga el webhook que liquida.
--
-- El mensaje se escribe para que se entienda en un registro a las tres de la
-- manyana, no para que quede bonito.

create or replace function public.beautyos_calcular_cargo_epayco(
  p_tenant_id uuid,
  p_plan_code text default null
)
returns table (
  monto_cop bigint,
  periodo_inicio timestamptz,
  periodo_fin timestamptz,
  motivo text,
  plan_id_resuelto uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  raise exception
    'El cobro por negocio se retiro (AG, 22-sep): cada sede se cobra por separado. Use beautyos_calcular_cargo_sede(p_branch_id). Negocio solicitado: %.',
    p_tenant_id
    using errcode = '22023';
end;
$$;

comment on function public.beautyos_calcular_cargo_epayco(uuid, text) is
  'RETIRADA el 22-sep (AG): el cobro es por sede desde D-239. Se niega en vez de borrarse para que un intento quede escrito en el registro con su negocio, y para no romper la firma que espera create-epayco-session. La maquinaria que LIQUIDA un pago de negocio (beautyos_procesar_evento_epayco y la version de fila del calculo) sigue viva a proposito: un pago rezagado tiene que poder registrarse. NO ELIMINAR.';

commit;
