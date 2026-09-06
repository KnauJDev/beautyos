// BeautyOS - Creador Seguro de Sesiones de Smart Checkout ePayco V2 (D-141 / D-158 / D-192)
//
// Desde D-192 acepta `branchId`: si viene, se cobra ESA sede con el prorrateo
// hasta la fecha de corte del negocio (D-191). Si no viene, es el cobro del
// negocio entero, exactamente como antes.
//
// Autentica contra Apify usando llaves del servidor (nunca expuestas en Flutter)
// y genera un `sessionId` seguro para abrir el checkout modal oficial de ePayco.

import {
  crearSupabaseAdmin,
  crearSupabaseUsuario,
  resolverClaveSecreta,
  SUPABASE_URL,
} from "../_shared/supabase_keys.ts";

const EPAYCO_PUBLIC_KEY = Deno.env.get("EPAYCO_PUBLIC_KEY") ?? "a20a90e36c84335c754a73fba80a0978";
const EPAYCO_PRIVATE_KEY = Deno.env.get("EPAYCO_PRIVATE_KEY") ?? Deno.env.get("EPAYCO_P_KEY") ?? "";
const EPAYCO_TEST_MODE = (Deno.env.get("EPAYCO_TEST_MODE") ?? "true").toLowerCase() === "true";

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

    const { key: secretKey } = resolverClaveSecreta();
    if (!SUPABASE_URL || !secretKey) {
      console.error("Falta SUPABASE_URL o clave secreta en el servidor.");
      return responder({ error: "Error de configuración de base de datos en el servidor." }, 500);
    }

    paso = "verificar sesión autenticada";
    const autorizacion = req.headers.get("Authorization");
    if (!autorizacion) {
      return responder({ error: "Se requiere una sesión autenticada para generar la sesión de pago." }, 401);
    }

    const token = autorizacion.replace(/^Bearer\s+/i, "").trim();
    let userId: string | null = null;

    // 1. Extraer sub directamente del payload JWT verificado por el gateway de Supabase
    try {
      const parts = token.split(".");
      if (parts.length === 3) {
        const payloadStr = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"));
        const payload = JSON.parse(payloadStr);
        if (payload?.sub) {
          userId = payload.sub;
        }
      }
    } catch (e) {
      console.warn("Aviso al decodificar JWT payload:", e);
    }

    // 2. Si no se obtuvo del payload, consultar auth.getUser(token)
    if (!userId) {
      try {
        const supabaseAuth = crearSupabaseAdmin();
        const { data: userData } = await supabaseAuth.auth.getUser(token);
        if (userData?.user?.id) {
          userId = userData.user.id;
        }
      } catch (e) {
        console.warn("Aviso al validar usuario con auth.getUser:", e);
      }
    }

    if (!userId) {
      console.error("No se pudo resolver el usuario autenticado desde el token.");
      return responder({ error: "Se requiere una sesión autenticada para generar la sesión de pago." }, 401);
    }

    const supabaseAdmin = crearSupabaseAdmin();

    paso = "leer parámetros de solicitud";
    let body: { planCode?: string; branchId?: string } = {};
    try {
      body = await req.json();
    } catch {
      // Body vacío
    }

    // D-188: el plan por defecto pasa de "profesional" a "pro", el plan unico
    // Todo Incluido. Los tres viejos quedaron en `retired`.
    const planCode = (body.planCode || "pro").toLowerCase();

    // D-192 (Etapa 3b): si viene una sede, se cobra ESA sede. Si no viene, es
    // el cobro del negocio entero, que es como funcionaba hasta ahora y como
    // siguen funcionando los enlaces de pago que ya existan por ahi.
    const branchId = (body.branchId ?? "").toString().trim() || null;

    // El tenantId NUNCA se toma del cliente: se resuelve exclusivamente desde
    // la identidad y membresías del usuario autenticado en el servidor.
    paso = "resolver negocio del usuario autenticado";
    let tenantId: string | null = null;

    // 1. Intentar resolver mediante RPC get_my_tenant_id con el token del usuario
    try {
      const userClient = crearSupabaseUsuario(autorizacion);
      const { data: rpcTenantId, error: rpcErr } = await userClient.rpc("get_my_tenant_id");
      if (rpcTenantId) {
        tenantId = rpcTenantId as string;
      } else if (rpcErr) {
        console.warn("Aviso al consultar RPC get_my_tenant_id:", rpcErr.message);
      }
    } catch (e) {
      console.warn("Excepción al consultar RPC get_my_tenant_id:", e);
    }

    // 2. Si no se resolvió, buscar en tenant_memberships activas
    if (!tenantId) {
      const { data: memData } = await supabaseAdmin
        .from("tenant_memberships")
        .select("tenant_id")
        .eq("user_id", userId)
        .eq("active", true)
        .limit(1)
        .maybeSingle();

      if (memData?.tenant_id) {
        tenantId = memData.tenant_id;
      }
    }

    // 3. Si aún no, buscar en user_profiles (perfil principal del usuario)
    if (!tenantId) {
      const { data: profileData } = await supabaseAdmin
        .from("user_profiles")
        .select("tenant_id")
        .eq("user_id", userId)
        .limit(1)
        .maybeSingle();

      if (profileData?.tenant_id) {
        tenantId = profileData.tenant_id;
      }
    }

    // 4. Si aún no, buscar si el usuario es owner_user_id en la tabla tenants
    if (!tenantId) {
      const { data: ownerTenant } = await supabaseAdmin
        .from("tenants")
        .select("id")
        .eq("owner_user_id", userId)
        .limit(1)
        .maybeSingle();

      if (ownerTenant?.id) {
        tenantId = ownerTenant.id;
      }
    }

    if (!tenantId) {
      console.error(`No se encontró tenant para el usuario ${userId}`);
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
    // D-192: la sede tiene que ser de este negocio. El tenantId sale de la
    // sesion (nunca del cliente), asi que comprobar la sede contra el cierra
    // la misma clase de agujero que TL-01.
    if (branchId) {
      paso = "comprobar que la sede es de este negocio";
      const { data: branchData } = await supabaseAdmin
        .from("branches")
        .select("id")
        .eq("id", branchId)
        .eq("tenant_id", tenantId)
        .maybeSingle();

      if (!branchData) {
        return responder({ error: "La sede indicada no pertenece a tu negocio." }, 403);
      }
    }

    paso = "calcular monto y periodo a cobrar";
    let amount: number = 0;
    let planCodeResuelto: string = planCode;
    let planName: string = "Todo Incluido";
    let planIdResuelto: string | null = null;
    let motivo: string = "primera_activacion";
    let periodoFin: string | null = null;

    // 1. Intentar con RPC en base de datos
    const { data: calcData, error: calcError } = branchId
      ? await supabaseAdmin.rpc("beautyos_calcular_cargo_sede", {
          p_branch_id: branchId,
        })
      : await supabaseAdmin.rpc("beautyos_calcular_cargo_epayco", {
          p_tenant_id: tenantId,
          p_plan_code: planCode,
        });

    if (calcData && Array.isArray(calcData) && calcData.length > 0) {
      const calc = calcData[0];
      amount = Number(calc.monto_cop) || 0;
      motivo = calc.motivo || "primera_activacion";
      planIdResuelto = calc.plan_id_resuelto ?? null;
      periodoFin = calc.periodo_fin ?? null;

      if (planIdResuelto) {
        const { data: planData } = await supabaseAdmin
          .from("plans")
          .select("code, name")
          .eq("id", planIdResuelto)
          .maybeSingle();
        if (planData) {
          planCodeResuelto = planData.code || planCode;
          planName = planData.name || "Todo Incluido";
        }
      }
    } else {
      if (calcError) {
        console.warn("Aviso al ejecutar RPC calcular cargo, usando fallback directo:", calcError.message);
      }
      // 2. Fallback de cálculo directo leyendo la suscripción del negocio
      const { data: subData } = await supabaseAdmin
        .from("tenant_subscriptions")
        .select("id, plan_id, price_cop, discount_percent, discount_ends_at, current_period_end, status")
        .eq("tenant_id", tenantId)
        .maybeSingle();

      const { data: proPlan } = await supabaseAdmin
        .from("plans")
        .select("id, code, name, price_cop")
        .eq("code", "pro")
        .maybeSingle();

      const defaultPlan = proPlan || { id: null, code: "pro", name: "Todo Incluido", price_cop: 150000 };
      planIdResuelto = subData?.plan_id || defaultPlan.id;
      planCodeResuelto = defaultPlan.code;
      planName = defaultPlan.name;

      let basePrice = subData?.price_cop && subData.price_cop > 0
        ? Number(subData.price_cop)
        : Number(defaultPlan.price_cop || 150000);

      if (subData?.discount_percent && Number(subData.discount_percent) > 0) {
        const descVal = Number(subData.discount_percent);
        basePrice = Math.round(basePrice * (1 - descVal / 100));
      }

      amount = Math.max(1000, basePrice);
      motivo = subData?.current_period_end ? "renovacion_anticipada" : "primera_activacion";
    }

    if (amount <= 0) {
      console.error("Monto calculado es 0 o negativo:", amount);
      return responder({ error: "El monto calculado para la suscripción es inválido." }, 500);
    }

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
    // La factura lleva marca de sede para que se distinga de un vistazo en el
    // panel de ePayco cual de los cobros de un salon es cual.
    const marcaSede = branchId
      ? `-SED${branchId.replace(/-/g, "").substring(0, 6).toUpperCase()}`
      : "";
    const invoiceNumber =
      `SUB-${tenantId.replace(/-/g, "").substring(0, 8).toUpperCase()}${marcaSede}-${Date.now()}`;

    // D-182 (TL-02): se deja escrito, ANTES de que nadie pueda pagar, a qué
    // negocio y a qué plan corresponde esta factura. El webhook leerá esto en
    // vez de creerle a `x_extra1`, que viaja fuera de la firma de ePayco y por
    // tanto se puede cambiar sin invalidarla.
    paso = "registrar la intención de pago (D-182)";
    const { error: intentError } = await supabaseAdmin.rpc("beautyos_registrar_intencion_pago", {
      p_invoice_number: invoiceNumber,
      p_tenant_id: tenantId,
      p_plan_code: planCodeResuelto,
      p_plan_id: planIdResuelto,
      p_amount_cop: amount,
      p_created_by: userId,
      p_branch_id: branchId,
    });

    if (intentError) {
      console.warn("Aviso al registrar intención con RPC, guardando directamente en tabla:", intentError.message);
      const { error: upsertError } = await supabaseAdmin
        .from("subscription_payment_intents")
        .upsert({
          invoice_number: invoiceNumber.trim(),
          tenant_id: tenantId,
          branch_id: branchId,
          plan_code: planCodeResuelto,
          plan_id: planIdResuelto,
          amount_cop: amount,
          created_by: userId,
          status: "pendiente",
        }, { onConflict: "invoice_number" });

      if (upsertError) {
        console.error("Error al registrar intención en tabla:", upsertError);
        return responder({
          error: `No se pudo preparar el cobro de forma segura (${upsertError.message}). Inténtalo de nuevo.`,
        }, 500);
      }
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
      branchId: branchId,
      periodoFin: calc.periodo_fin ?? null,
      testMode: EPAYCO_TEST_MODE,
    }, 200);
  } catch (error) {
    console.error(`Excepción en create-epayco-session (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al generar sesión de pago (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
