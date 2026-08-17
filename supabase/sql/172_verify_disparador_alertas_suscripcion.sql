-- ==============================================================================
-- Control 172: Verificacion del disparador diario de avisos de suscripcion
-- ==============================================================================
-- Solo LEE estado ya aplicado (extensiones, tarea programada, secreto en
-- Vault). No crea ni borra nada -- a diferencia de los controles 170/171, no
-- hace falta BEGIN/ROLLBACK porque no escribe.
-- ==============================================================================

do $$
declare
  v_extensiones_ok boolean;
  v_job record;
  v_secreto_existe boolean;
begin
  raise notice 'Iniciando Control 172...';

  -- 1. Extensiones pg_cron y pg_net instaladas
  select
    (count(*) filter (where extname = 'pg_cron') = 1)
    and (count(*) filter (where extname = 'pg_net') = 1)
    into v_extensiones_ok
  from pg_extension;

  if not v_extensiones_ok then
    raise exception 'Fallo: pg_cron y/o pg_net no estan instaladas.';
  end if;
  raise notice '✅ pg_cron y pg_net instaladas.';

  -- 2. La tarea diaria existe, esta activa y apunta a la funcion correcta
  select * into v_job
  from cron.job
  where jobname = 'avisos_vencimiento_suscripcion_diario';

  if v_job.jobid is null then
    raise exception 'Fallo: no existe la tarea avisos_vencimiento_suscripcion_diario.';
  end if;

  if not v_job.active then
    raise exception 'Fallo: la tarea existe pero esta INACTIVA.';
  end if;

  if v_job.schedule != '0 13 * * *' then
    raise exception 'Fallo: horario inesperado (%). Se esperaba "0 13 * * *".', v_job.schedule;
  end if;

  if v_job.command not like '%send-subscription-expiry-alerts%' then
    raise exception 'Fallo: la tarea no apunta a send-subscription-expiry-alerts.';
  end if;

  if v_job.command not like '%x-cron-secret%' then
    raise exception 'Fallo: la tarea no envia la cabecera x-cron-secret.';
  end if;

  raise notice '✅ Tarea programada activa: % (horario %).', v_job.jobname, v_job.schedule;

  -- 3. El secreto ya se guardo en Vault (sin imprimir su valor)
  select exists (
    select 1 from vault.decrypted_secrets
    where name = 'cron_secret_subscription_alerts'
  ) into v_secreto_existe;

  if not v_secreto_existe then
    raise warning '⚠️ Falta el paso manual: aun no existe el secreto '
      '"cron_secret_subscription_alerts" en Vault. La tarea correra pero la '
      'Edge Function respondera 401 hasta que se guarde con vault.create_secret(...).';
  else
    raise notice '✅ El secreto "cron_secret_subscription_alerts" ya existe en Vault.';
  end if;

  raise notice '==================================================';
  raise notice 'CONTROL 172 COMPLETADO (ver avisos arriba si el secreto falta).';
  raise notice '==================================================';
end;
$$;
