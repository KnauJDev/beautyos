-- BeautyOS - Comision de estilista por sede+estilista+servicio.
-- Benchmarking 2026-07-28 (AgendaPro), punto 1 del orden acordado (el mas
-- dificil primero): hoy `commission_policies` es una sola politica por
-- todo el negocio (unique(tenant_id)). El propietario decidio que cada
-- sede pueda fijar excepciones de comision por estilista y por servicio,
-- sin tocar la politica por defecto del negocio.
--
-- Resolucion en register_ticket_payment (unico punto real donde nace una
-- fila de stylist_commissions, ver 081_stylist_commissions_and_payment_hooks.sql):
-- por cada servicio finalizado se busca primero una excepcion activa para
-- (branch_id del ticket, stylist_id, service_id); si no existe, se usa la
-- politica del negocio como hoy. Sin excepciones configuradas, el
-- comportamiento es identico al actual -- cero riesgo para negocios que
-- nunca toquen esto.
--
-- Trazabilidad: se agrega stylist_commissions.commission_override_id
-- (nullable) para saber si una comision ya generada vino de una
-- excepcion o del valor por defecto. Nada del historial ya generado se
-- reescribe. Cambiar una excepcion no sobreescribe la fila anterior: se
-- desactiva y se inserta una nueva, dejando el historial de cambios de
-- comision tambien auditable (mismo criterio de "no alterar el historial
-- financiero sin trazabilidad" de AGENTS.md).

begin;

create table if not exists public.stylist_service_commissions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  branch_id uuid not null,
  stylist_id uuid not null references public.stylists(id) on delete restrict,
  service_id uuid not null references public.services(id) on delete restrict,
  commission_type text not null check (commission_type in ('percentage', 'fixed')),
  commission_percentage numeric not null default 0
    check (commission_percentage >= 0 and commission_percentage <= 100),
  fixed_commission_amount numeric not null default 0
    check (fixed_commission_amount >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null,
  constraint stylist_service_commissions_tenant_branch_fkey
    foreign key (tenant_id, branch_id)
    references public.branches(tenant_id, id)
    on update cascade on delete restrict
);

alter table public.stylist_service_commissions enable row level security;

create unique index if not exists stylist_service_commissions_active_uidx
  on public.stylist_service_commissions (tenant_id, branch_id, stylist_id, service_id)
  where active = true;

create index if not exists stylist_service_commissions_lookup_idx
  on public.stylist_service_commissions (tenant_id, branch_id, stylist_id, service_id)
  where active = true;

revoke all on table public.stylist_service_commissions from public, anon, authenticated;

comment on table public.stylist_service_commissions
  is 'Excepciones de comision por sede+estilista+servicio. Si no hay fila activa para una combinacion, se usa la politica por defecto del negocio (commission_policies).';

alter table public.stylist_commissions
  add column if not exists commission_override_id uuid
    references public.stylist_service_commissions(id) on delete set null;

comment on column public.stylist_commissions.commission_override_id
  is 'Excepcion de sede+estilista+servicio usada para esta comision, si existia una activa al momento de generarse. Null si se uso la politica por defecto del negocio.';

-- Lista las excepciones (y sus valores por defecto si no hay excepcion)
-- para los servicios que un estilista tiene asignados en una sede.
create or replace function public.get_stylist_commission_overrides(
  p_branch_id uuid,
  p_stylist_id uuid
)
returns table (
  service_id uuid,
  service_name text,
  override_id uuid,
  commission_type text,
  commission_percentage numeric,
  fixed_commission_amount numeric
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
    p_branch_id, array['tenant_owner', 'admin']::text[], true
  );

  return query
  select
    s.id,
    s.name,
    sc.id,
    sc.commission_type,
    sc.commission_percentage,
    sc.fixed_commission_amount
  from public.branch_stylist_services bss
  join public.branch_stylists bst
    on bst.id = bss.branch_stylist_id
  join public.branch_services bsv
    on bsv.id = bss.branch_service_id
  join public.services s
    on s.id = bsv.service_id
  left join public.stylist_service_commissions sc
    on sc.tenant_id = v_access.tenant_id
   and sc.branch_id = p_branch_id
   and sc.stylist_id = p_stylist_id
   and sc.service_id = s.id
   and sc.active
  where bst.tenant_id = v_access.tenant_id
    and bst.branch_id = p_branch_id
    and bst.stylist_id = p_stylist_id
    and bsv.branch_id = p_branch_id
    and bss.active
    and bst.active
    and bsv.active
  order by s.name;
end;
$$;

-- Crea o reemplaza la excepcion activa para una combinacion sede+estilista+servicio.
create or replace function public.set_stylist_service_commission(
  p_branch_id uuid,
  p_stylist_id uuid,
  p_service_id uuid,
  p_commission_type text,
  p_commission_percentage numeric,
  p_fixed_commission_amount numeric
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_new_id uuid;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin']::text[], true
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

  if not exists (
    select 1
    from public.branch_stylist_services bss
    join public.branch_stylists bst
      on bst.id = bss.branch_stylist_id
    join public.branch_services bsv
      on bsv.id = bss.branch_service_id
    where bst.tenant_id = v_access.tenant_id
      and bst.branch_id = p_branch_id
      and bst.stylist_id = p_stylist_id
      and bsv.branch_id = p_branch_id
      and bsv.service_id = p_service_id
      and bss.active
      and bst.active
      and bsv.active
  ) then
    raise exception 'Este estilista no tiene asignado ese servicio en esta sede.';
  end if;

  update public.stylist_service_commissions
     set active = false,
         updated_at = now()
   where tenant_id = v_access.tenant_id
     and branch_id = p_branch_id
     and stylist_id = p_stylist_id
     and service_id = p_service_id
     and active = true;

  insert into public.stylist_service_commissions (
    tenant_id, branch_id, stylist_id, service_id,
    commission_type, commission_percentage, fixed_commission_amount,
    created_by
  ) values (
    v_access.tenant_id, p_branch_id, p_stylist_id, p_service_id,
    p_commission_type, p_commission_percentage, p_fixed_commission_amount,
    auth.uid()
  )
  returning id into v_new_id;

  return v_new_id;
end;
$$;

-- Quita la excepcion activa (vuelve a usar la politica por defecto del negocio).
create or replace function public.remove_stylist_service_commission_override(
  p_branch_id uuid,
  p_stylist_id uuid,
  p_service_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin']::text[], true
  );

  update public.stylist_service_commissions
     set active = false,
         updated_at = now()
   where tenant_id = v_access.tenant_id
     and branch_id = p_branch_id
     and stylist_id = p_stylist_id
     and service_id = p_service_id
     and active = true;

  if not found then
    raise exception 'No hay una excepcion activa para revertir en esa combinacion.';
  end if;
end;
$$;

-- Resuelve la comision real: excepcion de sede+estilista+servicio si existe,
-- si no la politica por defecto del negocio (mismo criterio de hoy).
create or replace function public.register_ticket_payment(
  p_ticket_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text default null,
  p_notes text default null
)
returns setof public.ticket_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket public.tickets%rowtype;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
  v_balance numeric(12, 2);
  v_method text;
  v_payment public.ticket_payments%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para registrar pagos.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  if v_ticket.status <> 'finalizado' then
    raise exception 'Solo se pueden registrar pagos de tickets finalizados.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'El valor del pago debe ser mayor que cero.';
  end if;

  v_method := lower(trim(coalesce(p_method, '')));

  if v_method not in ('efectivo', 'tarjeta', 'transferencia', 'otro') then
    raise exception 'Metodo de pago no valido.';
  end if;

  select coalesce(sum(ts.price), 0)::numeric(12, 2)
    into v_total
  from public.ticket_services ts
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = v_tenant_id
    and ts.status = 'finalizado';

  if v_total <= 0 then
    raise exception 'El ticket no tiene servicios finalizados para cobrar.';
  end if;

  select coalesce(sum(tp.amount), 0)::numeric(12, 2)
    into v_paid
  from public.ticket_payments tp
  where tp.ticket_id = v_ticket.id
    and tp.tenant_id = v_tenant_id
    and tp.status = 'registrado';

  v_balance := v_total - v_paid;

  if v_balance <= 0 then
    raise exception 'El ticket ya esta completamente pagado.';
  end if;

  if p_amount > v_balance then
    raise exception 'El pago supera el saldo pendiente de %.', v_balance;
  end if;

  insert into public.ticket_payments (
    tenant_id, ticket_id, amount, method, reference, notes, created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    p_amount,
    v_method,
    nullif(trim(coalesce(p_reference, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    auth.uid()
  )
  returning * into v_payment;

  if p_amount = v_balance then
    update public.tickets
       set status = 'cerrado'
     where id = v_ticket.id
       and tenant_id = v_tenant_id;

    insert into public.ticket_history (
      tenant_id, ticket_id, event_type, previous_status, new_status, reason, created_by
    ) values (
      v_tenant_id,
      v_ticket.id,
      'status_changed',
      'finalizado',
      'cerrado',
      'Saldo pagado completamente',
      auth.uid()
    );

    insert into public.stylist_commissions (
      tenant_id,
      ticket_id,
      ticket_service_id,
      stylist_id,
      commission_policy_id,
      commission_override_id,
      service_amount,
      commission_type,
      commission_percentage,
      fixed_commission_amount,
      applies_after_discount,
      commission_amount,
      generated_at,
      generated_by
    )
    select
      v_tenant_id,
      v_ticket.id,
      ts.id,
      ts.stylist_id,
      cp.id,
      ov.id,
      ts.price,
      coalesce(ov.commission_type, cp.commission_type),
      coalesce(ov.commission_percentage, cp.commission_percentage),
      coalesce(ov.fixed_commission_amount, cp.fixed_commission_amount),
      cp.applies_after_discount,
      case
        when coalesce(ov.commission_type, cp.commission_type) = 'fixed'
          then coalesce(ov.fixed_commission_amount, cp.fixed_commission_amount)
        else round(ts.price * coalesce(ov.commission_percentage, cp.commission_percentage) / 100, 2)
      end,
      v_payment.received_at,
      auth.uid()
    from public.ticket_services ts
    join public.commission_policies cp
      on cp.tenant_id = v_tenant_id
     and cp.active = true
    left join public.stylist_service_commissions ov
      on ov.tenant_id = v_tenant_id
     and ov.branch_id = v_ticket.branch_id
     and ov.stylist_id = ts.stylist_id
     and ov.service_id = ts.service_id
     and ov.active
    where ts.ticket_id = v_ticket.id
      and ts.tenant_id = v_tenant_id
      and ts.status = 'finalizado'
      and ts.stylist_id is not null
      and not exists (
        select 1
        from public.stylist_commissions sc
        where sc.ticket_service_id = ts.id
          and sc.status = 'generada'
      );
  end if;

  return next v_payment;
end;
$$;

revoke all on function public.get_stylist_commission_overrides(uuid, uuid)
  from public, anon;
revoke all on function public.set_stylist_service_commission(uuid, uuid, uuid, text, numeric, numeric)
  from public, anon;
revoke all on function public.remove_stylist_service_commission_override(uuid, uuid, uuid)
  from public, anon;

grant execute on function public.get_stylist_commission_overrides(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.set_stylist_service_commission(uuid, uuid, uuid, text, numeric, numeric)
  to authenticated, service_role;
grant execute on function public.remove_stylist_service_commission_override(uuid, uuid, uuid)
  to authenticated, service_role;

comment on function public.get_stylist_commission_overrides(uuid, uuid)
  is 'Lista los servicios asignados a un estilista en una sede con su excepcion de comision activa, si existe.';
comment on function public.set_stylist_service_commission(uuid, uuid, uuid, text, numeric, numeric)
  is 'Crea una excepcion de comision para sede+estilista+servicio, exclusivo de tenant_owner/admin de esa sede.';
comment on function public.remove_stylist_service_commission_override(uuid, uuid, uuid)
  is 'Desactiva la excepcion activa de sede+estilista+servicio, revirtiendo a la politica por defecto del negocio.';

commit;
