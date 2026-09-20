-- Extrae el texto VIVO de `public.change_ticket_service_status`.
--
-- POR QUE. La regla del proyecto dice que al reescribir una funcion hay que
-- sacar primero su texto actual y comparar linea por linea (D-119, D-122,
-- D-123: tres fallos en un mismo dia por reescribir de memoria). Y aqui pesa
-- doble: el hallazgo AI dejo escrito que el repositorio **no** es la fuente
-- del esquema. Esta funcion nacio en `supabase/sql/071`, que es de julio.
--
-- NO MODIFICA NADA. Solo lee el catalogo y escribe un archivo en el disco.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_cambio_de_estado_de_servicio.sql
select pg_get_functiondef(
  'public.change_ticket_service_status(uuid, text)'::regprocedure
);
\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. El texto vivo quedo en:'
\echo '  C:\Proyectos\salonymas\_vivo_cambio_de_estado_de_servicio.sql'
