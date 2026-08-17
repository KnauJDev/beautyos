-- ==============================================================================
-- Migracion: Disparador diario real de avisos de vencimiento (cierre de 3.11)
-- ==============================================================================
-- Hasta ahora `send-subscription-expiry-alerts` existia y estaba bien blindada
-- (CRON_SECRET obligatorio, D-143) pero nadie la llamaba sola: alguien tenia
-- que dispararla a mano. Esta migracion programa una tarea diaria con
-- `pg_cron` que la invoca por HTTP usando `pg_net`.
--
-- EL SECRETO NO VIVE EN ESTE ARCHIVO. `CRON_SECRET` ya existe como variable
-- de entorno de la Edge Function (D-143); aqui se guarda una SEGUNDA copia
-- del mismo valor en Supabase Vault, cifrada, para que el trabajo programado
-- pueda enviarla en la cabecera `x-cron-secret` sin que el valor quede
-- escrito en texto plano en ningun archivo versionado.
--
-- PASO MANUAL OBLIGATORIO ANTES O DESPUES DE APLICAR ESTA MIGRACION (fuera de
-- git, en el Editor SQL de Supabase, una sola vez):
--
--   select vault.create_secret(
--     '<el mismo valor exacto que CRON_SECRET en los secretos de la funcion>',
--     'cron_secret_subscription_alerts',
--     'Secreto usado por pg_cron para llamar a send-subscription-expiry-alerts'
--   );
--
-- Si el nombre 'cron_secret_subscription_alerts' ya existe, usar en su lugar:
--   select vault.update_secret(
--     (select id from vault.secrets where name = 'cron_secret_subscription_alerts'),
--     '<valor nuevo>'
--   );
--
-- Sin ese paso, la tarea programada corre igual pero la Edge Function
-- respondera 401 (fail-closed, D-143) porque no llegara ningun secreto valido
-- en la cabecera -- fallo visible en los logs de la funcion, no un error
-- silencioso.
-- ==============================================================================

-- 1. Extensiones necesarias (ya soportadas por Supabase; no tocan datos).
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- 2. Reprogramable: si ya existe una tarea con este nombre (re-aplicar esta
--    migracion, o un cambio de horario futuro), se reemplaza en vez de
--    duplicarla.
do $$
begin
  if exists (
    select 1 from cron.job where jobname = 'avisos_vencimiento_suscripcion_diario'
  ) then
    perform cron.unschedule('avisos_vencimiento_suscripcion_diario');
  end if;
end;
$$;

-- 3. Tarea diaria a las 08:00 hora Colombia (13:00 UTC, sin horario de
--    verano). Llama a la Edge Function con el secreto leido desde Vault por
--    NOMBRE, nunca por valor escrito aqui.
select cron.schedule(
  'avisos_vencimiento_suscripcion_diario',
  '0 13 * * *',
  $cron$
  select net.http_post(
    url := 'https://eogppgbdnwxdtcbctaol.supabase.co/functions/v1/send-subscription-expiry-alerts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'cron_secret_subscription_alerts'
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 25000
  ) as request_id;
  $cron$
);

comment on extension pg_cron is
  'Programa la tarea diaria de avisos de vencimiento y suspension automatica (D-143/3.11).';
