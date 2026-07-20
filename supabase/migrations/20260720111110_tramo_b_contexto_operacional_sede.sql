-- BeautyOS - Tramo B: contexto operacional de sede.
--
-- Objetivos:
-- 1. Incorporar branch_id sin romper los RPC ni Flutter heredados.
-- 2. Backfill determinista hacia la sede principal activa.
-- 3. Impedir cruces de tenant/sede mediante claves compuestas.
-- 4. Mantener branch_id nullable durante la ventana de compatibilidad.

begin;

do $$
begin
  if exists (
    select t.id
    from public.tenants t
    left join public.branches b
      on b.tenant_id = t.id
     and b.is_primary
     and b.active
    group by t.id
    having count(b.id) <> 1
  ) then
    raise exception 'Tramo B requiere exactamente una sede principal activa por tenant.';
  end if;
end;
$$;

-- La columna permanece nullable hasta que Flutter y todos los RPC escriban
-- la sede de forma explicita (Tramo C/D).
alter table public.business_hours add column if not exists branch_id uuid;
alter table public.appointment_policies add column if not exists branch_id uuid;
alter table public.tickets add column if not exists branch_id uuid;
alter table public.ticket_services add column if not exists branch_id uuid;
alter table public.ticket_history add column if not exists branch_id uuid;
alter table public.ticket_service_history add column if not exists branch_id uuid;
alter table public.ticket_service_change_history add column if not exists branch_id uuid;
alter table public.ticket_payments add column if not exists branch_id uuid;
alter table public.stylist_commissions add column if not exists branch_id uuid;
alter table public.inventory_movements add column if not exists branch_id uuid;
alter table public.purchases add column if not exists branch_id uuid;
alter table public.purchase_items add column if not exists branch_id uuid;
alter table public.expenses add column if not exists branch_id uuid;
alter table public.work_photos add column if not exists branch_id uuid;
alter table public.reviews add column if not exists branch_id uuid;

-- Raices operacionales: sede principal del tenant.
update public.business_hours x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

update public.appointment_policies x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

update public.tickets x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

update public.inventory_movements x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

update public.purchases x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

update public.expenses x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

-- Hijos: heredan la sede del documento operacional que les da origen.
update public.ticket_services x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.ticket_history x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.ticket_service_history x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.ticket_service_change_history x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.ticket_payments x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.stylist_commissions x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.purchase_items x
set branch_id = p.branch_id
from public.purchases p
where x.branch_id is null
  and p.id = x.purchase_id
  and p.tenant_id = x.tenant_id;

-- Fotos y resenas pueden existir sin ticket. Si lo tienen, respetan su sede;
-- si no, durante esta ventana heredan la sede principal.
update public.work_photos x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and x.ticket_id is not null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.work_photos x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

update public.reviews x
set branch_id = t.branch_id
from public.tickets t
where x.branch_id is null
  and x.ticket_id is not null
  and t.id = x.ticket_id
  and t.tenant_id = x.tenant_id;

update public.reviews x
set branch_id = b.id
from public.branches b
where x.branch_id is null
  and b.tenant_id = x.tenant_id
  and b.is_primary
  and b.active;

do $$
declare
  v_table text;
  v_missing bigint;
begin
  foreach v_table in array array[
    'business_hours','appointment_policies','tickets','ticket_services',
    'ticket_history','ticket_service_history','ticket_service_change_history',
    'ticket_payments','stylist_commissions','inventory_movements','purchases',
    'purchase_items','expenses','work_photos','reviews'
  ] loop
    execute format('select count(*) from public.%I where branch_id is null', v_table)
      into v_missing;
    if v_missing <> 0 then
      raise exception 'Backfill incompleto en %. Filas sin sede: %', v_table, v_missing;
    end if;
  end loop;
end;
$$;

-- Claves candidatas necesarias para FKs compuestas tenant + sede.
create unique index if not exists clients_tenant_id_id_uidx
  on public.clients (tenant_id, id);
create unique index if not exists tickets_tenant_branch_id_uidx
  on public.tickets (tenant_id, branch_id, id);
create unique index if not exists ticket_services_tenant_branch_id_uidx
  on public.ticket_services (tenant_id, branch_id, id);
create unique index if not exists purchases_tenant_branch_id_uidx
  on public.purchases (tenant_id, branch_id, id);
create unique index if not exists branch_services_tenant_branch_service_uidx
  on public.branch_services (tenant_id, branch_id, service_id);
create unique index if not exists branch_stylists_tenant_branch_stylist_uidx
  on public.branch_stylists (tenant_id, branch_id, stylist_id);
create unique index if not exists branch_products_tenant_branch_product_uidx
  on public.branch_products (tenant_id, branch_id, product_id);

-- FKs se crean NOT VALID para minimizar el bloqueo y se validan tras el
-- backfill dentro de la misma transaccion.
alter table public.business_hours
  add constraint business_hours_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid;

alter table public.appointment_policies
  add constraint appointment_policies_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid;

alter table public.tickets
  add constraint tickets_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint tickets_tenant_client_fkey
  foreign key (tenant_id, client_id)
  references public.clients (tenant_id, id)
  on update cascade on delete restrict not valid;

alter table public.ticket_services
  add constraint ticket_services_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_services_tenant_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_services_branch_service_fkey
  foreign key (tenant_id, branch_id, service_id)
  references public.branch_services (tenant_id, branch_id, service_id)
  on update cascade on delete restrict not valid,
  add constraint ticket_services_branch_stylist_fkey
  foreign key (tenant_id, branch_id, stylist_id)
  references public.branch_stylists (tenant_id, branch_id, stylist_id)
  on update cascade on delete restrict not valid;

alter table public.ticket_history
  add constraint ticket_history_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_history_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid;

alter table public.ticket_service_history
  add constraint ticket_service_history_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_service_history_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_service_history_branch_service_fkey
  foreign key (tenant_id, branch_id, ticket_service_id)
  references public.ticket_services (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid;

alter table public.ticket_service_change_history
  add constraint ticket_service_change_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_service_change_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_service_change_branch_service_fkey
  foreign key (tenant_id, branch_id, ticket_service_id)
  references public.ticket_services (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid;

alter table public.ticket_payments
  add constraint ticket_payments_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint ticket_payments_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid;

alter table public.stylist_commissions
  add constraint stylist_commissions_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint stylist_commissions_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint stylist_commissions_branch_service_fkey
  foreign key (tenant_id, branch_id, ticket_service_id)
  references public.ticket_services (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint stylist_commissions_branch_stylist_fkey
  foreign key (tenant_id, branch_id, stylist_id)
  references public.branch_stylists (tenant_id, branch_id, stylist_id)
  on update cascade on delete restrict not valid;

alter table public.inventory_movements
  add constraint inventory_movements_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint inventory_movements_branch_product_fkey
  foreign key (tenant_id, branch_id, product_id)
  references public.branch_products (tenant_id, branch_id, product_id)
  on update cascade on delete restrict not valid;

alter table public.purchases
  add constraint purchases_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid;

alter table public.purchase_items
  add constraint purchase_items_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint purchase_items_branch_purchase_fkey
  foreign key (tenant_id, branch_id, purchase_id)
  references public.purchases (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint purchase_items_branch_product_fkey
  foreign key (tenant_id, branch_id, product_id)
  references public.branch_products (tenant_id, branch_id, product_id)
  on update cascade on delete restrict not valid;

alter table public.expenses
  add constraint expenses_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid;

alter table public.work_photos
  add constraint work_photos_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint work_photos_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint work_photos_tenant_client_fkey
  foreign key (tenant_id, client_id)
  references public.clients (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint work_photos_branch_stylist_fkey
  foreign key (tenant_id, branch_id, stylist_id)
  references public.branch_stylists (tenant_id, branch_id, stylist_id)
  on update cascade on delete restrict not valid;

alter table public.reviews
  add constraint reviews_tenant_branch_fkey
  foreign key (tenant_id, branch_id)
  references public.branches (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint reviews_branch_ticket_fkey
  foreign key (tenant_id, branch_id, ticket_id)
  references public.tickets (tenant_id, branch_id, id)
  on update cascade on delete restrict not valid,
  add constraint reviews_tenant_client_fkey
  foreign key (tenant_id, client_id)
  references public.clients (tenant_id, id)
  on update cascade on delete restrict not valid,
  add constraint reviews_branch_stylist_fkey
  foreign key (tenant_id, branch_id, stylist_id)
  references public.branch_stylists (tenant_id, branch_id, stylist_id)
  on update cascade on delete restrict not valid,
  add constraint reviews_branch_service_fkey
  foreign key (tenant_id, branch_id, service_id)
  references public.branch_services (tenant_id, branch_id, service_id)
  on update cascade on delete restrict not valid;

-- Unicidad futura por sede; las restricciones antiguas por tenant se
-- conservan hasta retirar la compatibilidad heredada.
create unique index if not exists business_hours_branch_day_uidx
  on public.business_hours (tenant_id, branch_id, day_of_week);
create unique index if not exists appointment_policies_branch_uidx
  on public.appointment_policies (tenant_id, branch_id);

-- Validacion explicita de todas las nuevas relaciones.
alter table public.business_hours validate constraint business_hours_tenant_branch_fkey;
alter table public.appointment_policies validate constraint appointment_policies_tenant_branch_fkey;
alter table public.tickets validate constraint tickets_tenant_branch_fkey;
alter table public.tickets validate constraint tickets_tenant_client_fkey;
alter table public.ticket_services validate constraint ticket_services_tenant_branch_fkey;
alter table public.ticket_services validate constraint ticket_services_tenant_branch_ticket_fkey;
alter table public.ticket_services validate constraint ticket_services_branch_service_fkey;
alter table public.ticket_services validate constraint ticket_services_branch_stylist_fkey;
alter table public.ticket_history validate constraint ticket_history_tenant_branch_fkey;
alter table public.ticket_history validate constraint ticket_history_branch_ticket_fkey;
alter table public.ticket_service_history validate constraint ticket_service_history_tenant_branch_fkey;
alter table public.ticket_service_history validate constraint ticket_service_history_branch_ticket_fkey;
alter table public.ticket_service_history validate constraint ticket_service_history_branch_service_fkey;
alter table public.ticket_service_change_history validate constraint ticket_service_change_tenant_branch_fkey;
alter table public.ticket_service_change_history validate constraint ticket_service_change_branch_ticket_fkey;
alter table public.ticket_service_change_history validate constraint ticket_service_change_branch_service_fkey;
alter table public.ticket_payments validate constraint ticket_payments_tenant_branch_fkey;
alter table public.ticket_payments validate constraint ticket_payments_branch_ticket_fkey;
alter table public.stylist_commissions validate constraint stylist_commissions_tenant_branch_fkey;
alter table public.stylist_commissions validate constraint stylist_commissions_branch_ticket_fkey;
alter table public.stylist_commissions validate constraint stylist_commissions_branch_service_fkey;
alter table public.stylist_commissions validate constraint stylist_commissions_branch_stylist_fkey;
alter table public.inventory_movements validate constraint inventory_movements_tenant_branch_fkey;
alter table public.inventory_movements validate constraint inventory_movements_branch_product_fkey;
alter table public.purchases validate constraint purchases_tenant_branch_fkey;
alter table public.purchase_items validate constraint purchase_items_tenant_branch_fkey;
alter table public.purchase_items validate constraint purchase_items_branch_purchase_fkey;
alter table public.purchase_items validate constraint purchase_items_branch_product_fkey;
alter table public.expenses validate constraint expenses_tenant_branch_fkey;
alter table public.work_photos validate constraint work_photos_tenant_branch_fkey;
alter table public.work_photos validate constraint work_photos_branch_ticket_fkey;
alter table public.work_photos validate constraint work_photos_tenant_client_fkey;
alter table public.work_photos validate constraint work_photos_branch_stylist_fkey;
alter table public.reviews validate constraint reviews_tenant_branch_fkey;
alter table public.reviews validate constraint reviews_branch_ticket_fkey;
alter table public.reviews validate constraint reviews_tenant_client_fkey;
alter table public.reviews validate constraint reviews_branch_stylist_fkey;
alter table public.reviews validate constraint reviews_branch_service_fkey;

-- Capa puente: los RPC existentes no reciben branch_id. Estas funciones
-- privadas derivan y validan la sede dentro de PostgreSQL; el cliente nunca
-- decide implicitamente a que tenant pertenece una operacion.
create or replace function private.beautyos_resolve_branch(
  p_tenant_id uuid,
  p_branch_id uuid default null
)
returns uuid
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_branch_id uuid;
  v_count integer;
begin
  if p_tenant_id is null then
    raise exception 'No se puede resolver una sede sin tenant.';
  end if;

  if p_branch_id is not null then
    select b.id into v_branch_id
    from public.branches b
    where b.tenant_id = p_tenant_id
      and b.id = p_branch_id;

    if v_branch_id is null then
      raise exception 'La sede no pertenece al tenant indicado.';
    end if;
    return v_branch_id;
  end if;

  select count(*)
    into v_count
  from public.branches b
  where b.tenant_id = p_tenant_id
    and b.is_primary
    and b.active;

  if v_count <> 1 then
    raise exception 'El tenant debe tener exactamente una sede principal activa.';
  end if;

  select b.id
    into v_branch_id
  from public.branches b
  where b.tenant_id = p_tenant_id
    and b.is_primary
    and b.active
  limit 1;
  return v_branch_id;
end;
$$;

create or replace function private.beautyos_set_root_branch()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'UPDATE'
     and old.branch_id is not null
     and new.branch_id is distinct from old.branch_id then
    raise exception 'La sede de un registro operacional existente no puede cambiarse directamente.';
  end if;

  new.branch_id := private.beautyos_resolve_branch(new.tenant_id, new.branch_id);
  return new;
end;
$$;

create or replace function private.beautyos_set_ticket_branch()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
begin
  select t.tenant_id, t.branch_id
    into v_tenant_id, v_branch_id
  from public.tickets t
  where t.id = new.ticket_id;

  if v_tenant_id is null then
    raise exception 'Ticket operacional inexistente.';
  end if;
  if new.tenant_id is distinct from v_tenant_id then
    raise exception 'El ticket no pertenece al tenant indicado.';
  end if;
  if new.branch_id is not null and new.branch_id is distinct from v_branch_id then
    raise exception 'El registro no pertenece a la sede del ticket.';
  end if;

  new.branch_id := v_branch_id;
  return new;
end;
$$;

create or replace function private.beautyos_set_purchase_branch()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
begin
  select p.tenant_id, p.branch_id
    into v_tenant_id, v_branch_id
  from public.purchases p
  where p.id = new.purchase_id;

  if v_tenant_id is null then
    raise exception 'Compra operacional inexistente.';
  end if;
  if new.tenant_id is distinct from v_tenant_id then
    raise exception 'La compra no pertenece al tenant indicado.';
  end if;
  if new.branch_id is not null and new.branch_id is distinct from v_branch_id then
    raise exception 'El detalle no pertenece a la sede de la compra.';
  end if;

  new.branch_id := v_branch_id;
  return new;
end;
$$;

create or replace function private.beautyos_set_optional_ticket_branch()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
begin
  if new.ticket_id is null then
    new.branch_id := private.beautyos_resolve_branch(new.tenant_id, new.branch_id);
    return new;
  end if;

  select t.tenant_id, t.branch_id
    into v_tenant_id, v_branch_id
  from public.tickets t
  where t.id = new.ticket_id;

  if v_tenant_id is null then
    raise exception 'Ticket operacional inexistente.';
  end if;
  if new.tenant_id is distinct from v_tenant_id then
    raise exception 'El ticket no pertenece al tenant indicado.';
  end if;
  if new.branch_id is not null and new.branch_id is distinct from v_branch_id then
    raise exception 'El registro no pertenece a la sede del ticket.';
  end if;

  new.branch_id := v_branch_id;
  return new;
end;
$$;

revoke all on function private.beautyos_resolve_branch(uuid, uuid) from public, anon, authenticated;
revoke all on function private.beautyos_set_root_branch() from public, anon, authenticated;
revoke all on function private.beautyos_set_ticket_branch() from public, anon, authenticated;
revoke all on function private.beautyos_set_purchase_branch() from public, anon, authenticated;
revoke all on function private.beautyos_set_optional_ticket_branch() from public, anon, authenticated;

create trigger business_hours_set_branch
before insert or update of tenant_id, branch_id on public.business_hours
for each row execute function private.beautyos_set_root_branch();
create trigger appointment_policies_set_branch
before insert or update of tenant_id, branch_id on public.appointment_policies
for each row execute function private.beautyos_set_root_branch();
create trigger tickets_set_branch
before insert or update of tenant_id, branch_id on public.tickets
for each row execute function private.beautyos_set_root_branch();
create trigger inventory_movements_set_branch
before insert or update of tenant_id, branch_id on public.inventory_movements
for each row execute function private.beautyos_set_root_branch();
create trigger purchases_set_branch
before insert or update of tenant_id, branch_id on public.purchases
for each row execute function private.beautyos_set_root_branch();
create trigger expenses_set_branch
before insert or update of tenant_id, branch_id on public.expenses
for each row execute function private.beautyos_set_root_branch();

create trigger ticket_services_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.ticket_services
for each row execute function private.beautyos_set_ticket_branch();
create trigger ticket_history_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.ticket_history
for each row execute function private.beautyos_set_ticket_branch();
create trigger ticket_service_history_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.ticket_service_history
for each row execute function private.beautyos_set_ticket_branch();
create trigger ticket_service_change_history_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.ticket_service_change_history
for each row execute function private.beautyos_set_ticket_branch();
create trigger ticket_payments_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.ticket_payments
for each row execute function private.beautyos_set_ticket_branch();
create trigger stylist_commissions_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.stylist_commissions
for each row execute function private.beautyos_set_ticket_branch();

create trigger purchase_items_set_branch
before insert or update of tenant_id, branch_id, purchase_id on public.purchase_items
for each row execute function private.beautyos_set_purchase_branch();
create trigger work_photos_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.work_photos
for each row execute function private.beautyos_set_optional_ticket_branch();
create trigger reviews_set_branch
before insert or update of tenant_id, branch_id, ticket_id on public.reviews
for each row execute function private.beautyos_set_optional_ticket_branch();

-- Indices para FKs y rutas operativas frecuentes.
create index if not exists business_hours_tenant_branch_idx
  on public.business_hours (tenant_id, branch_id);
create index if not exists appointment_policies_tenant_branch_idx
  on public.appointment_policies (tenant_id, branch_id);
create index if not exists tickets_branch_schedule_active_idx
  on public.tickets (tenant_id, branch_id, scheduled_at)
  where status in ('solicitado','cotizado','apartado','confirmado','en_espera','en_proceso');
create index if not exists ticket_services_branch_stylist_active_idx
  on public.ticket_services (tenant_id, branch_id, stylist_id, status, ticket_id)
  where status in ('pendiente','en_proceso');
create index if not exists ticket_history_branch_ticket_created_idx
  on public.ticket_history (tenant_id, branch_id, ticket_id, created_at desc);
create index if not exists ticket_service_history_branch_ticket_created_idx
  on public.ticket_service_history (tenant_id, branch_id, ticket_id, created_at desc);
create index if not exists ticket_service_change_branch_ticket_created_idx
  on public.ticket_service_change_history (tenant_id, branch_id, ticket_id, created_at desc);
create index if not exists ticket_payments_branch_received_active_idx
  on public.ticket_payments (tenant_id, branch_id, received_at desc)
  where status = 'registrado';
create index if not exists stylist_commissions_branch_generated_active_idx
  on public.stylist_commissions (tenant_id, branch_id, generated_at desc)
  where status = 'generada';
create index if not exists inventory_movements_branch_created_idx
  on public.inventory_movements (tenant_id, branch_id, created_at desc);
create index if not exists purchases_branch_date_active_idx
  on public.purchases (tenant_id, branch_id, purchase_date desc)
  where active;
create index if not exists purchase_items_branch_purchase_idx
  on public.purchase_items (tenant_id, branch_id, purchase_id);
create index if not exists expenses_branch_date_active_idx
  on public.expenses (tenant_id, branch_id, expense_date desc)
  where active;
create index if not exists work_photos_branch_created_idx
  on public.work_photos (tenant_id, branch_id, created_at desc);
create index if not exists reviews_branch_created_idx
  on public.reviews (tenant_id, branch_id, created_at desc);

-- Cobertura exacta de claves foraneas (incluye deuda heredada detectada por
-- la auditoria local). Un indice parcial no basta para sostener una FK.
create index if not exists tickets_client_id_idx
  on public.tickets (client_id);
create index if not exists tickets_tenant_client_idx
  on public.tickets (tenant_id, client_id);
create index if not exists ticket_services_ticket_id_idx
  on public.ticket_services (ticket_id);
create index if not exists ticket_services_service_id_idx
  on public.ticket_services (service_id);
create index if not exists ticket_services_stylist_id_idx
  on public.ticket_services (stylist_id);
create index if not exists ticket_services_branch_ticket_idx
  on public.ticket_services (tenant_id, branch_id, ticket_id);
create index if not exists ticket_services_branch_service_idx
  on public.ticket_services (tenant_id, branch_id, service_id);
create index if not exists ticket_services_branch_stylist_idx
  on public.ticket_services (tenant_id, branch_id, stylist_id);
create index if not exists ticket_history_ticket_id_idx
  on public.ticket_history (ticket_id);
create index if not exists ticket_service_history_ticket_id_idx
  on public.ticket_service_history (ticket_id);
create index if not exists ticket_service_history_service_id_idx
  on public.ticket_service_history (ticket_service_id);
create index if not exists ticket_service_history_branch_service_idx
  on public.ticket_service_history (tenant_id, branch_id, ticket_service_id);
create index if not exists ticket_service_change_branch_service_idx
  on public.ticket_service_change_history (tenant_id, branch_id, ticket_service_id);
create index if not exists ticket_payments_branch_ticket_idx
  on public.ticket_payments (tenant_id, branch_id, ticket_id);
create index if not exists stylist_commissions_branch_ticket_idx
  on public.stylist_commissions (tenant_id, branch_id, ticket_id);
create index if not exists stylist_commissions_branch_service_idx
  on public.stylist_commissions (tenant_id, branch_id, ticket_service_id);
create index if not exists stylist_commissions_branch_stylist_idx
  on public.stylist_commissions (tenant_id, branch_id, stylist_id);
create index if not exists inventory_movements_product_id_idx
  on public.inventory_movements (product_id);
create index if not exists inventory_movements_branch_product_idx
  on public.inventory_movements (tenant_id, branch_id, product_id);
create index if not exists purchase_items_purchase_id_idx
  on public.purchase_items (purchase_id);
create index if not exists purchase_items_product_id_idx
  on public.purchase_items (product_id);
create index if not exists purchase_items_branch_product_idx
  on public.purchase_items (tenant_id, branch_id, product_id);
create index if not exists reviews_service_id_idx
  on public.reviews (service_id);
create index if not exists reviews_tenant_client_idx
  on public.reviews (tenant_id, client_id);
create index if not exists reviews_branch_ticket_idx
  on public.reviews (tenant_id, branch_id, ticket_id);
create index if not exists reviews_branch_stylist_idx
  on public.reviews (tenant_id, branch_id, stylist_id);
create index if not exists reviews_branch_service_idx
  on public.reviews (tenant_id, branch_id, service_id);
create index if not exists work_photos_client_id_idx
  on public.work_photos (client_id);
create index if not exists work_photos_tenant_client_idx
  on public.work_photos (tenant_id, client_id);
create index if not exists work_photos_branch_ticket_idx
  on public.work_photos (tenant_id, branch_id, ticket_id);
create index if not exists work_photos_branch_stylist_idx
  on public.work_photos (tenant_id, branch_id, stylist_id);
create index if not exists stylist_services_service_id_idx
  on public.stylist_services (service_id);

commit;
