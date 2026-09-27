-- ============================================================================
-- AU (D-286), paso 9.48: "Mis fotos de trabajos" cumple lo que promete el
-- interruptor "Visible al cliente".
--
-- LA DECISIÓN DEL PROPIETARIO (27-sep): en su portal, la clienta ve TODA foto
-- que el salón le marque como visible, esté o no en el portafolio, con una
-- marca que distinga las publicadas en la página del salón.
--
-- LO QUE PASABA: `get_client_portal_data` exigía `photo_url is not null`, y
-- esa dirección solo existe cuando la foto está publicada. Se vio dos veces:
-- el 18-sep (AU) y el 27-sep, cuando Juan Carlos retiró su foto del
-- portafolio y dejó de verla también en su propio portal; la de David Alonso,
-- visible desde el 18-sep, nunca se le mostró.
--
-- QUÉ CAMBIA, contra el texto VIVO (`extraer_portal_mis_fotos_au.sql`,
-- 27-sep, comparado con `diff`): dos cosas y nada más.
--   1. Se quita `and wp.photo_url is not null`.
--   2. Cada foto gana `in_portfolio`.
-- Las fotos privadas llegan sin dirección; la app pide una URL temporal a la
-- Edge Function `client-consent-photo-url` (D-281), que ya existe y ya
-- comprueba con el token que la foto es de ella. No hace falta función nueva.
--
-- Mismo nombre, mismos parámetros, mismo tipo de retorno (jsonb): basta
-- `create or replace`, y los permisos vivos (anon, authenticated) se
-- conservan.
-- ============================================================================

begin;

CREATE OR REPLACE FUNCTION public.get_client_portal_data(p_tenant_id uuid, p_phone text, p_portal_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_phone_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_client public.clients%rowtype;
begin
  select *
    into v_client
  from public.clients c
  where c.tenant_id = p_tenant_id
    and c.active = true
    and regexp_replace(c.phone, '[^0-9]', '', 'g') = v_phone_digits
  order by c.created_at
  limit 1;

  if not found
     or v_client.portal_session_token is null
     or v_client.portal_session_token <> coalesce(p_portal_token, '')
     or v_client.portal_session_expires_at is null
     or v_client.portal_session_expires_at < now()
  then
    raise exception 'Tu sesión expiró. Vuelve a ingresar con tu celular y tu PIN.';
  end if;

  return jsonb_build_object(
    'client_name', v_client.name,
    'upcoming_appointments', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'ticket_id', t.id,
          'ticket_code', t.ticket_code,
          'scheduled_at', t.scheduled_at,
          'status', t.status,
          'service_names', coalesce(ss.service_names, 'Sin servicios'),
          'stylist_names', coalesce(ss.stylist_names, 'Sin estilista')
        )
        order by t.scheduled_at asc nulls last
      ), '[]'::jsonb)
      from public.tickets t
      left join lateral (
        select
          string_agg(distinct s.name, ', ' order by s.name) as service_names,
          string_agg(distinct st.name, ', ' order by st.name) as stylist_names
        from public.ticket_services ts
        left join public.services s
          on s.tenant_id = ts.tenant_id and s.id = ts.service_id
        left join public.stylists st
          on st.tenant_id = ts.tenant_id and st.id = ts.stylist_id
        where ts.ticket_id = t.id
          and ts.status <> 'cancelado'
      ) ss on true
      where t.tenant_id = p_tenant_id
        and t.client_id = v_client.id
        and t.status not in ('finalizado', 'cerrado', 'cancelado', 'no_asistio')
    ),
    'past_appointments', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'ticket_id', t.id,
          'ticket_code', t.ticket_code,
          'scheduled_at', t.scheduled_at,
          'status', t.status,
          'service_names', coalesce(ss.service_names, 'Sin servicios'),
          'already_reviewed', exists(
            select 1 from public.reviews r
            where r.ticket_id = t.id and r.active
          )
        )
        order by t.scheduled_at desc nulls last
      ), '[]'::jsonb)
      from public.tickets t
      left join lateral (
        select string_agg(distinct s.name, ', ' order by s.name) as service_names
        from public.ticket_services ts
        left join public.services s
          on s.tenant_id = ts.tenant_id and s.id = ts.service_id
        where ts.ticket_id = t.id
          and ts.status <> 'cancelado'
      ) ss on true
      where t.tenant_id = p_tenant_id
        and t.client_id = v_client.id
        and t.status in ('finalizado', 'cerrado')
      limit 50
    ),
    'photos', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', wp.id,
          'photo_url', wp.photo_url,
          'photo_type', wp.photo_type,
          'caption', wp.caption,
          'created_at', wp.created_at,
          -- AU (D-286): la marca que distingue lo publicado en la página
          -- del salón de lo que es solo para ella.
          'in_portfolio', (wp.approved_for_portfolio and wp.photo_url is not null)
        )
        order by wp.created_at desc
      ), '[]'::jsonb)
      from public.work_photos wp
      where wp.tenant_id = p_tenant_id
        and wp.client_id = v_client.id
        and wp.visible_to_customer = true
        and wp.active
        -- AU (D-286): se entregan TAMBIÉN las del almacén privado, que no
        -- tienen dirección (`photo_url` nula). La app pide para cada una una
        -- URL temporal a `client-consent-photo-url` (D-281), que vuelve a
        -- comprobar el token y que la foto es suya. Hasta el 27-sep aquí
        -- había `and wp.photo_url is not null` (D-167): el interruptor
        -- "Visible al cliente" no hacía nada sin portafolio.
    )
  );
end;
$function$
;

comment on function public.get_client_portal_data(uuid, text, text) is
  'Portal de la clienta (D-167). Desde D-286 (AU) entrega también sus fotos visibles del almacén privado, sin dirección, con in_portfolio para distinguir las publicadas.';

commit;
