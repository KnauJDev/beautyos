-- Salon y Mas - Marcar un negocio como de prueba (accion A5 de la Etapa A).
--
-- POR QUE
--
-- "Naguara de Unas" es el negocio del propio propietario, usado para probar
-- todo desde julio, y ademas tiene sembrada historia de febrero a agosto
-- (D-112). En el panel de plataforma se ve **exactamente igual** que un
-- cliente real.
--
-- Hoy da igual porque no hay clientes reales. **El dia que entre el primero,
-- ya sera tarde:** cualquier cifra que se mire -- cuantos negocios hay, cuanto
-- facturan, cuantos siguen despues de la prueba gratis -- vendra contaminada
-- con el propio, y nadie recordara descontarlo. Por eso D-112 dijo que esto
-- entra **antes** del primer cliente, no despues.
--
-- QUE HACE Y QUE NO
--
-- Es una **etiqueta**, no una restriccion. El negocio marcado sigue
-- funcionando exactamente igual: no pierde funciones, no se le corta nada, no
-- cambia su suscripcion. Lo unico que cambia es que **se puede distinguir**.
--
-- Se decidio marcarlo asi -- una columna en `tenants` -- y no borrando el
-- negocio ni creando uno nuevo "de verdad": la historia sembrada es lo que
-- permite ver funcionar las comparaciones del Dashboard, y tirarla para tener
-- un panel limpio seria cambiar una herramienta util por una cifra bonita.
--
-- NOTA LIGADA AL NUMERO DE TICKET (D-117)
--
-- Los 700 tickets numerados **incluyen los sembrados**. Cuando se borre la
-- semilla con `supabase/sql/160_borrar_semilla_demo.sql`, el primer ticket
-- real seria el 0000701. Se corrige con `set_ticket_numbering` devolviendo el
-- contador a 1 -- posible solo porque el propietario pidio que la numeracion
-- fuera ajustable. Con el consecutivo fijo de la especificacion original esto
-- no habria tenido arreglo.

begin;

-- ---------------------------------------------------------------------------
-- 1. La etiqueta.
-- ---------------------------------------------------------------------------

alter table public.tenants
  add column if not exists is_demo boolean not null default false;

comment on column public.tenants.is_demo
  is 'Negocio de prueba del propietario de la plataforma, no un cliente real (D-112). Es una etiqueta para no contaminar las metricas: no restringe nada.';

-- ---------------------------------------------------------------------------
-- 2. Marcar "Naguara de Unas".
--
--    Se busca por nombre porque es el unico negocio que existe, pero se
--    escribe de forma que **no falle ni marque de mas** si algun dia hubiera
--    varios con nombre parecido: se exige coincidencia exacta.
-- ---------------------------------------------------------------------------

update public.tenants
set is_demo = true
where name = 'Naguara de Uñas';

-- ---------------------------------------------------------------------------
-- 3. Que el panel de plataforma lo distinga.
--    DROP requerido: no se pueden agregar columnas a RETURNS TABLE.
-- ---------------------------------------------------------------------------

drop function if exists public.platform_list_tenants();

create or replace function public.platform_list_tenants()
returns table (
  tenant_id uuid,
  tenant_name text,
  contact_email text,
  whatsapp text,
  tenant_active boolean,
  is_demo boolean,
  plan_code text,
  subscription_status text,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
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
    t.id,
    t.name,
    t.contact_email,
    t.whatsapp,
    t.active,
    t.is_demo,
    p.code,
    ts.status,
    ts.trial_ends_at,
    ts.current_period_end,
    ts.grace_ends_at,
    t.created_at
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  -- Los de prueba van al final: el panel debe abrir mostrando clientes
  -- reales, no el negocio propio.
  order by t.is_demo, t.created_at desc;
end;
$$;

revoke all on function public.platform_list_tenants()
  from public, anon, authenticated;
grant execute on function public.platform_list_tenants()
  to authenticated;

comment on function public.platform_list_tenants()
  is 'Lista los negocios para el panel de plataforma, distinguiendo los de prueba (D-112). Cualquier rol de plataforma.';

commit;
