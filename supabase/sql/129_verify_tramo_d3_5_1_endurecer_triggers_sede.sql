-- BeautyOS - Verificacion de solo lectura D3.5.1.

begin;
set transaction read only;

do $$
declare
  v_definition text;
  v_arguments text;
  v_expected_count integer;
begin
  if to_regprocedure('private.beautyos_resolve_branch(uuid,uuid)') is null then
    raise exception 'D3.5.1: falta el helper estricto de sede.';
  end if;

  select pg_get_functiondef(to_regprocedure(
           'private.beautyos_resolve_branch(uuid,uuid)'
         )),
         pg_get_function_arguments(to_regprocedure(
           'private.beautyos_resolve_branch(uuid,uuid)'
         ))
    into v_definition, v_arguments;

  if position('p_branch_id is null' in lower(v_definition)) = 0
     or position('is_primary' in lower(v_definition)) > 0 then
    raise exception 'D3.5.1: el helper aun permite resolver sede principal.';
  end if;

  begin
    perform private.beautyos_resolve_branch(
      (select b.tenant_id from public.branches b order by b.id limit 1)
    );
    raise exception 'D3.5.1: el helper acepto la omision de branch_id.';
  exception
    when not_null_violation then
      if position('sede es obligatoria' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  if has_function_privilege('anon',
       'private.beautyos_resolve_branch(uuid,uuid)', 'EXECUTE')
     or has_function_privilege('authenticated',
       'private.beautyos_resolve_branch(uuid,uuid)', 'EXECUTE') then
    raise exception 'D3.5.1: privilegios de cliente inesperados.';
  end if;

  select count(*)
    into v_expected_count
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and t.tgname like '%\_set\_branch' escape '\'
    and not t.tgisinternal
    and t.tgenabled <> 'D';

  if v_expected_count <> 15 then
    raise exception 'D3.5.1: se esperaban 15 triggers activos y existen %.',
      v_expected_count;
  end if;
end;
$$;

select
  p.oid::regprocedure as signature,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_get_function_arguments(p.oid) as arguments,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE')
    as authenticated_execute
from pg_proc p
where p.oid = to_regprocedure(
  'private.beautyos_resolve_branch(uuid,uuid)'
);

rollback;
