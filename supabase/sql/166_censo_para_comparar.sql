-- Salon y Mas - Censo para comparar produccion contra la copia restaurada.
--
-- PASO 2.2. Este guion es lo que de verdad prueba que un respaldo sirve.
--
-- ESTO NO ES UNA PRUEBA AUTOMATICA. Se ejecuta a mano DOS VECES:
--   1) contra PRODUCCION, antes de restaurar, y se guarda el resultado
--   2) contra la COPIA restaurada
-- Y se comparan las dos listas. **Si los numeros cuadran, el respaldo sirve.**
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\166_censo_para_comparar.sql"
--
-- ES DE SOLO LECTURA. No escribe, no borra, no cambia nada. Se puede ejecutar
-- contra produccion sin ningun riesgo.
--
-- POR QUE UNA SOLA LISTA DE "concepto | valor" Y NO VARIAS TABLAS: porque asi
-- comparar es mirar dos columnas de numeros, sin saber SQL. Un respaldo se
-- comprueba con evidencia que cualquiera pueda leer, no con la palabra de
-- quien lo ejecuto.
--
-- POR QUE HAY SUMAS DE DINERO Y NO SOLO CONTEOS DE FILAS: porque una fila
-- restaurada a medias sigue contando como una fila. Si el total cobrado del
-- negocio cuadra al peso, los datos llegaron enteros de verdad.

\echo ''
\echo '======================================================================'
\echo '  CENSO - anota o guarda esta lista y comparala con la otra base'
\echo '======================================================================'
\echo ''

select 'estructura: tablas en public'      as concepto,
       count(*)::text                       as valor
from pg_tables where schemaname = 'public'
union all
select 'estructura: funciones en public',
       count(*)::text
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
union all
select 'estructura: politicas de seguridad (RLS)',
       count(*)::text
from pg_policies where schemaname = 'public'
union all
select 'estructura: disparadores (triggers)',
       count(*)::text
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and not t.tgisinternal
union all
select 'estructura: indices',
       count(*)::text
from pg_indexes where schemaname = 'public'
union all

-- ---- El negocio, tabla por tabla -----------------------------------------
select 'datos: negocios (tenants)',            count(*)::text from public.tenants
union all
select 'datos: sedes',                         count(*)::text from public.branches
union all
select 'datos: estilistas del catalogo',       count(*)::text from public.stylists
union all
select 'datos: servicios',                     count(*)::text from public.services
union all
select 'datos: productos',                     count(*)::text from public.products
union all
select 'datos: clientes',                      count(*)::text from public.clients
union all
select 'datos: tickets',                       count(*)::text from public.tickets
union all
select 'datos: servicios dentro de tickets',   count(*)::text from public.ticket_services
union all
select 'datos: pagos de tickets',              count(*)::text from public.ticket_payments
union all
select 'datos: comisiones',                    count(*)::text from public.stylist_commissions
union all
select 'datos: compras',                       count(*)::text from public.purchases
union all
select 'datos: gastos',                        count(*)::text from public.expenses
union all
select 'datos: movimientos de inventario',     count(*)::text from public.inventory_movements
union all
select 'datos: resenas',                       count(*)::text from public.reviews
union all
select 'datos: fotos de trabajo',              count(*)::text from public.work_photos
union all
select 'datos: perfiles de usuario',           count(*)::text from public.user_profiles
union all
select 'datos: membresias de negocio',         count(*)::text from public.tenant_memberships
union all
select 'datos: membresias de sede',            count(*)::text from public.branch_memberships
union all
select 'datos: suscripciones',                 count(*)::text from public.tenant_subscriptions
union all

-- ---- El dinero. Aqui es donde se ve si los datos llegaron enteros --------
select 'DINERO: suma de todos los pagos',
       coalesce(sum(amount), 0)::text
from public.ticket_payments
union all
select 'DINERO: suma de servicios cobrados',
       coalesce(sum(price), 0)::text
from public.ticket_services
union all
select 'DINERO: suma de comisiones',
       coalesce(sum(commission_amount), 0)::text
from public.stylist_commissions
union all
select 'DINERO: suma de compras',
       coalesce(sum(total_amount), 0)::text
from public.purchases
union all
select 'DINERO: suma de gastos',
       coalesce(sum(amount), 0)::text
from public.expenses
union all

-- ---- Trazabilidad: los extremos del historial ----------------------------
select 'trazabilidad: primer ticket emitido',
       coalesce(min(ticket_code), '(ninguno)')
from public.tickets
union all
select 'trazabilidad: ultimo ticket emitido',
       coalesce(max(ticket_code), '(ninguno)')
from public.tickets
union all
select 'trazabilidad: ticket mas antiguo (fecha)',
       coalesce(min(created_at)::date::text, '(ninguno)')
from public.tickets
union all
select 'trazabilidad: ticket mas reciente (fecha)',
       coalesce(max(created_at)::date::text, '(ninguno)')
from public.tickets
union all

-- ---- Cuentas. Solo se cuentan: NUNCA se listan datos personales ----------
select 'cuentas: usuarios en auth',            count(*)::text from auth.users
union all
select 'cuentas: identidades en auth',         count(*)::text from auth.identities
union all
select 'archivos: almacenes (buckets)',        count(*)::text from storage.buckets
union all
select 'archivos: objetos registrados',        count(*)::text from storage.objects;

\echo ''
\echo '======================================================================'
\echo '  COMO SE LEE ESTO'
\echo '======================================================================'
\echo ''
\echo '  Ejecuta esta misma lista contra la copia restaurada y compara.'
\echo ''
\echo '  Las lineas DINERO son las que mas importan: una fila restaurada a'
\echo '  medias sigue contando como una fila, pero una suma que cuadra al'
\echo '  peso significa que los datos llegaron enteros.'
\echo ''
\echo '  DOS DIFERENCIAS SON NORMALES Y NO SON UN FALLO:'
\echo '    - archivos: objetos registrados -> el respaldo guarda la LISTA de'
\echo '      archivos, no los archivos. Las imagenes no viajan aqui (por eso'
\echo '      existe respaldo_archivos.ps1).'
\echo '    - estructura: indices y funciones pueden variar en unas pocas'
\echo '      unidades si el proyecto nuevo trae objetos internos propios.'
\echo ''
\echo '  CUALQUIER DIFERENCIA EN LAS LINEAS "datos:" O "DINERO:" SI ES UN'
\echo '  FALLO DEL RESPALDO, y hay que entenderla antes de darlo por bueno.'
\echo ''
