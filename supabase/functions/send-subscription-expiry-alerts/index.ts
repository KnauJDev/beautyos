// BeautyOS - Automatizacion de Alertas de Vencimiento de Suscripcion y Gracia (Paso 3.11 / D-143)
//
// 1. Control de Acceso: exige x-cron-secret o Bearer token contra CRON_SECRET (Fail-Closed).
// 2. Ejecuta la suspension automatica de salones con gracia vencida (beautyos_suspender_suscripciones_vencidas).
// 3. Consulta los salones con notificaciones pendientes (10, 5, 3 dias antes de corte y dias 1 al 5 de gracia).
// 4. Genera correos en formato HTML responsivo en espanol con escape de caracteres, enlace directo de pago y WhatsApp.
// 5. Envia los correos a traves de Resend (hola@salonymas.com) y registra cada envio en logs anti-spam.

import { createClient } from "@supabase/supabase-js";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? Deno.env.get("SUBSCRIPTION_CRON_SECRET") ?? "";
const APP_URL = Deno.env.get("APP_URL") ?? "https://salonymas.com";
const WHATSAPP_SUPPORT_URL = "https://wa.me/573159780158?text=Hola%20equipo%20de%20Salon%20y%20Mas,%20necesito%20ayuda%20con%20mi%20suscripcion";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(cuerpo: unknown, status: number) {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function escapeHtml(str: string): string {
  return (str || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatearPesosCop(valor?: number | null): string {
  if (!valor || valor === 0) return "Tarifa según plan";
  return "$" + valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".") + " COP / mes";
}

function generarContenidoCorreo(alerta: Record<string, any>) {
  const rawNombreDuenio = alerta.owner_name || "Propietario(a)";
  const rawNombreSalon = alerta.tenant_name || "Tu Negocio";
  const rawPlan = alerta.plan_name || "Profesional";

  const nombreDuenio = escapeHtml(rawNombreDuenio);
  const nombreSalon = escapeHtml(rawNombreSalon);
  const plan = escapeHtml(rawPlan);
  const precio = formatearPesosCop(alerta.price_cop);
  const tipo = alerta.notification_type || "";
  const dias = alerta.days_remaining ?? 0;

  let asunto = `Aviso sobre tu cuenta en Salón y Más (${rawNombreSalon})`;
  let encabezado = "Estado de tu suscripción";
  let mensajePrincipal = "";
  let colorBadge = "#6366f1"; // Indigo
  let textoBoton = "Pagar y Gestionar Mi Plan";

  if (tipo.startsWith("trial_")) {
    encabezado = "Tu prueba gratis está por terminar";
    if (dias > 1) {
      asunto = `Tu prueba gratis de Salón y Más vence en ${dias} días — ${rawNombreSalon}`;
      mensajePrincipal = `Te quedan <strong>${dias} días</strong> de tu periodo de prueba gratis. Para continuar disfrutando de tu agenda, reservas de clientes y reportes sin interrupción, te invitamos a activar tu suscripción.`;
    } else {
      asunto = `🚨 Tu prueba gratis de Salón y Más termina pronto — ${rawNombreSalon}`;
      mensajePrincipal = `Tu periodo de prueba gratis finaliza hoy o en las próximas horas. ¡Activa tu suscripción para mantener la agenda abierta a tus clientes!`;
      colorBadge = "#e11d48";
    }
  } else if (tipo.startsWith("period_")) {
    encabezado = "Próxima renovación de mensualidad";
    if (dias > 1) {
      asunto = `Tu suscripción a Salón y Más vence en ${dias} días — ${rawNombreSalon}`;
      mensajePrincipal = `Te recordamos que tu mensualidad del <strong>Plan ${plan}</strong> vence en <strong>${dias} días</strong>. Realiza tu pago con tiempo para mantener tus servicios al día.`;
    } else {
      asunto = `Tu mensualidad de Salón y Más vence hoy — ${rawNombreSalon}`;
      mensajePrincipal = `Hoy vence tu periodo de suscripción mensual del <strong>Plan ${plan}</strong>. Realiza tu pago para evitar que tu servicio entre en periodo de mora.`;
      colorBadge = "#f59e0b";
    }
  } else if (tipo.startsWith("grace_day_")) {
    encabezado = `Periodo de Gracia: Te quedan ${dias} ${dias === 1 ? "día" : "días"}`;
    colorBadge = dias <= 2 ? "#e11d48" : "#f59e0b";
    asunto = `⚠️ Tienes ${dias} ${dias === 1 ? "día" : "días"} de gracia para realizar tu pago — ${rawNombreSalon}`;
    mensajePrincipal = `Tienes <strong>${dias} ${dias === 1 ? "día" : "días"} de gracia</strong> para realizar tu pago y continuar disfrutando de tus servicios sin interrupción ni bloqueo de citas.`;
    textoBoton = "Pagar Ahora por PSE / Tarjeta";
  } else if (tipo === "suspended") {
    encabezado = "Suscripción Pausada";
    colorBadge = "#e11d48";
    asunto = `Tu suscripción a Salón y Más ha sido pausada — ${rawNombreSalon}`;
    mensajePrincipal = `Tu periodo de gracia ha finalizado y tu servicio ha sido pausado temporalmente. No podrás agendar nuevas citas ni recibir reservas públicas hasta reactivar tu plan. Tan pronto realices el pago, tu cuenta se reactivará automáticamente.`;
    textoBoton = "Reactivar Mi Cuenta Ahora";
  }

  const html = `
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 20px; }
        .container { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden; }
        .header { background: #0f172a; padding: 24px; text-align: center; }
        .header h1 { color: #ffffff; margin: 0; font-size: 20px; font-weight: 700; }
        .badge { display: inline-block; padding: 6px 12px; border-radius: 20px; background-color: ${colorBadge}; color: #ffffff; font-size: 12px; font-weight: 700; text-transform: uppercase; margin-bottom: 12px; }
        .content { padding: 32px 24px; line-height: 1.6; }
        .info-card { background: #f1f5f9; border-radius: 8px; padding: 16px; margin: 20px 0; }
        .info-row { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 14px; }
        .info-row:last-child { margin-bottom: 0; }
        .btn-container { text-align: center; margin: 28px 0; }
        .btn { display: inline-block; background-color: #2563eb; color: #ffffff !important; text-decoration: none; padding: 14px 28px; font-weight: 700; font-size: 15px; border-radius: 8px; }
        .whatsapp-link { text-align: center; font-size: 13px; color: #64748b; margin-top: 20px; }
        .whatsapp-link a { color: #059669; font-weight: 600; text-decoration: none; }
        .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 16px; text-align: center; font-size: 12px; color: #94a3b8; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Salón y Más</h1>
        </div>
        <div class="content">
          <div class="badge">${encabezado}</div>
          <p>Hola <strong>${nombreDuenio}</strong>,</p>
          <p>${mensajePrincipal}</p>

          <div class="info-card">
            <div class="info-row"><strong>Negocio:</strong> <span>${nombreSalon}</span></div>
            <div class="info-row"><strong>Plan:</strong> <span>${plan}</span></div>
            <div class="info-row"><strong>Valor mensual:</strong> <span>${precio}</span></div>
          </div>

          <div class="btn-container">
            <a href="${APP_URL}" class="btn">${textoBoton}</a>
          </div>

          <p style="font-size: 13px; color: #64748b;">
            Aceptamos pagos seguros por <strong>PSE, Nequi, Daviplata y Tarjetas</strong> a través de ePayco. La renovación es inmediata.
          </p>

          <div class="whatsapp-link">
            ¿Tienes dudas o necesitas ayuda? <a href="${WHATSAPP_SUPPORT_URL}">Escríbenos por WhatsApp</a>
          </div>
        </div>
        <div class="footer">
          Salón y Más — Plataforma de Gestión para Centros de Estética y Barberías<br>
          Colombia · hola@salonymas.com
        </div>
      </div>
    </body>
    </html>
  `;

  return { asunto, html };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  let paso = "inicio";
  try {
    if (req.method !== "POST") {
      return responder({ error: "Metodo no permitido. Solo se aceptan solicitudes POST." }, 405);
    }

    paso = "validar secreto de ejecucion (control de acceso)";
    // BLINDAJE FAIL-CLOSED: Si CRON_SECRET no esta configurada o el header no coincide, rechaza
    const headerSecret = req.headers.get("x-cron-secret") ?? "";
    const authHeader = req.headers.get("authorization") ?? "";
    const bearerToken = authHeader.startsWith("Bearer ") ? authHeader.substring(7) : "";

    const secretProvided = headerSecret || bearerToken;

    if (!CRON_SECRET) {
      console.error("CRITICO: Falta configurar CRON_SECRET en las variables de entorno de Supabase.");
      return responder({ error: "Configuracion de seguridad de ejecucion incompleta en el servidor." }, 500);
    }

    if (secretProvided !== CRON_SECRET) {
      console.warn("ALERTA DE SEGURIDAD: Intento de invocacion no autorizada sin secreto valido.");
      return responder({ error: "No autorizado. Se requiere un secreto valido de cron." }, 401);
    }

    paso = "revisar configuracion";
    if (!RESEND_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error("Configuracion incompleta en variables de entorno (RESEND_API_KEY o SUPABASE)");
      return responder({ error: "Configuracion interna de servidor incompleta." }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    paso = "suspender suscripciones con gracia vencida";
    const { data: suspendResult, error: suspendError } = await supabase
      .rpc("beautyos_suspender_suscripciones_vencidas");

    if (suspendError) {
      console.error("Error al suspender suscripciones vencidas:", suspendError.message);
    } else {
      console.log("Suscripciones suspendidas hoy:", suspendResult);
    }

    paso = "consultar alertas pendientes";
    const { data: alertas, error: alertasError } = await supabase
      .rpc("beautyos_obtener_alertas_suscripcion_pendientes");

    if (alertasError) {
      console.error("Error al consultar alertas pendientes:", alertasError.message);
      return responder({ error: `Error al consultar alertas: ${alertasError.message}` }, 500);
    }

    const listaAlertas = (alertas as any[]) || [];
    console.log(`PASO: ${paso} | Alertas encontradas: ${listaAlertas.length}`);

    let totalEnviados = 0;
    let totalFallidos = 0;
    const detallesEnvios: any[] = [];

    paso = "enviar correos por Resend";
    for (const alerta of listaAlertas) {
      try {
        const { asunto, html } = generarContenidoCorreo(alerta);

        const resResend = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${RESEND_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "Salon y Mas <hola@salonymas.com>",
            to: [alerta.recipient_email],
            subject: asunto,
            html: html,
          }),
        });

        if (resResend.ok) {
          // Registrar en BD para evitar duplicados
          await supabase.rpc("beautyos_registrar_alerta_enviada", {
            p_tenant_id: alerta.tenant_id,
            p_subscription_id: alerta.subscription_id,
            p_notification_type: alerta.notification_type,
            p_recipient_email: alerta.recipient_email,
            p_metadata: {
              asunto: asunto,
              dias_restantes: alerta.days_remaining,
              enviado_at: new Date().toISOString(),
            },
          });

          totalEnviados++;
          detallesEnvios.push({
            tenant: alerta.tenant_name,
            email: alerta.recipient_email,
            tipo: alerta.notification_type,
            ok: true,
          });
        } else {
          const errText = await resResend.text();
          console.error(`Resend rechazo envio a ${alerta.recipient_email}:`, errText);
          totalFallidos++;
          detallesEnvios.push({
            tenant: alerta.tenant_name,
            email: alerta.recipient_email,
            tipo: alerta.notification_type,
            error: errText,
          });
        }
      } catch (errAlerta) {
        console.error(`Fallo envio para tenant ${alerta.tenant_name}:`, errAlerta);
        totalFallidos++;
      }
    }

    return responder(
      {
        ok: true,
        suspendidos: suspendResult,
        total_procesados: listaAlertas.length,
        enviados: totalEnviados,
        fallidos: totalFallidos,
        detalles: detallesEnvios,
      },
      200
    );
  } catch (fallo) {
    console.error(`FALLO INESPERADO en send-subscription-expiry-alerts en paso "${paso}":`, fallo);
    return responder({ error: `Fallo interno en "${paso}": ${String(fallo)}`, paso }, 500);
  }
});
