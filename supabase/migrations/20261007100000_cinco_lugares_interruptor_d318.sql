-- ==============================================================================
-- Paso 6 del plan de David (D-308): el interruptor de LOS CINCO LUGARES. (D-318)
-- ==============================================================================
--
-- QUÉ PASA
--
-- El propietario aprobó el 07-oct, vista por vista, la nueva forma de la app:
-- Agenda · Clientes · Mi negocio · Mi vitrina · Ajustes (D-318). Reordenar la
-- navegación cambia la rutina de TODOS los salones a la vez, y la regla es
-- probar primero en el espejo (Peluquería Éxito Prueba). Por eso llega detrás
-- de un interruptor, y este interruptor NACE APAGADO: el Panel lo enciende
-- salón por salón (una excepción con enabled = true), empezando por el espejo.
--
-- A diferencia de las capacidades de D-310, que nacieron ENCENDIDAS para que
-- nadie notara nada, esta nace APAGADA en los cuatro planes, por la misma
-- razón: que nadie note nada hasta que el propietario decida.
--
-- QUÉ CAMBIA, Y QUÉ NO
--
--   Solo se AÑADEN filas: una en `features` y una por plan en `plan_features`,
--   con enabled = false. No se reescribe ninguna función ni se toca ninguna
--   fila existente. `on conflict do nothing`: correrla dos veces no hace nada.
--   Encenderla a un salón usa `platform_set_tenant_feature_override`, que ya
--   acepta enabled = true y deja su evento en el historial.
--
-- Lo prueba el CONTROL 245.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

insert into public.features (key, name, description) values
  ('cinco_lugares', 'Los cinco lugares',
   'La app en cinco lugares: Agenda, Clientes, Mi negocio, Mi vitrina y Ajustes (D-318). Nace apagada; se enciende salón por salón.')
on conflict (key) do nothing;

insert into public.plan_features (plan_id, feature_id, enabled)
select p.id, f.id, false
from public.plans p
cross join public.features f
where f.key = 'cinco_lugares'
on conflict (plan_id, feature_id) do nothing;

commit;
