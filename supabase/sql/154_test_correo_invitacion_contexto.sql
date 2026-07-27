-- Prueba con rollback: get_team_invitation_email_context (D-062).
-- No persiste nada: crea la funcion dentro de la transaccion, la
-- ejercita con 3 escenarios reales y revierte todo al final.

begin;

create or replace function public.get_team_invitation_email_context(
  p_invitation_id uuid
)
returns table (
  email text,
  role text,
  tenant_name text,
  branch_name text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception 'Se requiere una sesion autenticada.';
  end if;

  return query
  select ti.email, ti.role, t.name, b.name, ti.expires_at
  from public.team_invitations ti
  join public.tenants t on t.id = ti.tenant_id
  join public.branches b on b.id = ti.branch_id
  where ti.id = p_invitation_id
    and ti.invited_by = auth.uid()
    and ti.status = 'pending';
end;
$$;

revoke all on function public.get_team_invitation_email_context(uuid)
  from public, anon;
grant execute on function public.get_team_invitation_email_context(uuid)
  to authenticated;

-- Escenario 1: quien creo la invitacion (invited_by real) ve el contexto.
select set_config('request.jwt.claim.sub', '0991e9d3-94a7-4a86-bb5e-14f53c3353f0', true);
select 'escenario_1_invited_by' as caso, *
from public.get_team_invitation_email_context('af49468d-df80-4dc9-a2b0-d58273435687');

-- Escenario 2: otro usuario real (no invited_by) no ve nada (0 filas).
select set_config('request.jwt.claim.sub', 'dbee91f0-36e0-4bd8-9303-fe173418ba55', true);
select 'escenario_2_otro_usuario' as caso, *
from public.get_team_invitation_email_context('af49468d-df80-4dc9-a2b0-d58273435687');

-- Escenario 3: sin sesion, debe fallar con excepcion (se atrapa aqui
-- mismo para no abortar la transaccion antes del rollback).
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform * from public.get_team_invitation_email_context('af49468d-df80-4dc9-a2b0-d58273435687');
  raise exception 'FALLO: deberia haber lanzado excepcion sin sesion';
exception
  when others then
    if sqlerrm = 'Se requiere una sesion autenticada.' then
      raise notice 'escenario_3_sin_sesion: OK, rechazado como se esperaba';
    else
      raise;
    end if;
end;
$$;

rollback;
