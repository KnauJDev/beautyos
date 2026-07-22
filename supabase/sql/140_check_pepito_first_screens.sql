-- BeautyOS - Verificacion de solo lectura: RPC que un owner recien
-- registrado toca en sus primeras pantallas (Dashboard, Configuracion).
-- Usa la sesion real de elboga000@gmail.com contra su tenant real
-- "Pepito Pelos y Uñas". Sin escrituras, no requiere rollback.

select set_config(
  'request.jwt.claim.sub',
  '2975e198-2f33-4cd3-a3f2-4d93eb517118',
  true
);

select 'get_my_profile' as rpc, count(*) as filas from public.get_my_profile()
union all
select 'get_my_branch_context_v2', count(*) from public.get_my_branch_context_v2()
union all
select 'get_business_settings', count(*) from public.get_business_settings()
union all
select 'get_commission_policy', count(*) from public.get_commission_policy();

-- Estas dos exigen p_branch_id: se prueban aparte con la sede real.
select 'get_dashboard_metrics_v2' as rpc, count(*) as filas
from public.get_dashboard_metrics_v2('9e7c2c18-c6b1-4357-9399-56d35c6c9711')
union all
select 'get_appointment_policy_v2', count(*)
from public.get_appointment_policy_v2('9e7c2c18-c6b1-4357-9399-56d35c6c9711')
union all
select 'get_business_hours_v2', count(*)
from public.get_business_hours_v2('9e7c2c18-c6b1-4357-9399-56d35c6c9711');
