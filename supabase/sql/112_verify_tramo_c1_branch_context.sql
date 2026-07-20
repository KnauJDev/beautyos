-- BeautyOS - Auditoria de solo lectura del Tramo C1.

do $$
begin
  if to_regprocedure(
    'private.beautyos_resolve_branch_access(uuid,text[],boolean)'
  ) is null then
    raise exception 'Falta el resolver privado de sede efectiva.';
  end if;

  if to_regprocedure('public.get_my_branch_context_v2()') is null then
    raise exception 'Falta la RPC de contextos de sede.';
  end if;

  if has_function_privilege(
    'anon',
    'public.get_my_branch_context_v2()',
    'EXECUTE'
  ) then
    raise exception 'Anon no debe ejecutar get_my_branch_context_v2.';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.get_my_branch_context_v2()',
    'EXECUTE'
  ) then
    raise exception 'Authenticated debe ejecutar get_my_branch_context_v2.';
  end if;

  if has_function_privilege(
    'authenticated',
    'private.beautyos_resolve_branch_access(uuid,text[],boolean)',
    'EXECUTE'
  ) then
    raise exception 'El resolver privado no debe ser ejecutable directamente.';
  end if;
end;
$$;

select
  p.oid::regprocedure::text as function_signature,
  p.prosecdef as security_definer,
  p.proconfig as function_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where (n.nspname, p.proname) in (
  ('private', 'beautyos_resolve_branch_access'),
  ('public', 'get_my_branch_context_v2')
)
order by function_signature;
