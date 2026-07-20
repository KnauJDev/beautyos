-- BeautyOS - Inventario de solo lectura previo al retiro D3.

begin;
set transaction read only;

select
  count(*) as legacy_authenticated,
  count(*) filter (where p.prosecdef) as security_definer,
  count(*) filter (
    where has_function_privilege('anon', p.oid, 'execute')
  ) as anon_executable,
  count(*) filter (
    where has_function_privilege('authenticated', p.oid, 'execute')
  ) as authenticated_executable,
  count(*) filter (
    where has_function_privilege('public', p.oid, 'execute')
  ) as public_executable
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and right(p.proname, 3) <> '_v2'
  and has_function_privilege('authenticated', p.oid, 'execute');

select
  p.oid::regprocedure as signature,
  p.prosecdef as security_definer,
  pg_get_userbyid(p.proowner) as owner,
  has_function_privilege('anon', p.oid, 'execute') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'execute')
    as authenticated_execute,
  has_function_privilege('public', p.oid, 'execute') as public_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and right(p.proname, 3) <> '_v2'
  and has_function_privilege('authenticated', p.oid, 'execute')
order by p.proname, pg_get_function_identity_arguments(p.oid);

select
  r.relname as table_name,
  t.tgname,
  t.tgenabled,
  p.oid::regprocedure as trigger_function
from pg_trigger t
join pg_class r on r.oid = t.tgrelid
join pg_namespace n on n.oid = r.relnamespace
join pg_proc p on p.oid = t.tgfoid
where n.nspname = 'public'
  and not t.tgisinternal
  and t.tgname like '%_set_branch'
order by r.relname;

rollback;
