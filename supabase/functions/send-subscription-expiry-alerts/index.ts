// BeautyOS - Automatizacion de Alertas de Vencimiento de Suscripcion y Gracia (Paso 3.11 / D-143, por sede desde D-196)
//
// 1. Control de Acceso: exige x-cron-secret o Bearer token contra CRON_SECRET (Fail-Closed).
// 2. Ejecuta la suspension automatica de salones con gracia vencida (beautyos_suspender_suscripciones_vencidas).
//    Sigue siendo solo del NEGOCIO: ninguna sede secundaria se suspende sola todavia (D-196).
// 3. Consulta los salones con notificaciones pendientes (10, 5, 3 dias antes de corte y dias 1 al 5 de gracia),
//    y por separado las SEDES SECUNDARIAS con el mismo calculo (D-196). La sede principal no se consulta aparte:
//    su vencimiento ya lo cubre la alerta del negocio.
// 4. Agrupa las dos listas POR NEGOCIO: un dueno con una sede que vence y dos sedes en gracia recibe UN SOLO
//    correo, no tres. Genera HTML responsivo en espanol con escape de caracteres, enlace directo de pago y WhatsApp.
// 5. Envia un correo por negocio a traves de Resend (hola@salonymas.com) y registra CADA alerta individual
//    (la del negocio y la de cada sede) en el log anti-spam, para que el filtro de "no repetir hoy" siga
//    funcionando por componente aunque el correo salga combinado.

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

interface AlertaTenant {
  tenant_id: string;
  tenant_name: string;
  recipient_email: string;
  owner_name: string;
  subscription_id: string;
  subscription_status: string;
  plan_name: string;
  price_cop: number | null;
  notification_type: string;
  days_remaining: number;
  expiry_date: string;
}

interface AlertaSede {
  tenant_id: string;
  tenant_name: string;
  recipient_email: string;
  owner_name: string;
  branch_id: string;
  branch_name: string;
  branch_subscription_id: string;
  notification_type: string;
  days_remaining: number;
  expiry_date: string;
  price_cop: number | null;
}

interface GrupoAlertas {
  tenant_id: string;
  tenant_name: string;
  recipient_email: string;
  owner_name: string;
  tenantAlert: AlertaTenant | null;
  sedeAlerts: AlertaSede[];
}

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

// Agrupa las dos listas de alertas (negocio y sede) por tenant_id, para que
// cada negocio reciba UN SOLO correo aunque tenga varias alertas pendientes
// hoy (D-196). El orden de recorrido no importa: un Map con upsert basta.
function agruparPorNegocio(
  alertasTenant: AlertaTenant[],
  alertasSede: AlertaSede[]
): Map<string, GrupoAlertas> {
  const grupos = new Map<string, GrupoAlertas>();

  for (const a of alertasTenant) {
    grupos.set(a.tenant_id, {
      tenant_id: a.tenant_id,
      tenant_name: a.tenant_name,
      recipient_email: a.recipient_email,
      owner_name: a.owner_name,
      tenantAlert: a,
      sedeAlerts: [],
    });
  }

  for (const a of alertasSede) {
    const existente = grupos.get(a.tenant_id);
    if (existente) {
      existente.sedeAlerts.push(a);
    } else {
      grupos.set(a.tenant_id, {
        tenant_id: a.tenant_id,
        tenant_name: a.tenant_name,
        recipient_email: a.recipient_email,
        owner_name: a.owner_name,
        tenantAlert: null,
        sedeAlerts: [a],
      });
    }
  }

  return grupos;
}

// Frase corta para una fila de sede dentro del correo combinado. Mismo
// vocabulario de notification_type que ya usa la alerta del negocio.
function describirVencimientoSede(alerta: AlertaSede): string {
  const tipo = alerta.notification_type || "";
  const dias = alerta.days_remaining ?? 0;

  if (tipo.startsWith("trial_")) {
    return dias > 1 ? `Su prueba termina en ${dias} días` : "Su prueba termina hoy o mañana";
  }
  if (tipo.startsWith("period_")) {
    return dias > 1 ? `Vence en ${dias} días` : "Vence hoy";
  }
  if (tipo.startsWith("grace_day_")) {
    return `En periodo de gracia: quedan ${dias} ${dias === 1 ? "día" : "días"}`;
  }
  return "Requiere atención";
}

// true si alguna de las sedes ya está en las últimas 48h de su gracia o vence
// hoy: sirve para elegir el color/urgencia cuando no hay alerta de negocio.
function haySedeUrgente(sedeAlerts: AlertaSede[]): boolean {
  return sedeAlerts.some(
    (a) =>
      a.notification_type === "grace_day_4" ||
      a.notification_type === "grace_day_5" ||
      (a.notification_type === "period_1d" && (a.days_remaining ?? 0) <= 1)
  );
}

function bloqueSedesHtml(sedeAlerts: AlertaSede[]): string {
  if (sedeAlerts.length === 0) return "";

  const filas = sedeAlerts
    .map(
      (a) => `
          <div class="info-row">
            <strong>${escapeHtml(a.branch_name)}:</strong>
            <span>${escapeHtml(describirVencimientoSede(a))}</span>
          </div>`
    )
    .join("");

  return `
          <p style="margin-top: 24px; margin-bottom: 8px; font-weight: 700;">
            Tus sedes con vencimiento próximo
          </p>
          <div class="info-card">
            ${filas}
          </div>`;
}

function generarContenidoCorreo(grupo: GrupoAlertas) {
  const rawNombreDuenio = grupo.owner_name || "Propietario(a)";
  const rawNombreSalon = grupo.tenant_name || "Tu Negocio";

  const nombreDuenio = escapeHtml(rawNombreDuenio);
  const nombreSalon = escapeHtml(rawNombreSalon);

  const tenantAlert = grupo.tenantAlert;
  const sedeAlerts = grupo.sedeAlerts;

  let asunto: string;
  let encabezado: string;
  let mensajePrincipal: string;
  let colorBadge = "#6366f1"; // Indigo
  let textoBoton = "Pagar y Gestionar Mi Plan";
  let plan = "";
  let precio = "Tarifa según plan";

  if (tenantAlert) {
    plan = escapeHtml(tenantAlert.plan_name || "Todo Incluido");
    precio = formatearPesosCop(tenantAlert.price_cop);
    const tipo = tenantAlert.notification_type || "";
    const dias = tenantAlert.days_remaining ?? 0;

    asunto = `Aviso sobre tu cuenta en Salón y Más (${rawNombreSalon})`;
    encabezado = "Estado de tu suscripción";

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
    } else {
      mensajePrincipal = "Hay novedades sobre el estado de tu suscripción.";
    }

    // Con alertas de sede además de la del negocio, se avisa en el asunto
    // para que no parezca un correo repetido si llega otro sobre las sedes.
    if (sedeAlerts.length > 0) {
      asunto += ` (+ ${sedeAlerts.length} sede${sedeAlerts.length === 1 ? "" : "s"})`;
    }
  } else {
    // Sin alerta del negocio: solo hay sedes secundarias por vencer o en
    // gracia. Encabezado propio, sin mencionar un plan que hoy no vence.
    encabezado = "Sedes por vencer";
    colorBadge = haySedeUrgente(sedeAlerts) ? "#e11d48" : "#f59e0b";
    asunto = `Aviso de sedes por vencer en Salón y Más — ${rawNombreSalon}`;
    textoBoton = "Ver mis sedes y pagar";
    mensajePrincipal =
      sedeAlerts.length === 1
        ? `Una de tus sedes está por vencer o en periodo de gracia. Revisa el detalle abajo.`
        : `${sedeAlerts.length} de tus sedes están por vencer o en periodo de gracia. Revisa el detalle abajo.`;
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

          ${
            tenantAlert
              ? `<div class="info-card">
            <div class="info-row"><strong>Negocio:</strong> <span>${nombreSalon}</span></div>
            <div class="info-row"><strong>Plan:</strong> <span>${plan}</span></div>
            <div class="info-row"><strong>Valor mensual:</strong> <span>${precio}</span></div>
          </div>`
              : ""
          }

          ${bloqueSedesHtml(sedeAlerts)}

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
    // Sigue siendo solo del NEGOCIO (D-143). Ninguna sede secundaria se
    // suspende sola todavia: construir esa suspension automatica por sede es
    // un cambio de comportamiento mayor que D-196 no cubrio a proposito.
    const { data: suspendResult, error: suspendError } = await supabase
      .rpc("beautyos_suspender_suscripciones_vencidas");

    if (suspendError) {
      console.error("Error al suspender suscripciones vencidas:", suspendError.message);
    } else {
      console.log("Suscripciones suspendidas hoy:", suspendResult);
    }

    paso = "consultar alertas pendientes del negocio";
    const { data: alertasTenantData, error: alertasTenantError } = await supabase
      .rpc("beautyos_obtener_alertas_suscripcion_pendientes");

    if (alertasTenantError) {
      console.error("Error al consultar alertas del negocio:", alertasTenantError.message);
      return responder({ error: `Error al consultar alertas: ${alertasTenantError.message}` }, 500);
    }

    paso = "consultar alertas pendientes por sede";
    const { data: alertasSedeData, error: alertasSedeError } = await supabase
      .rpc("beautyos_obtener_alertas_sede_pendientes");

    if (alertasSedeError) {
      console.error("Error al consultar alertas por sede:", alertasSedeError.message);
      return responder({ error: `Error al consultar alertas de sede: ${alertasSedeError.message}` }, 500);
    }

    const alertasTenant = (alertasTenantData as AlertaTenant[]) || [];
    const alertasSede = (alertasSedeData as AlertaSede[]) || [];
    const grupos = agruparPorNegocio(alertasTenant, alertasSede);

    console.log(
      `PASO: ${paso} | Alertas de negocio: ${alertasTenant.length} | Alertas de sede: ${alertasSede.length} | Negocios a notificar: ${grupos.size}`
    );

    let totalEnviados = 0;
    let totalFallidos = 0;
    const detallesEnvios: any[] = [];

    paso = "enviar correos por Resend";
    for (const grupo of grupos.values()) {
      try {
        const { asunto, html } = generarContenidoCorreo(grupo);

        const resResend = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${RESEND_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "Salon y Mas <hola@salonymas.com>",
            to: [grupo.recipient_email],
            subject: asunto,
            html: html,
          }),
        });

        if (resResend.ok) {
          // Registra CADA alerta individual (negocio + cada sede) en el log
          // anti-spam, aunque el correo haya salido combinado: el filtro de
          // "no repetir hoy" de beautyos_obtener_alertas_*_pendientes es por
          // componente, no por correo.
          if (grupo.tenantAlert) {
            await supabase.rpc("beautyos_registrar_alerta_enviada", {
              p_tenant_id: grupo.tenantAlert.tenant_id,
              p_subscription_id: grupo.tenantAlert.subscription_id,
              p_notification_type: grupo.tenantAlert.notification_type,
              p_recipient_email: grupo.tenantAlert.recipient_email,
              p_metadata: {
                asunto,
                dias_restantes: grupo.tenantAlert.days_remaining,
                enviado_at: new Date().toISOString(),
              },
            });
          }

          for (const sede of grupo.sedeAlerts) {
            await supabase.rpc("beautyos_registrar_alerta_enviada", {
              p_tenant_id: sede.tenant_id,
              p_subscription_id: null,
              p_notification_type: sede.notification_type,
              p_recipient_email: sede.recipient_email,
              p_metadata: {
                asunto,
                dias_restantes: sede.days_remaining,
                sede: sede.branch_name,
                enviado_at: new Date().toISOString(),
              },
              p_branch_id: sede.branch_id,
            });
          }

          totalEnviados++;
          detallesEnvios.push({
            tenant: grupo.tenant_name,
            email: grupo.recipient_email,
            tipo_negocio: grupo.tenantAlert?.notification_type ?? null,
            sedes: grupo.sedeAlerts.map((s) => ({ sede: s.branch_name, tipo: s.notification_type })),
            ok: true,
          });
        } else {
          const errText = await resResend.text();
          console.error(`Resend rechazo envio a ${grupo.recipient_email}:`, errText);
          totalFallidos++;
          detallesEnvios.push({
            tenant: grupo.tenant_name,
            email: grupo.recipient_email,
            error: errText,
          });
        }
      } catch (errAlerta) {
        console.error(`Fallo envio para tenant ${grupo.tenant_name}:`, errAlerta);
        totalFallidos++;
      }
    }

    return responder(
      {
        ok: true,
        suspendidos: suspendResult,
        alertas_negocio: alertasTenant.length,
        alertas_sede: alertasSede.length,
        negocios_notificados: grupos.size,
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
