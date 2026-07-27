-- BeautyOS - Choque de agenda entre sedes de un mismo estilista.
--
-- Hueco confirmado por el propietario al probar D-072 (crear sedes
-- adicionales): el trigger enforce_stylist_schedule_conflict (Tramo C2b)
-- solo revisaba choques DENTRO de la misma sede (`other_ts.branch_id =
-- v_branch_id`). Un estilista activo en dos sedes podia quedar
-- doble-agendado a la misma hora en sedes distintas, porque cada sede
-- validaba su propia agenda sin mirar la otra. Esto era una limitacion
-- conocida y documentada como "politica futura" en
-- docs/04_pruebas/CRITERIOS_SALIDA_FASE_1.md, pero se vuelve un riesgo
-- real ahora que multisede con estilistas compartidos ya existe de
-- verdad.
--
-- Cambio: se revisa el choque contra TODAS las sedes del tenant para ese
-- estilista (se quita el filtro por sede en la subconsulta "occupied"),
-- y el candado de concurrencia (advisory lock) pasa a ser por estilista
-- en vez de por sede -- si el candado siguiera siendo por sede, dos
-- reservas simultaneas en sedes distintas para el mismo estilista
-- podrian pasar la validacion al mismo tiempo antes de que cualquiera
-- confirme. El mensaje de error ahora menciona la sede donde ya tiene la
-- cita, para que el equipo entienda un choque que no puede ver en el
-- calendario de su propia sede.

begin;

create or replace function public.enforce_stylist_schedule_conflict()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_ticket_id uuid;
  v_stylist_id uuid;
  v_scheduled_at timestamptz;
  v_duration_minutes integer;
  v_stylist_name text;
  v_assignment record;
  v_previous_ticket_service_id uuid;
  v_conflict_branch_name text;
begin
  if tg_table_name = 'ticket_services' then
    if new.stylist_id is null
       or new.status not in ('pendiente', 'en_proceso') then
      return new;
    end if;

    select t.tenant_id, t.branch_id, t.id, t.scheduled_at
      into v_tenant_id, v_branch_id, v_ticket_id, v_scheduled_at
    from public.tickets t
    where t.id = new.ticket_id
      and t.tenant_id = new.tenant_id
      and t.branch_id = new.branch_id
      and t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      );

    if not found or v_scheduled_at is null then
      return new;
    end if;

    v_stylist_id := new.stylist_id;
    if tg_op = 'UPDATE' then
      v_previous_ticket_service_id := old.id;
    end if;

    select (coalesce(sum(ts.duration_minutes), 0) + new.duration_minutes)::integer
      into v_duration_minutes
    from public.ticket_services ts
    where ts.ticket_id = new.ticket_id
      and ts.tenant_id = new.tenant_id
      and ts.branch_id = new.branch_id
      and ts.stylist_id = new.stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and (v_previous_ticket_service_id is null or ts.id <> v_previous_ticket_service_id);

    perform pg_advisory_xact_lock(
      hashtextextended('beautyos:agenda:stylist:' || v_stylist_id::text, 0)
    );

    v_conflict_branch_name := null;

    select ob.name
      into v_conflict_branch_name
    from (
      select other_t.branch_id, other_t.scheduled_at,
             sum(other_ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services other_ts
      join public.tickets other_t
        on other_t.id = other_ts.ticket_id
       and other_t.tenant_id = other_ts.tenant_id
       and other_t.branch_id = other_ts.branch_id
      where other_ts.tenant_id = v_tenant_id
        and other_ts.ticket_id <> v_ticket_id
        and other_ts.stylist_id = v_stylist_id
        and other_ts.status in ('pendiente', 'en_proceso')
        and other_t.status in (
          'solicitado', 'cotizado', 'apartado',
          'confirmado', 'en_espera', 'en_proceso'
        )
        and other_t.scheduled_at is not null
      group by other_t.branch_id, other_t.id, other_t.scheduled_at
    ) occupied
    join public.branches ob on ob.id = occupied.branch_id
    where v_scheduled_at < occupied.scheduled_at
            + occupied.duration_minutes * interval '1 minute'
      and v_scheduled_at + v_duration_minutes * interval '1 minute'
            > occupied.scheduled_at
    limit 1;

    if v_conflict_branch_name is not null then
      select st.name into v_stylist_name
      from public.stylists st
      where st.id = v_stylist_id and st.tenant_id = v_tenant_id;

      raise exception 'Choque de agenda: % ya tiene una cita en "%" que se cruza con este horario.',
        coalesce(v_stylist_name, 'el estilista seleccionado'), v_conflict_branch_name;
    end if;

    return new;
  end if;

  if tg_table_name = 'tickets' then
    if new.scheduled_at is null
       or new.status not in (
         'solicitado', 'cotizado', 'apartado',
         'confirmado', 'en_espera', 'en_proceso'
       ) then
      return new;
    end if;

    if new.scheduled_at is not distinct from old.scheduled_at
       and new.status is not distinct from old.status then
      return new;
    end if;

    v_tenant_id := new.tenant_id;
    v_branch_id := new.branch_id;
    v_ticket_id := new.id;
    v_scheduled_at := new.scheduled_at;

    for v_assignment in
      select ts.stylist_id, sum(ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services ts
      where ts.ticket_id = v_ticket_id
        and ts.tenant_id = v_tenant_id
        and ts.branch_id = v_branch_id
        and ts.stylist_id is not null
        and ts.status in ('pendiente', 'en_proceso')
      group by ts.stylist_id
      order by ts.stylist_id
    loop
      perform pg_advisory_xact_lock(
        hashtextextended('beautyos:agenda:stylist:' || v_assignment.stylist_id::text, 0)
      );

      select ob.name
        into v_conflict_branch_name
      from (
        select other_t.branch_id, other_t.scheduled_at,
               sum(other_ts.duration_minutes)::integer as duration_minutes
        from public.ticket_services other_ts
        join public.tickets other_t
          on other_t.id = other_ts.ticket_id
         and other_t.tenant_id = other_ts.tenant_id
         and other_t.branch_id = other_ts.branch_id
        where other_ts.tenant_id = v_tenant_id
          and other_ts.ticket_id <> v_ticket_id
          and other_ts.stylist_id = v_assignment.stylist_id
          and other_ts.status in ('pendiente', 'en_proceso')
          and other_t.status in (
            'solicitado', 'cotizado', 'apartado',
            'confirmado', 'en_espera', 'en_proceso'
          )
          and other_t.scheduled_at is not null
        group by other_t.branch_id, other_t.id, other_t.scheduled_at
      ) occupied
      join public.branches ob on ob.id = occupied.branch_id
      where v_scheduled_at < occupied.scheduled_at
              + occupied.duration_minutes * interval '1 minute'
        and v_scheduled_at + v_assignment.duration_minutes * interval '1 minute'
              > occupied.scheduled_at
      limit 1;

      if v_conflict_branch_name is not null then
        select st.name into v_stylist_name
        from public.stylists st
        where st.id = v_assignment.stylist_id and st.tenant_id = v_tenant_id;

        raise exception 'Choque de agenda: % ya tiene una cita en "%" que se cruza con este horario.',
          coalesce(v_stylist_name, 'el estilista seleccionado'), v_conflict_branch_name;
      end if;
    end loop;

    return new;
  end if;

  return new;
end;
$$;

commit;
