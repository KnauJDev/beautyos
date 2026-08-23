// BeautyOS - Creador Seguro de Sesiones de Smart Checkout ePayco V2 (D-141 / D-158)
//
// Autentica contra Apify usando llaves del servidor (nunca expuestas en Flutter)
// y genera un `sessionId` seguro para abrir el checkout modal oficial de ePayco.

import { createClient } from "@supabase/supabase-js";

const EPAYCO_PUBLIC_KEY = Deno.env.get("EPAYCO_PUBLIC_KEY") ?? "a20a90e36c84335c754a73fba80a0978";
const EPAYCO_PRIVATE_KEY = Deno.env.get("EPAYCO_PRIVATE_KEY") ?? Deno.env.get("EPAYCO_P_KEY") ?? "";
const EPAYCO_TEST_MODE = (Deno.env.get("EPAYCO_TEST_MODE") ?? "true").toLowerCase() === "true";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(cuerpo: unknown, status: number) {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  let paso = "inicio";
  try {
    if (req.method !== "POST") {
      return responder({ error: "Método no permitido. Solo se aceptan solicitudes POST." }, 405);
    }

    paso = "revisar configuración del servidor";
    if (!EPAYCO_PUBLIC_KEY || !EPAYCO_PRIVATE_KEY) {
      console.error("Falta EPAYCO_PUBLIC_KEY o EPAYCO_PRIVATE_KEY en los secretos de Supabase.");
      return responder({ error: "La pasarela de pago no está configurada en el servidor." }, 500);
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error("Falta SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en el servidor.");
      return responder({ error: "Error de configuración de base de datos." }, 500);
    }

    const autorizacion = req.headers.get("Authorization");
    if (!autorizacion) {
      return responder({ error: "No autorizado: falta encabezado de autenticación." }, 401);
    }

    paso = "validar usuario autenticado";
    const token = autorizacion.replace(/^Bearer\s+/i, "").trim();
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let userId: string | null = null;
    if (token) {
      const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
      if (userData?.user) {
        userId = userData.user.id;
      } else {
        console.warn("No se pudo resolver usuario por token:", userError?.message);
      }
    }

    paso = "leer parámetros de solicitud";
    let body: { tenantId?: string; planCode?: string; amount?: number };
    try {
      body = await req.json();
    } catch {
      return responder({ error: "Cuerpo de solicitud inválido." }, 400);
    }

    const tenantId = body.tenantId;
    const planCode = (body.planCode || "profesional").toLowerCase();

    if (!tenantId) {
      return responder({ error: "Falta el tenantId en la solicitud." }, 400);
    }

    paso = "consultar datos y precio efectivo del tenant";
    const { data: tenantData, error: tenantError } = await supabaseAdmin
      .from("tenants")
      .select("id, name, contact_email, whatsapp")
      .eq("id", tenantId)
      .single();

    if (tenantError || !tenantData) {
      return responder({ error: "No se encontró el negocio especificado." }, 404);
    }

    let amount = 240000;
    if (planCode === "basico") amount = 160000;
    if (planCode === "business") amount = 200000;

    // Consultar suscripción y tarifas pactadas en BD
    const { data: subData } = await supabaseAdmin
      .from("tenant_subscriptions")
      .select("price_cop, is_founder, discount_percent, plan_id, plans(code)")
      .eq("tenant_id", tenantId)
      .single();

    if (subData) {
      if (subData.price_cop && subData.price_cop > 0) {
        amount = subData.price_cop;
      } else if (subData.is_founder) {
        amount = Math.round(amount * 0.5);
      } else if (subData.discount_percent && subData.discount_percent > 0) {
        amount = Math.round(amount * (1 - subData.discount_percent / 100));
      }
    }

    // Permitir monto solicitado expresamente si es válido
    if (body.amount && typeof body.amount === "number" && body.amount >= 10000) {
      amount = body.amount;
    }

    let planName = "Profesional";
    if (planCode === "basico") planName = "Básico";
    if (planCode === "business") planName = "Business";

    paso = "autenticar con ePayco Apify";
    const basicAuth = btoa(`${EPAYCO_PUBLIC_KEY}:${EPAYCO_PRIVATE_KEY}`);
    const loginRes = await fetch("https://apify.epayco.co/login", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${basicAuth}`,
      },
    });

    if (!loginRes.ok) {
      const errText = await loginRes.text();
      console.error("Error login Apify:", errText);
      return responder({ error: `Fallo de autenticación con pasarela ePayco: ${errText}` }, 502);
    }

    const loginJson = await loginRes.json();
    const apifyToken = loginJson.token;

    if (!apifyToken) {
      return responder({ error: "ePayco no retornó token de sesión válido." }, 502);
    }

    paso = "crear sesión de Smart Checkout V2 en ePayco";
    const sessionPayload = {
      checkout_version: "2",
      name: `Suscripción Salón y Más - ${planName}`,
      description: `Plan ${planName} - ${tenantData.name}`,
      currency: "COP",
      amount: amount,
      tax_base: 0,
      tax: 0,
      country: "CO",
      lang: "ES",
      extra1: tenantId,
      extra2: planCode,
      extra3: "beautyos_app",
      confirmation_url: "https://eogppgbdnwxdtcbctaol.supabase.co/functions/v1/epayco-webhook",
      response_url: "https://salonymas.com",
      test: EPAYCO_TEST_MODE,
      billing: {
        email: tenantData.contact_email || "facturacion@salonymas.com",
        name: tenantData.name,
        mobilePhone: (tenantData.whatsapp || "3000000000").replace(/[^0-9]/g, ""),
      },
    };

    const sessionRes = await fetch("https://apify.epayco.co/payment/session/create", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apifyToken}`,
      },
      body: JSON.stringify(sessionPayload),
    });

    const sessionJson = await sessionRes.json();
    if (!sessionRes.ok || !sessionJson?.data?.sessionId) {
      console.error("Error al crear sesión en ePayco:", sessionJson);
      return responder({
        error: sessionJson?.textResponse || sessionJson?.message || "No se pudo generar la sesión de pago.",
      }, 502);
    }

    const sessionId = sessionJson.data.sessionId;

    return responder({
      success: true,
      sessionId: sessionId,
      amount: amount,
      planCode: planCode,
      planName: planName,
      testMode: EPAYCO_TEST_MODE,
    }, 200);
  } catch (error) {
    console.error(`Excepción en create-epayco-session (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al generar sesión de pago (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
