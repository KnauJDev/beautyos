-- BeautyOS - Acceso de solo lectura del dueno de plataforma a cualquier
-- negocio (punto 4.3 de RUTA_GENERAL_2026-07-25.md).
--
-- Reconfirmacion de D-009: el propietario decidio que SI quiere poder ver
-- (nunca editar ni borrar) los datos de cualquier negocio para dar
-- soporte o resolver problemas -- clientes/tickets, finanzas, equipo, y
-- resenas/fotos. Decidio explicitamente que esto NO quede auditado (a
-- diferencia de suspender/reactivar/extender prueba, que si dejan rastro
-- en subscription_events desde D-046).
--
-- Autorizacion: igual que platform_list_tenants (D-046), solo exige
-- private.beautyos_current_platform_role() no nulo -- cualquier rol de
-- plataforma puede VER, igual que ya puede listar tenants; las acciones
-- que modifican algo (suspender, reactivar, extender prueba) siguen
-- exigiendo especificamente 'platform_owner'. Estas funciones nuevas son
-- 100% de lectura, ninguna toca datos.

begin;

create or replace function public.platform_get_tenant_clients(
  p_tenant_id uuid
)
returns table (
  client_id uuid,
  name text,
  phone text,
  email text,
  active boolean,
  created_at timestamptz
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
  select c.id, c.name, c.phone, c.email, c.active, c.created_at
  from public.clients c
  where c.tenant_id = p_tenant_id
  order by c.created_at desc;
end;
$$;

create or replace function public.platform_get_tenant_tickets(
  p_tenant_id uuid
)
returns table (
  ticket_id uuid,
  branch_name text,
  client_name text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  paid_amount numeric
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
  with service_summary as (
    select
      ts.ticket_id,
      coalesce(
        string_agg(distinct s.name, ', ' order by s.name)
          filter (where ts.status <> 'cancelado'),
        'Sin servicios'
      ) as service_names,
      coalesce(
        string_agg(distinct st.name, ', ' order by st.name)
          filter (where ts.status <> 'cancelado'),
        'Sin estilista'
      ) as stylist_names,
      coalesce(
        sum(ts.price) filter (where ts.status <> 'cancelado'),
        0
      )::numeric as total_price
    from public.ticket_services ts
    left join public.services s
      on s.tenant_id = ts.tenant_id
     and s.id = ts.service_id
    left join public.stylists st
      on st.tenant_id = ts.tenant_id
     and st.id = ts.stylist_id
    where ts.tenant_id = p_tenant_id
    group by ts.ticket_id
  ),
  payment_summary as (
    select
      tp.ticket_id,
      coalesce(sum(tp.amount), 0)::numeric as paid_amount
    from public.ticket_payments tp
    where tp.tenant_id = p_tenant_id
      and tp.status = 'registrado'
    group by tp.ticket_id
  )
  select
    tk.id,
    b.name,
    coalesce(c.name, 'Cliente sin nombre'),
    tk.scheduled_at,
    tk.status,
    tk.channel,
    coalesce(ss.service_names, 'Sin servicios'),
    coalesce(ss.stylist_names, 'Sin estilista'),
    coalesce(ss.total_price, 0)::numeric,
    coalesce(ps.paid_amount, 0)::numeric
  from public.tickets tk
  join public.branches b
    on b.tenant_id = tk.tenant_id
   and b.id = tk.branch_id
  left join public.clients c
    on c.tenant_id = tk.tenant_id
   and c.id = tk.client_id
  left join service_summary ss on ss.ticket_id = tk.id
  left join payment_summary ps on ps.ticket_id = tk.id
  where tk.tenant_id = p_tenant_id
  order by tk.scheduled_at desc nulls last, tk.created_at desc
  limit 500;
end;
$$;

create or replace function public.platform_get_tenant_financial_summary(
  p_tenant_id uuid
)
returns table (
  branch_id uuid,
  branch_name text,
  total_sales numeric,
  total_purchases numeric,
  total_expenses numeric,
  total_commissions numeric,
  net_result numeric
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
    coalesce((
      select sum(tp.amount)
      from public.ticket_payments tp
      where tp.tenant_id = p_tenant_id
        and tp.branch_id = b.id
        and tp.status = 'registrado'
    ), 0)::numeric as total_sales,
    coalesce((
      select sum(p.total_amount)
      from public.purchases p
      where p.tenant_id = p_tenant_id
        and p.branch_id = b.id
        and p.active
    ), 0)::numeric as total_purchases,
    coalesce((
      select sum(e.amount)
      from public.expenses e
      where e.tenant_id = p_tenant_id
        and e.branch_id = b.id
        and e.active
    ), 0)::numeric as total_expenses,
    coalesce((
      select sum(sc.commission_amount)
      from public.stylist_commissions sc
      where sc.tenant_id = p_tenant_id
        and sc.branch_id = b.id
        and sc.status = 'generada'
    ), 0)::numeric as total_commissions,
    (
      coalesce((
        select sum(tp.amount)
        from public.ticket_payments tp
        where tp.tenant_id = p_tenant_id
          and tp.branch_id = b.id
          and tp.status = 'registrado'
      ), 0)
      - coalesce((
        select sum(p.total_amount)
        from public.purchases p
        where p.tenant_id = p_tenant_id
          and p.branch_id = b.id
          and p.active
      ), 0)
      - coalesce((
        select sum(e.amount)
        from public.expenses e
        where e.tenant_id = p_tenant_id
          and e.branch_id = b.id
          and e.active
      ), 0)
      - coalesce((
        select sum(sc.commission_amount)
        from public.stylist_commissions sc
        where sc.tenant_id = p_tenant_id
          and sc.branch_id = b.id
          and sc.status = 'generada'
      ), 0)
    )::numeric as net_result
  from public.branches b
  where b.tenant_id = p_tenant_id
  order by b.is_primary desc, b.name;
end;
$$;

create or replace function public.platform_get_tenant_team(
  p_tenant_id uuid
)
returns table (
  profile_id uuid,
  full_name text,
  email text,
  role text,
  active boolean,
  stylist_name text,
  created_at timestamptz
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
    up.id,
    up.full_name,
    coalesce(au.email, '')::text,
    up.role,
    up.active,
    s.name,
    up.created_at
  from public.user_profiles up
  left join auth.users au
    on au.id = up.user_id
  left join public.stylists s
    on s.id = up.stylist_id
   and s.tenant_id = p_tenant_id
  where up.tenant_id = p_tenant_id
  order by
    case up.role when 'owner' then 0 else 1 end,
    up.full_name asc;
end;
$$;

create or replace function public.platform_get_tenant_reviews(
  p_tenant_id uuid
)
returns table (
  review_id uuid,
  branch_name text,
  client_name text,
  stylist_name text,
  service_name text,
  rating integer,
  comment text,
  moderation_status text,
  visible_to_public boolean,
  created_at timestamptz
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
    r.id,
    b.name,
    coalesce(c.name, 'Cliente no asociado'),
    coalesce(st.name, 'Estilista no asociado'),
    coalesce(s.name, 'Servicio no asociado'),
    r.rating,
    r.comment,
    r.moderation_status,
    r.visible_to_public,
    r.created_at
  from public.reviews r
  join public.branches b
    on b.tenant_id = r.tenant_id
   and b.id = r.branch_id
  left join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  left join public.stylists st
    on st.tenant_id = r.tenant_id
   and st.id = r.stylist_id
  left join public.services s
    on s.tenant_id = r.tenant_id
   and s.id = r.service_id
  where r.tenant_id = p_tenant_id
    and r.active
  order by r.created_at desc;
end;
$$;

create or replace function public.platform_get_tenant_work_photos(
  p_tenant_id uuid
)
returns table (
  photo_id uuid,
  branch_name text,
  client_name text,
  stylist_name text,
  photo_url text,
  photo_type text,
  caption text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
  created_at timestamptz
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
    wp.id,
    b.name,
    coalesce(c.name, 'Cliente no asociado'),
    coalesce(st.name, 'Estilista no asociado'),
    wp.photo_url,
    wp.photo_type,
    wp.caption,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  join public.branches b
    on b.tenant_id = wp.tenant_id
   and b.id = wp.branch_id
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join public.stylists st
    on st.tenant_id = wp.tenant_id
   and st.id = wp.stylist_id
  where wp.tenant_id = p_tenant_id
    and wp.active
  order by wp.created_at desc;
end;
$$;

revoke all on function public.platform_get_tenant_clients(uuid) from public, anon;
revoke all on function public.platform_get_tenant_tickets(uuid) from public, anon;
revoke all on function public.platform_get_tenant_financial_summary(uuid) from public, anon;
revoke all on function public.platform_get_tenant_team(uuid) from public, anon;
revoke all on function public.platform_get_tenant_reviews(uuid) from public, anon;
revoke all on function public.platform_get_tenant_work_photos(uuid) from public, anon;

grant execute on function public.platform_get_tenant_clients(uuid) to authenticated, service_role;
grant execute on function public.platform_get_tenant_tickets(uuid) to authenticated, service_role;
grant execute on function public.platform_get_tenant_financial_summary(uuid) to authenticated, service_role;
grant execute on function public.platform_get_tenant_team(uuid) to authenticated, service_role;
grant execute on function public.platform_get_tenant_reviews(uuid) to authenticated, service_role;
grant execute on function public.platform_get_tenant_work_photos(uuid) to authenticated, service_role;

commit;
