-- ==============================================================================
-- HALLAZGO BL: las tildes danadas de "Corregir un servicio finalizado"
-- ==============================================================================
--
-- QUE SE ENCONTRO
--
-- La comprobacion 9 del control 224 (23-sep) barrio toda la base buscando
-- texto danado por la codificacion y encontro UNA funcion:
-- `public.reopen_finished_ticket_service`, la que hay debajo de "Corregir un
-- servicio finalizado" (la llama `reopen_finished_ticket_service_v2`).
--
-- Tenia cinco textos danados: cuatro mensajes de error ("finalizaciÃ³n",
-- "correcciÃ³n", "no estÃ¡") y **la frase que se guarda en el historial del
-- ticket**: "CorrecciÃ³n administrativa: <motivo>".
--
-- **La funcion no esta en ningun archivo del repositorio**: solo sus permisos
-- (tramo D3.5.2). Nacio antes de que el proyecto usara migraciones (hallazgo
-- AI). Por eso se leyo antes de tocarla
-- (`intervenciones/extraer_tildes_danadas_bl.sql`), y por eso esta migracion
-- es tambien la primera vez que su texto queda escrito aqui.
--
-- Las migraciones con tildes aplicadas con `aplicar_sql.ps1` quedaron bien: el
-- dano no vino del guion (D-262).
--
-- QUE CAMBIA
--
-- Solo esas cinco cadenas. El resto es el texto vivo, generado por un guion que
-- aplica cada cambio comprobando su ancla. **Tampoco se toca su
-- `search_path = public`**, distinto del `pg_catalog` del resto: funciona, y
-- cambiarlo no es lo que se pidio (regla 25 b).
--
-- LO QUE NO HACE: las filas del historial que ya se guardaron con el texto
-- danado NO se corrigen aqui. Es el historial de los tickets, y tocarlo es
-- decision del propietario (AGENTS.md: no alterar historial sin
-- trazabilidad). El control 225 las cuenta.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\225_test_las_tildes_de_corregir_servicio.sql
-- ==============================================================================

-- Los textos llevan tildes: que se lean como UTF-8 (D-261).
set client_encoding = 'UTF8';

begin;

CREATE OR REPLACE FUNCTION public.reopen_finished_ticket_service(p_ticket_service_id uuid, p_reason text)
 RETURNS SETOF ticket_services
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tenant_id uuid;
  v_role text;
  v_reason text;
  v_service public.ticket_services%rowtype;
  v_ticket public.tickets%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede corregir una finalización.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_reason is null then
    raise exception 'Indica el motivo de la corrección.';
  end if;

  select *
    into v_service
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
  for update;

  if not found or v_service.status <> 'finalizado' then
    raise exception 'El servicio no está finalizado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_service.ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found or v_ticket.status not in ('en_proceso', 'finalizado') then
    raise exception 'El ticket ya no admite esta corrección.';
  end if;

  update public.ticket_services
     set status = 'en_proceso'
   where id = v_service.id
     and tenant_id = v_tenant_id;

  insert into public.ticket_service_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    previous_status,
    new_status,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_service.id,
    'finalizado',
    'en_proceso',
    v_reason,
    auth.uid()
  );

  if v_ticket.status = 'finalizado' then
    update public.tickets
       set status = 'en_proceso'
     where id = v_ticket.id
       and tenant_id = v_tenant_id;

    insert into public.ticket_history (
      tenant_id,
      ticket_id,
      event_type,
      previous_status,
      new_status,
      reason,
      created_by
    ) values (
      v_tenant_id,
      v_ticket.id,
      'status_changed',
      'finalizado',
      'en_proceso',
      'Corrección administrativa: ' || v_reason,
      auth.uid()
    );
  end if;

  return query
  select ts.*
  from public.ticket_services ts
  where ts.id = v_service.id;
end;
$function$;

commit;
