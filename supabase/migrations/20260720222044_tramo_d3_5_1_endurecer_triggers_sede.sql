-- BeautyOS - Tramo D3.5.1: retirar fallback de sede principal en escrituras.
--
-- Los seis triggers raiz y los dos triggers de ticket opcional llaman este
-- helper cuando no pueden heredar una sede desde un padre operativo. Desde
-- este tramo branch_id debe llegar explicito y pertenecer al tenant.
-- Los siete triggers derivados desde ticket o compra no se modifican.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function private.beautyos_resolve_branch(
  p_tenant_id uuid,
  -- Se conserva el default de la firma existente para reemplazar la funcion
  -- sin eliminar dependencias. El cuerpo rechaza siempre ese NULL.
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
begin
  if p_tenant_id is null then
    raise exception using
      errcode = '23502',
      message = 'No se puede validar una sede sin tenant.';
  end if;

  if p_branch_id is null then
    raise exception using
      errcode = '23502',
      message = 'La sede es obligatoria para la operacion.';
  end if;

  select b.id
    into v_branch_id
  from public.branches b
  where b.tenant_id = p_tenant_id
    and b.id = p_branch_id;

  if v_branch_id is null then
    raise exception using
      errcode = '23503',
      message = 'La sede no pertenece al tenant indicado.';
  end if;

  return v_branch_id;
end;
$$;

revoke all on function private.beautyos_resolve_branch(uuid, uuid)
  from public, anon, authenticated;

comment on function private.beautyos_resolve_branch(uuid, uuid)
  is 'Valida una sede explicita del tenant; NULL falla y no selecciona sede principal.';

commit;
