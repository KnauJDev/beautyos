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

    paso = "verificar sesión autenticada";
    const autorizacion = req.headers.get("Authorization");
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let userId: string | null = null;
    if (autorizacion) {
      const token = autorizacion.replace(/^Bearer\s+/i, "").trim();
      if (token) {
        const { data: userData } = await supabaseAdmin.auth.getUser(token);
        userId = userData?.user?.id ?? null;
      }
    }

    if (!userId) {
      return responder({ error: "Se requiere una sesión autenticada para generar la sesión de pago." }, 401);
    }

    paso = "leer parámetros de solicitud";
    let body: { planCode?: string } = {};
    try {
      body = await req.json();
    } catch {
      // Body vacío
    }

    // D-188: el plan por defecto pasa de "profesional" a "pro", el plan unico
    // Todo Incluido. Los tres viejos quedaron en `retired`.
    const planCode = (body.planCode || "pro").toLowerCase();

    // El tenantId NUNCA se toma del cliente: se resuelve exclusivamente desde
    // la membresía activa del usuario autenticado, para que nadie pueda pagar
    // (ni de menos, ni a nombre de otro negocio) suplantando un tenantId ajeno.
    paso = "resolver negocio del usuario autenticado";
    const { data: memData } = await supabaseAdmin
      .from("tenant_memberships")
      .select("tenant_id")
      .eq("user_id", userId)
      .eq("active", true)
      .limit(1)
      .maybeSingle();

    const tenantId = memData?.tenant_id;

    if (!tenantId) {
      return responder({ error: "El usuario autenticado no tiene un negocio activo asociado." }, 403);
    }

    paso = "consultar datos del tenant";
    let tenantName = "Mi Negocio";
    let tenantEmail = "facturacion@salonymas.com";
    let tenantPhone = "3000000000";

    const { data: tenantData } = await supabaseAdmin
      .from("tenants")
      .select("id, name, contact_email, whatsapp")
      .eq("id", tenantId)
      .maybeSingle();

    if (tenantData) {
      if (tenantData.name) tenantName = tenantData.name;
      if (tenantData.contact_email) tenantEmail = tenantData.contact_email;
      if (tenantData.whatsapp) {
        const digits = tenantData.whatsapp.replace(/[^0-9]/g, "");
        if (digits.length >= 7) tenantPhone = digits;
      }
    }

    // El monto y el plan a cobrar los calcula SIEMPRE el servidor, con la
    // misma función que valida el pago al confirmarlo (fuente de verdad
    // única). Si el tenant tiene plan/precio pactado por el owner, esta
    // función ignora por completo el planCode que mandó el cliente — el
    // dropdown de Flutter ya no lo muestra en ese caso, pero esto es
    // defensa en profundidad, no depende de que el cliente se comporte.
    paso = "calcular monto y periodo a cobrar";
    const { data: calcData, error: calcError } = await supabaseAdmin.rpc(
      "beautyos_calcular_cargo_epayco",
      { p_tenant_id: tenantId, p_plan_code: planCode },
    );

    if (calcError || !calcData || calcData.length === 0) {
      console.error("Error al calcular el cargo de ePayco:", calcError);
      return responder({ error: "No se pudo calcular el monto a cobrar para este negocio." }, 500);
    }

    const calc = calcData[0];
    const amount = calc.monto_cop;

    const { data: planData } = await supabaseAdmin
      .from("plans")
      .select("code, name")
      .eq("id", calc.plan_id_resuelto)
      .maybeSingle();

    const planCodeResuelto = planData?.code || planCode;
    const planName = planData?.name || "Todo Incluido";

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
    const invoiceNumber = `SUB-${tenantId.replace(/-/g, "").substring(0, 8).toUpperCase()}-${Date.now()}`;

    // D-182 (TL-02): se deja escrito, ANTES de que nadie pueda pagar, a qué
    // negocio y a qué plan corresponde esta factura. El webhook leerá esto en
    // vez de creerle a `x_extra1`, que viaja fuera de la firma de ePayco y por
    // tanto se puede cambiar sin invalidarla.
    //
    // Va antes de crear la sesión a propósito: si se registrara después y esa
    // escritura fallara, quedaría una sesión pagable sin intención, y el
    // webhook rechazaría un pago legítimo.
    paso = "registrar la intención de pago (D-182)";
    const { error: intentError } = await supabaseAdmin.rpc("beautyos_registrar_intencion_pago", {
      p_invoice_number: invoiceNumber,
      p_tenant_id: tenantId,
      p_plan_code: planCodeResuelto,
      p_plan_id: calc.plan_id_resuelto ?? null,
      p_amount_cop: amount,
      p_created_by: userId,
    });

    if (intentError) {
      console.error("No se pudo registrar la intención de pago:", intentError);
      return responder({
        error: "No se pudo preparar el cobro de forma segura. Inténtalo de nuevo.",
      }, 500);
    }
    const sessionPayload = {
      checkout_version: "2",
      name: `Suscripción Salón y Más - ${planName}`,
      description: `Plan ${planName} - ${tenantName}`,
      invoice: invoiceNumber,
      currency: "COP",
      amount: amount,
      tax_base: 0,
      tax: 0,
      country: "CO",
      lang: "ES",
      extra1: tenantId,
      extra2: planCodeResuelto,
      extra3: "beautyos_app",
      confirmation_url: "https://eogppgbdnwxdtcbctaol.supabase.co/functions/v1/epayco-webhook",
      response_url: "https://salonymas.com",
      test: EPAYCO_TEST_MODE,
      billing: {
        email: tenantEmail,
        name: tenantName,
        mobilePhone: tenantPhone,
      },
    };

    console.log("Enviando sesión a ePayco:", JSON.stringify(sessionPayload));

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
        error: sessionJson?.textResponse || sessionJson?.message || "No se pudo generar la sesión de pago en ePayco.",
      }, 502);
    }

    const sessionId = sessionJson.data.sessionId;

    return responder({
      success: true,
      sessionId: sessionId,
      amount: amount,
      planCode: planCodeResuelto,
      planName: planName,
      motivo: calc.motivo,
      testMode: EPAYCO_TEST_MODE,
    }, 200);
  } catch (error) {
    console.error(`Excepción en create-epayco-session (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al generar sesión de pago (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
