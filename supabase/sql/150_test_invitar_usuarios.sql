-- BeautyOS - Prueba real (con rollback) del flujo de invitacion de
-- equipo, contra el tenant real "Cortes y Barbas". No persiste nada.

begin;

select set_config(
  'request.jwt.claim.sub',
  '54403360-f1e3-4475-95c5-607368f3e8a7', -- amanteperfumes@gmail.com, owner
  true
);

-- 1. Invitar a un estilista vinculado a un estilista real del catalogo.
select * from public.create_team_invitation(
  'a12dcc83-c6fd-4f87-a824-2c4e98e11f33', -- branch
  'juankdev2026@gmail.com',
  'stylist',
  'db2bbd57-0b7c-4818-95b7-f578f231c5e6' -- Nicolas Alonso
);

-- 2. Invitar sin stylist_id para rol stylist debe fallar.
do $$
begin
  perform public.create_team_invitation(
    'a12dcc83-c6fd-4f87-a824-2c4e98e11f33', 'otro@correo.test', 'stylist'
  );
  raise exception 'FALLA: debio exigir stylist_id para rol stylist.';
exception
  when others then
    if sqlerrm not ilike '%selecciona a que estilista%' then raise; end if;
end;
$$;

-- 3. Invitar un correo duplicado (misma invitacion pendiente) debe fallar.
do $$
begin
  perform public.create_team_invitation(
    'a12dcc83-c6fd-4f87-a824-2c4e98e11f33', 'juankdev2026@gmail.com', 'assistant'
  );
  raise exception 'FALLA: no debio permitir invitacion duplicada pendiente.';
exception
  when others then
    if sqlerrm not ilike '%ya existe una invitacion pendiente%' then raise; end if;
end;
$$;

-- 4. list_team_invitations la muestra.
select count(*) as invitaciones_pendientes
from public.list_team_invitations('a12dcc83-c6fd-4f87-a824-2c4e98e11f33')
where status = 'pending';

-- 5. La persona invitada (juankdev2026, sesion propia) ve su invitacion.
select set_config('request.jwt.claim.sub', 'dbee91f0-36e0-4bd8-9303-fe173418ba55', true);

select * from public.get_my_pending_invitation();

-- 6. Aceptarla crea perfil, membresia de tenant y de sede correctamente.
select * from public.accept_team_invitation('Juan Aceptando Prueba');

select
  up.role as profile_role, up.stylist_id as profile_stylist_id,
  tm.role as membership_role, tm.stylist_id as membership_stylist_id,
  bm.branch_id
from public.user_profiles up
join public.tenant_memberships tm on tm.user_id = up.user_id and tm.tenant_id = up.tenant_id
join public.branch_memberships bm on bm.tenant_membership_id = tm.id
where up.user_id = 'dbee91f0-36e0-4bd8-9303-fe173418ba55';

-- 7. Un segundo intento de aceptar (ya tiene membresia) debe fallar.
do $$
begin
  perform public.accept_team_invitation('Otra vez');
  raise exception 'FALLA: no debio poder aceptar dos veces.';
exception
  when others then
    if sqlerrm not ilike '%ya pertenece a un negocio%' then raise; end if;
end;
$$;

rollback;
