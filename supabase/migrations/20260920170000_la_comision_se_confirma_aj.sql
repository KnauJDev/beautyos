-- AJ: la comision deja de nacer decidida, y se nota que nadie la decidio.
--
-- EL FALLO
--
-- Un salon nace con una comision del **40%** que nadie le pide confirmar, y
-- esa cifra decide lo que gana una persona. El registro hace
-- `insert into public.commission_policies (tenant_id) values (...)` -- una
-- sola columna --, asi que **el 40 no lo decide ninguna funcion: lo hereda del
-- default de la tabla**. Y *Primeros pasos* pide servicios, equipo, horario y
-- primera cita; la comision no aparece.
--
-- **Probado con dinero real el 18-sep:** ticket de $18.000, y en *Mi panel
-- financiero* del estilista aparecieron **$7.200**. El 40% exacto. Una cuenta
-- por pagar a una persona, generada sin que nadie la aprobara nunca. Y **la
-- ve antes el estilista que el duenyo**, porque el duenyo no tiene esa
-- pantalla.
--
-- LO QUE SE MIDIO ANTES DE TOCAR NADA
--
-- En la base hay **3 politicas, las 3 en el 40%, y 0 tocadas desde que
-- nacieron**. No es un problema teorico: nadie en toda la base ha confirmado
-- nunca su comision.
--
-- LA DECISION DEL PROPIETARIO: avisar fuerte, no bloquear
--
-- Se le ofrecio que la politica naciera en 0% hasta que alguien la fijara, y
-- lo descarto con buen criterio: **0% tambien es un numero inventado**, solo
-- que mas barato para el salon y igual de silencioso para el estilista. Asi
-- que la comision se sigue generando, pero la falta de confirmacion se ve en
-- los tres sitios donde importa: *Primeros pasos*, *Configuracion* y **el
-- panel del estilista**, que es quien tiene el dinero en juego.
--
-- POR QUE NO SE RELLENA `confirmed_at` DE LOS QUE YA ESTAN
--
-- Se penso deducirlo de `updated_at > created_at`, que parece evidencia de que
-- alguien guardo. **No lo es:** el sembrado `supabase/sql/016` hace
-- `on conflict do update set ... updated_at = now()`, asi que habria marcado
-- como confirmado un salon que nunca lo hizo. Y la medicion lo dejo sin
-- objeto: **0 politicas tocadas**, no hay nada que preservar. Todas nacen sin
-- confirmar, y confirmar cuesta un clic.
--
-- LA TABLA ENTRA EN UNA MIGRACION (parte de AI)
--
-- `commission_policies` nacio en `supabase/sql/015`, de julio, que **no es una
-- migracion**: por eso el 40 estaba escrito en un sitio que nadie lee. Aqui se
-- escribe su forma viva, extraida del catalogo el 20-sep, con el default
-- comentado.
--
-- **Lo que esto NO arregla, dicho a proposito:** `supabase db reset` sigue sin
-- funcionar. Migraciones anteriores insertan en esta tabla, y esta creacion va
-- despues. Deja el 40 donde se lee y se revisa; **no cierra AI**.
--
-- COMO SE ESCRIBIO
--
-- Texto vivo extraido con
-- `supabase/sql/intervenciones/extraer_comisiones_y_primeros_pasos.sql` y
-- comparado linea por linea (D-119, D-122, D-123): las tres funciones salieron
-- **identicas** al repositorio -- 26, 30 y 71 lineas --, asi que se reescriben
-- desde el. Cada cambio va marcado con `-- AJ:`.
--
-- **Los dos lectores llevan `drop` antes**, porque les cambia el tipo de
-- retorno. Saltarselo fue lo que tumbo la primera pasada de D-237.
--
-- Lo prueba el **control 219**.

begin;

-- ---------------------------------------------------------------------------
-- 1. La tabla, tal como esta viva hoy, escrita donde se lee
-- ---------------------------------------------------------------------------

create table if not exists public.commission_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  commission_type text not null default 'percentage'
    check (commission_type in ('percentage', 'fixed')),

  -- ESTE ES EL 40 DEL HALLAZGO AJ. Es un default de tabla, no una decision de
  -- ninguna funcion: el registro inserta solo `tenant_id` y hereda el resto.
  -- Existe porque un salon tiene que poder cobrar el primer dia, pero desde
  -- AJ **nace sin confirmar** y se le pide al duenyo que lo mire.
  commission_percentage numeric not null default 40
    check (commission_percentage >= 0 and commission_percentage <= 100),

  fixed_commission_amount numeric not null default 0
    check (fixed_commission_amount >= 0),
  applies_after_discount boolean not null default true,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id)
);

-- RLS encendida y **cero politicas, a proposito**: a esta tabla solo se llega
-- por funciones `security definer` (el perimetro de D-177). Asi esta viva hoy.
alter table public.commission_policies enable row level security;

-- La puso D-175 (H-08) por el barrido de columnas de dinero. Se repite aqui
-- para que la creacion describa la tabla entera; si ya existe, no pasa nada.
do $$
begin
  alter table public.commission_policies
    add constraint commission_policies_fixed_commission_amount_es_entero_check
    check (fixed_commission_amount = round(fixed_commission_amount)) not valid;
exception when duplicate_object then
  null;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. La marca de confirmada
-- ---------------------------------------------------------------------------

alter table public.commission_policies
  add column if not exists confirmed_at timestamptz;

comment on column public.commission_policies.confirmed_at is
  'Cuando el duenyo o el admin guardo la comision a proposito (AJ, 20-sep). Null = sigue siendo el default de 40% que nadie aprobo. NO se rellena por deduccion: `updated_at` lo mueve tambien el sembrado 016.';

-- ---------------------------------------------------------------------------
-- 3. Guardar la comision es confirmarla
-- ---------------------------------------------------------------------------

create or replace function public.update_commission_policy(
  p_branch_id uuid,
  p_commission_type text,
  p_commission_percentage numeric,
  p_fixed_commission_amount numeric,
  p_applies_after_discount boolean,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if p_commission_type not in ('percentage', 'fixed') then
    raise exception 'Tipo de comision no valido.';
  end if;

  if p_commission_percentage is null or p_commission_percentage < 0 or p_commission_percentage > 100 then
    raise exception 'El porcentaje de comision debe estar entre 0 y 100.';
  end if;

  if p_fixed_commission_amount is null or p_fixed_commission_amount < 0 then
    raise exception 'El valor fijo de comision no puede ser negativo.';
  end if;

  update public.commission_policies
     set commission_type = p_commission_type,
         commission_percentage = p_commission_percentage,
         fixed_commission_amount = p_fixed_commission_amount,
         applies_after_discount = p_applies_after_discount,
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         -- AJ: guardar ES confirmar. Se pone siempre, no solo la primera vez:
         -- volver a mirar la cifra y dejarla igual tambien es aprobarla, y
         -- exigir que cambie para contar obligaria a inventar un cambio.
         confirmed_at = now(),
         updated_at = now()
   where tenant_id = v_tenant_id
     and active = true;

  if not found then
    raise exception 'No existe una politica de comision activa para este negocio.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. El lector dice si esta confirmada
-- ---------------------------------------------------------------------------

drop function if exists public.get_commission_policy();

create or replace function public.get_commission_policy()
returns table (
  id uuid,
  commission_type text,
  commission_percentage numeric,
  fixed_commission_amount numeric,
  applies_after_discount boolean,
  notes text,
  confirmed_at timestamptz   -- AJ
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver las políticas de comisión.';
  end if;

  return query
  select
    cp.id,
    cp.commission_type,
    cp.commission_percentage,
    cp.fixed_commission_amount,
    cp.applies_after_discount,
    cp.notes,
    cp.confirmed_at   -- AJ
  from public.commission_policies cp
  join public.tenants t
    on t.id = cp.tenant_id
  where cp.tenant_id = current_tenant_id
    and cp.active = true
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_commission_policy() from anon;
revoke execute on function public.get_commission_policy() from public;
grant execute on function public.get_commission_policy() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Primeros pasos gana el quinto: confirmar la comision
-- ---------------------------------------------------------------------------

drop function if exists public.get_onboarding_progress(uuid);

create or replace function public.get_onboarding_progress(p_branch_id uuid)
returns table (
  tiene_servicios boolean,
  tiene_equipo boolean,
  tiene_horario boolean,
  tiene_primera_cita boolean,
  tiene_comision boolean,   -- AJ
  pasos_completos integer,
  pasos_totales integer,
  descartado boolean
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
  v_servicios boolean;
  v_equipo boolean;
  v_horario boolean;
  v_cita boolean;
  v_comision boolean;   -- AJ
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe una membresia activa para este usuario.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin ve los primeros pasos del negocio.';
  end if;

  -- La sede tiene que ser de este negocio. Sin esto, un owner podria preguntar
  -- por la sede de otro salon (misma clase de agujero que TL-01).
  if p_branch_id is null or not exists (
    select 1 from public.branches b
    where b.id = p_branch_id and b.tenant_id = v_tenant_id
  ) then
    raise exception 'La sede indicada no pertenece a este negocio.';
  end if;

  select exists (
    select 1
    from public.services s
    join public.branch_services bs
      on bs.tenant_id = v_tenant_id
     and bs.branch_id = p_branch_id
     and bs.service_id = s.id
    where s.tenant_id = v_tenant_id
      and s.active
      and bs.active
  ) into v_servicios;

  select exists (
    select 1
    from public.stylists st
    join public.branch_stylists bst
      on bst.tenant_id = v_tenant_id
     and bst.branch_id = p_branch_id
     and bst.stylist_id = st.id
    where st.tenant_id = v_tenant_id
      and st.active
      and bst.active
  ) into v_equipo;

  -- Por negocio, igual que `get_available_appointment_slots` (ver cabecera).
  select exists (
    select 1
    from public.business_hours bh
    where bh.tenant_id = v_tenant_id
      and bh.active
      and bh.is_open
  ) into v_horario;

  select exists (
    select 1
    from public.tickets t
    where t.branch_id = p_branch_id
  ) into v_cita;

  -- AJ: por negocio, como el horario. La comision es del salon entero, no de
  -- una sede: `commission_policies` es unica por `tenant_id`.
  select exists (
    select 1
    from public.commission_policies cp
    where cp.tenant_id = v_tenant_id
      and cp.active
      and cp.confirmed_at is not null
  ) into v_comision;

  return query
  select
    v_servicios,
    v_equipo,
    v_horario,
    v_cita,
    v_comision,   -- AJ
    (v_servicios::int + v_equipo::int + v_horario::int + v_cita::int
       + v_comision::int),   -- AJ
    5,   -- AJ: eran 4
    exists (
      select 1 from public.tenants t
      where t.id = v_tenant_id
        and t.onboarding_dismissed_at is not null
    );
end;
$$;

comment on function public.get_onboarding_progress(uuid) is
  'Que lleva hecho un salon nuevo de los cinco Primeros pasos: servicios, equipo, horario, primera cita y comision confirmada '
  '(paso 8.8 D-186; el quinto desde AJ, 20-sep). Servicios y equipo se miran POR SEDE; el horario y la comision, por negocio. NO ELIMINAR.';

revoke all on function public.get_onboarding_progress(uuid) from public, anon;
grant execute on function public.get_onboarding_progress(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Y el estilista, que es quien tiene el dinero en juego, puede saberlo
-- ---------------------------------------------------------------------------
--
-- **Por que una funcion aparte y no una columna mas en
-- `get_my_commission_summary`.** Ese lector devuelve una fila por servicio:
-- meter ahi la marca la repetiria en cada fila y le cambiaria el tipo de
-- retorno, con su `drop` y su riesgo, para transportar un solo `boolean`.
--
-- **Y por que no reusar `get_commission_policy`:** ese exige owner o admin, y
-- con razon. Un estilista no tiene por que ver el porcentaje del salon entero
-- ni las notas del duenyo. Lo unico que le corresponde saber es **si la cifra
-- con la que le estan pagando la aprobo alguien**. Esta funcion devuelve eso
-- y nada mas.

create or replace function public.my_commission_policy_is_confirmed()
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
begin
  -- Sirve para cualquier rol con membresia viva, estilista incluido: lee
  -- `tenant_memberships`, no `user_profiles` (D3.5.3).
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe una membresia activa para este usuario.';
  end if;

  return exists (
    select 1
    from public.commission_policies cp
    where cp.tenant_id = v_tenant_id
      and cp.active
      and cp.confirmed_at is not null
  );
end;
$$;

comment on function public.my_commission_policy_is_confirmed() is
  'Si la comision del negocio la aprobo alguien, o sigue siendo el 40% por defecto que nadie miro (AJ, 20-sep). Devuelve solo un booleano a proposito: el estilista no ve el porcentaje ni las notas, que son de owner y admin. NO ELIMINAR.';

revoke all on function public.my_commission_policy_is_confirmed() from public, anon;
grant execute on function public.my_commission_policy_is_confirmed() to authenticated;

commit;
