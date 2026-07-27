-- BeautyOS - Correo automatico de invitacion de equipo (D-062).
--
-- La Edge Function que envia el correo (Resend) no debe leer
-- public.team_invitations directamente: la tabla no tiene grants para
-- authenticated/anon (revocado en 20260723173701). Esta funcion expone
-- solo lo que el correo necesita mostrar, y solo a quien creo la propia
-- invitacion (mismo momento del flujo, sin abrir un canal nuevo de
-- autorizacion).

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

commit;
