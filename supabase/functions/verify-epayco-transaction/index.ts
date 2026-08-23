// BeautyOS - Verificador Inmediato de Transacciones ePayco (D-141 / D-158)
//
// Valida transacciones ePayco en tiempo real mediante la API oficial de consulta de referencias
// y activa inmediatamente la suscripción en la base de datos sin depender de latencias del webhook.

import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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
    paso = "revisar configuración";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return responder({ error: "Falta configuración interna de base de datos." }, 500);
    }

    paso = "extraer ref_payco";
    const url = new URL(req.url);
    let refPayco = url.searchParams.get("ref_payco") ?? url.searchParams.get("refPayco") ?? "";

    if (!refPayco && req.method === "POST") {
      try {
        const body = await req.json();
        refPayco = body.ref_payco ?? body.refPayco ?? "";
      } catch {
        try {
          const text = await req.text();
          const params = new URLSearchParams(text);
          refPayco = params.get("ref_payco") ?? params.get("refPayco") ?? "";
        } catch {
          // ignore
        }
      }
    }

    refPayco = refPayco.trim();
    if (!refPayco) {
      return responder({ error: "Falta el parámetro ref_payco." }, 400);
    }

    paso = "consultar transacción en API de ePayco";
    const epaycoRes = await fetch(`https://secure.epayco.co/validation/v1/reference/${refPayco}`);
    if (!epaycoRes.ok) {
      return responder({ error: "No se pudo consultar la transacción en ePayco." }, 502);
    }

    const epaycoJson = await epaycoRes.json();
    if (!epaycoJson.success || !epaycoJson.data) {
      return responder({ error: "ePayco no encontró la referencia de pago especificada." }, 404);
    }

    const data = epaycoJson.data;
    const xRefPayco = (data.x_ref_payco ?? refPayco).toString().trim();
    const xTransactionId = (data.x_transaction_id ?? data.x_id_invoice ?? "").toString().trim();
    const xAmount = Number(data.x_amount ?? data.x_amount_ok ?? 0);
    const xCurrencyCode = (data.x_currency_code ?? "COP").toString().trim();
    const xTransactionState = (data.x_transaction_state ?? data.x_response ?? data.x_respuesta ?? "").toString().trim();
    const xCodTransactionState = (data.x_cod_transaction_state ?? data.x_cod_response ?? data.x_cod_respuesta ?? "").toString().trim();
    const xInvoice = (data.x_id_invoice ?? data.x_id_factura ?? "").toString().trim();

    paso = "resolver tenant_id";
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let tenantId = (data.x_extra1 ?? data.extra1 ?? "").toString().trim();

    if (!tenantId && xInvoice) {
      const match = xInvoice.match(/SUB-([0-9A-Fa-f]{8})-/);
      if (match) {
        const prefix = match[1].toLowerCase();
        const { data: allTenants } = await supabaseAdmin
          .from("tenants")
          .select("id, name");
        const matched = allTenants?.find((t) => t.id.replace(/-/g, "").toLowerCase().startsWith(prefix));
        if (matched?.id) {
          tenantId = matched.id;
          console.log(`Tenant identificado por prefijo de factura ${prefix}: ${tenantId} (${matched.name})`);
        }
      }
    }

    if (!tenantId) {
      return responder({ error: `No se pudo identificar el negocio asociado a la factura (${xInvoice}).` }, 404);
    }

    paso = "ejecutar beautyos_procesar_evento_epayco";
    const { data: rpcData, error: rpcError } = await supabaseAdmin.rpc("beautyos_procesar_evento_epayco", {
      p_tenant_id: tenantId,
      p_x_ref_payco: xRefPayco,
      p_transaction_id: xTransactionId,
      p_transaction_state: xTransactionState,
      p_cod_transaction_state: xCodTransactionState,
      p_amount_cop: Math.round(xAmount),
      p_currency_code: xCurrencyCode,
      p_payload: data,
    });

    if (rpcError) {
      console.error("Error en beautyos_procesar_evento_epayco:", rpcError);
      return responder({ error: `Error procesando evento en base de datos: ${rpcError.message}` }, 500);
    }

    const rpcResult = Array.isArray(rpcData) && rpcData.length > 0 ? rpcData[0] : null;

    return responder({
      success: true,
      tenantId: tenantId,
      transactionState: xTransactionState,
      codResponse: xCodTransactionState,
      amount: xAmount,
      currency: xCurrencyCode,
      newStatus: rpcResult?.new_status ?? "active",
      message: rpcResult?.message ?? "Transacción verificada y procesada con éxito.",
    }, 200);
  } catch (error) {
    console.error(`Excepción en verify-epayco-transaction (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al verificar transacción (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
