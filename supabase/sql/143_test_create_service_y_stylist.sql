-- BeautyOS - Prueba real (con rollback) de create_service/create_stylist
-- contra el esquema vivo, usando la sesion real de elboga002@gmail.com
-- (tenant "Pelos y Tijeras"). No persiste nada: termina en rollback.

begin;

select set_config(
  'request.jwt.claim.sub',
  '915b2d28-abd3-49d5-a0cf-bd105ce5a9bf',
  true
);

-- 1. Crear un servicio deja el catalogo del tenant y la fila de sede
--    consistentes.
select * from public.create_service(
  'c8cdbb05-f406-4fb4-a9b4-edd8362ee936',
  'Corte clasico',
  'Cabello',
  30,
  35000
);

select
  s.name, s.duration_minutes, s.price, s.visible_to_customer,
  bs.branch_id, bs.price as branch_price, bs.duration_minutes as branch_duration
from public.services s
join public.branch_services bs on bs.service_id = s.id
where s.tenant_id = '258c2a65-902a-460a-8a89-f8939b4501f9'
  and s.name = 'Corte clasico';

-- 2. Nombre vacio debe fallar.
do $$
begin
  perform public.create_service(
    'c8cdbb05-f406-4fb4-a9b4-edd8362ee936', '', 'Cabello', 30, 35000
  );
  raise exception 'FALLA: no debio permitir un nombre vacio.';
exception
  when others then
    if sqlerrm not ilike '%nombre del servicio es obligatorio%' then
      raise;
    end if;
end;
$$;

-- 3. Crear un estilista deja el catalogo del tenant y la fila de sede
--    consistentes.
select * from public.create_stylist(
  'c8cdbb05-f406-4fb4-a9b4-edd8362ee936',
  'Ana Estilista',
  '3001112233',
  'Color'
);

select
  st.name, st.phone, st.specialty,
  bst.branch_id, bst.active
from public.stylists st
join public.branch_stylists bst on bst.stylist_id = st.id
where st.tenant_id = '258c2a65-902a-460a-8a89-f8939b4501f9'
  and st.name = 'Ana Estilista';

-- 4. Un usuario sin membresia en este tenant no puede crear nada aqui.
select set_config(
  'request.jwt.claim.sub',
  '2975e198-2f33-4cd3-a3f2-4d93eb517118',
  true
);

do $$
begin
  perform public.create_service(
    'c8cdbb05-f406-4fb4-a9b4-edd8362ee936', 'Intento ajeno', 'Cabello', 30, 10000
  );
  raise exception 'FALLA: un usuario de otro tenant no debio poder crear un servicio aqui.';
exception
  when others then
    if sqlerrm not ilike '%contexto de sede no esta disponible%' then
      raise;
    end if;
end;
$$;

rollback;
