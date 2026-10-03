-- Lectura: ¿por qué "Para invitar hoy" no sale en Peluquería Éxito Prueba?
-- (D-314, paso 4B, 03-oct). NO MODIFICA NADA: TERMINA EN ROLLBACK.
--
-- LO QUE SE VIO. Con la versión nueva cargada (en Servicios sí sale el campo
-- "Invitar a volver a los … días", y Corte de Cabello quedó en 1 día), la
-- Agenda no enseña la tarjeta y Clientes no enseña los filtros. Hay dos
-- explicaciones y esta lectura dice cuál, sin adivinar:
--   1. Ninguna clienta cumple: por servicio, cuántas clientas se lo hicieron
--      (cita finalizado/cerrado con el servicio finalizado), la más reciente
--      y la más vieja, y su tiempo de volver. Sin nombres.
--   2. La función falla para el dueño: se la llama como él y se cuenta lo que
--      devuelve, o se copia el error.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_para_invitar_4b.sql"

begin;

do $lectura$
declare
  v_sede    uuid := '978ee07d-41c1-491e-aee4-8598e1452d34';
  v_tenant  uuid;
  v_dueno   uuid;
  v_n       integer;
  v_toca    integer;
  v_error   text;
  r         record;
begin
  select b.tenant_id into v_tenant from public.branches b where b.id = v_sede;
  raise notice '0. Tiempo de volver del salon: % dias',
    (select t.return_default_days from public.tenants t where t.id = v_tenant);

  for r in
    select s.name as servicio,
           s.return_after_days as propio,
           count(distinct t.client_id) as clientas,
           min(t.scheduled_at) as mas_vieja,
           max(t.scheduled_at) as mas_reciente,
           string_agg(distinct t.status, ',') as estados_cita,
           string_agg(distinct ts.status, ',') as estados_servicio
    from public.tickets t
    join public.ticket_services ts on ts.ticket_id = t.id and ts.tenant_id = t.tenant_id
    join public.services s on s.id = ts.service_id
    where t.tenant_id = v_tenant
      and t.branch_id = v_sede
      and t.status in ('finalizado', 'cerrado')
    group by s.name, s.return_after_days
    order by s.name
  loop
    raise notice '1. % | tiempo propio=% | clientas=% | mas vieja=% | mas reciente=% | citas=% | servicios=%',
      r.servicio, coalesce(r.propio::text, 'del salon'), r.clientas,
      to_char(r.mas_vieja at time zone 'America/Bogota', 'DD-MM HH24:MI'),
      to_char(r.mas_reciente at time zone 'America/Bogota', 'DD-MM HH24:MI'),
      r.estados_cita, r.estados_servicio;
  end loop;

  select tm.user_id into v_dueno
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant and tm.role = 'tenant_owner' and tm.active
  limit 1;

  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
    select count(*), count(*) filter (where x.toca_hoy)
      into v_n, v_toca
    from public.get_return_invitations(v_sede) x;
  exception when others then
    v_error := sqlerrm;
  end;

  raise notice '2. Como el dueno: la funcion devuelve % fila(s), % para hoy, error = %',
    v_n, v_toca, coalesce(v_error, 'ninguno');

  perform set_config('request.jwt.claims', '{}', true);
end
$lectura$;

rollback;
