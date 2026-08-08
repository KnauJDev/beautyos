-- Salon y Mas - Borrar la historia de ensayo (D-112).
--
-- Deshace `20260808180000_datos_de_ensayo_naguara.sql`. **No se ejecuta solo:**
-- vive aqui, en `supabase/sql/`, para correrlo a mano el dia que estorbe --
-- tipicamente antes de ensenarle el sistema al primer cliente real.
--
-- Solo borra lo marcado con `SEMILLA_DEMO`. Las citas reales del negocio, que
-- empiezan el 27 de julio de 2026, **no se tocan**: no llevan esa marca.
--
-- El orden es obligatorio: primero los cobros, despues los servicios, despues
-- los tickets y al final las clientas. Al reves, las llaves foraneas lo
-- impiden -- que es justamente lo que se quiere, porque significa que no puede
-- quedar un cobro huerfano.

begin;

-- Cuenta antes, para poder comparar.
select
  (select count(*) from public.ticket_payments where notes = 'SEMILLA_DEMO') as cobros,
  (select count(*) from public.ticket_services ts
     join public.tickets t on t.id = ts.ticket_id
    where t.notes = 'SEMILLA_DEMO') as servicios,
  (select count(*) from public.tickets where notes = 'SEMILLA_DEMO') as citas,
  (select count(*) from public.clients where notes = 'SEMILLA_DEMO') as clientas;

delete from public.ticket_payments
where notes = 'SEMILLA_DEMO';

delete from public.ticket_services ts
using public.tickets t
where t.id = ts.ticket_id
  and t.notes = 'SEMILLA_DEMO';

delete from public.tickets
where notes = 'SEMILLA_DEMO';

-- Las clientas se borran de ultimas y solo si no quedaron con citas reales
-- encima: si alguna paso de ser inventada a atender de verdad, se conserva.
delete from public.clients c
where c.notes = 'SEMILLA_DEMO'
  and not exists (
    select 1 from public.tickets t where t.client_id = c.id
  );

commit;
