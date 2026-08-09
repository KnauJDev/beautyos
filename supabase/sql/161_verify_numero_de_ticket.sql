-- Verificacion de la tarea 2.6a: numero de ticket consecutivo (D-117).
--
-- Se ejecuta DESPUES de aplicar
-- supabase/migrations/20260809160000_numero_de_ticket_consecutivo.sql
--
-- Es de SOLO LECTURA salvo la seccion 6, que hace una prueba real de escritura
-- y termina en ROLLBACK. Nada de lo que hay aqui deja rastro en produccion.

-- ---------------------------------------------------------------------------
-- 1. Ningun ticket se quedo sin numero. Debe devolver 0.
-- ---------------------------------------------------------------------------
select count(*) as tickets_sin_numero
from public.tickets
where ticket_number is null
   or ticket_code is null
   or ticket_code = '';

-- ---------------------------------------------------------------------------
-- 2. No hay numeros repetidos dentro de un mismo negocio. Debe devolver 0 filas.
-- ---------------------------------------------------------------------------
select tenant_id, ticket_number, count(*) as veces
from public.tickets
group by tenant_id, ticket_number
having count(*) > 1;

-- ---------------------------------------------------------------------------
-- 3. La numeracion es continua y empieza en 1 por negocio.
--    'primero' debe ser 1 y 'ultimo' debe ser igual a 'cuantos'.
-- ---------------------------------------------------------------------------
select
  t.name as negocio,
  count(tk.id) as cuantos,
  min(tk.ticket_number) as primero,
  max(tk.ticket_number) as ultimo,
  case
    when count(tk.id) = 0 then 'sin tickets'
    when min(tk.ticket_number) = 1
     and max(tk.ticket_number) = count(tk.id) then 'continua'
    else 'REVISAR'
  end as veredicto
from public.tenants t
left join public.tickets tk on tk.tenant_id = t.id
group by t.id, t.name
order by t.name;

-- ---------------------------------------------------------------------------
-- 4. El orden del consecutivo respeta el orden de creacion.
--    Debe devolver 0 filas: ningun ticket creado antes lleva numero mayor.
-- ---------------------------------------------------------------------------
with ordenado as (
  select
    tenant_id,
    ticket_number,
    created_at,
    lag(created_at) over (partition by tenant_id order by ticket_number)
      as creado_anterior
  from public.tickets
)
select *
from ordenado
where creado_anterior is not null
  and created_at < creado_anterior;

-- ---------------------------------------------------------------------------
-- 5. Cada negocio tiene su contador y apunta al siguiente libre.
--    'siguiente' debe ser exactamente 'ultimo_emitido' + 1.
-- ---------------------------------------------------------------------------
select
  t.name as negocio,
  n.prefix as prefijo,
  n.padding as digitos,
  n.next_number as siguiente,
  coalesce(max(tk.ticket_number), 0) as ultimo_emitido,
  case
    when n.next_number = coalesce(max(tk.ticket_number), 0) + 1
      then 'correcto'
    when n.next_number > coalesce(max(tk.ticket_number), 0)
      then 'ajustado a mano, sin choque'
    else 'REVISAR: choca con uno ya emitido'
  end as veredicto
from public.tenants t
join public.tenant_ticket_numbering n on n.tenant_id = t.id
left join public.tickets tk on tk.tenant_id = t.id
group by t.id, t.name, n.prefix, n.padding, n.next_number
order by t.name;

-- ---------------------------------------------------------------------------
-- 6. Prueba de escritura. Termina en ROLLBACK: no deja nada.
--
--    Comprueba las dos reglas que no se pueden ver mirando datos:
--      a) un ticket nuevo recibe el siguiente numero solo
--      b) un numero ya emitido NO se puede cambiar
-- ---------------------------------------------------------------------------
begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_client uuid;
  v_esperado bigint;
  v_ticket public.tickets%rowtype;
  v_fallo text;
begin
  select t.id into v_tenant
  from public.tenants t
  where t.active
  order by t.created_at
  limit 1;

  select b.id into v_branch
  from public.branches b
  where b.tenant_id = v_tenant and b.active
  order by b.is_primary desc
  limit 1;

  select c.id into v_client
  from public.clients c
  where c.tenant_id = v_tenant and c.active
  limit 1;

  if v_tenant is null or v_branch is null or v_client is null then
    raise notice 'Sin datos suficientes para la prueba de escritura.';
    return;
  end if;

  select n.next_number into v_esperado
  from public.tenant_ticket_numbering n
  where n.tenant_id = v_tenant;

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel)
  values (v_tenant, v_branch, v_client, 'solicitado', 'manual')
  returning * into v_ticket;

  if v_ticket.ticket_number is distinct from v_esperado then
    raise exception
      'FALLO (a): se esperaba el numero %, llego %',
      v_esperado, v_ticket.ticket_number;
  end if;

  raise notice 'OK (a): el ticket nuevo recibio el numero % (codigo %)',
    v_ticket.ticket_number, v_ticket.ticket_code;

  -- Ahora se intenta reescribirlo. Tiene que fallar.
  begin
    update public.tickets
    set ticket_number = 999999
    where id = v_ticket.id;

    raise exception 'FALLO (b): se pudo cambiar el numero de un ticket emitido';
  exception
    when others then
      v_fallo := sqlerrm;

      if v_fallo like 'FALLO (b)%' then
        raise;
      end if;

      raise notice 'OK (b): la base rechazo el cambio -> %', v_fallo;
  end;
end;
$$;

rollback;
