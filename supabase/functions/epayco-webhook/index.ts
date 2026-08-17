// BeautyOS - Webhook Receptor y Validador de ePayco (Pasos 3.9 y 3.10 / D-141)
//
// Recibe las notificaciones de confirmacion de transacciones de ePayco (servidor a servidor),
// valida la firma criptografica SHA-256 usando la llave privada (EPAYCO_P_KEY) que reside
// exclusivamente en el servidor (FAIL-CLOSED: obligatorio), y ejecuta de forma atomica
// e idempotente la RPC interna `private.beautyos_procesar_evento_epayco` con privilegios de `service_role`.

import { createClient } from "@supabase/supabase-js";

const EPAYCO_P_CUST_ID = Deno.env.get("EPAYCO_P_CUST_ID") ?? Deno.env.get("EPAYCO_CUSTOMER_ID") ?? "";
const EPAYCO_P_KEY = Deno.env.get("EPAYCO_P_KEY") ?? Deno.env.get("EPAYCO_PRIVATE_KEY") ?? "";
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

/**
 * Calcula el hash SHA-256 en formato hexadecimal en Deno usando Web Crypto API.
 */
async function calcularSha256(texto: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(texto);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
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

    paso = "revisar configuracion de servidor";
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error("Falta SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en los secretos de la Edge Function.");
      return responder({ error: "Configuracion interna de base de datos incompleta." }, 500);
    }

    // BLINDAJE FAIL-CLOSED: Si las llaves de ePayco no estan en el servidor, no se procesa nada
    if (!EPAYCO_P_CUST_ID || !EPAYCO_P_KEY) {
      console.error("CRITICO: Falta configurar EPAYCO_P_CUST_ID o EPAYCO_P_KEY en las variables de entorno.");
      return responder({ error: "Configuracion de seguridad de pasarela incompleta en el servidor." }, 500);
    }

    paso = "leer cuerpo de la solicitud";
    let payload: Record<string, any> = {};
    const contentType = req.headers.get("content-type") || "";

    if (contentType.includes("application/x-www-form-urlencoded") || contentType.includes("multipart/form-data")) {
      const formData = await req.formData();
      formData.forEach((value, key) => {
        payload[key] = value.toString();
      });
    } else {
      try {
        payload = await req.json();
      } catch {
        const text = await req.text();
        const params = new URLSearchParams(text);
        params.forEach((value, key) => {
          payload[key] = value;
        });
      }
    }

    paso = "extraer campos de epayco";
    const xRefPayco = (payload.x_ref_payco ?? payload.x_ref_payco_ ?? "").toString().trim();
    const xTransactionId = (payload.x_transaction_id ?? payload.x_id_invoice ?? "").toString().trim();
    const xAmount = (payload.x_amount ?? "0").toString().trim();
    const xCurrencyCode = (payload.x_currency_code ?? "COP").toString().trim();
    const xSignature = (payload.x_signature ?? "").toString().trim();
    const xTransactionState = (payload.x_transaction_state ?? payload.x_response ?? "").toString().trim();
    const xCodTransactionState = (payload.x_cod_transaction_state ?? "").toString().trim();
    const xTenantId = (payload.x_extra1 ?? payload.extra1 ?? "").toString().trim();

    console.log(
      `PASO: ${paso} | ref: ${xRefPayco} | tx: ${xTransactionId} | estado: ${xTransactionState} (cod: ${xCodTransactionState}) | monto: ${xAmount} | tenant: ${xTenantId}`
    );

    if (!xRefPayco || !xTenantId) {
      console.warn("Webhook rechazado: Faltan x_ref_payco o x_extra1 (tenant_id).");
      return responder({ error: "Faltan parametros obligatorios: x_ref_payco o x_extra1." }, 400);
    }

    // BLINDAJE FAIL-CLOSED: x_signature es 100% obligatoria
    if (!xSignature) {
      console.error("ALERTA DE SEGURIDAD: Solicitud rechazada. No se recibio la firma criptografica x_signature.");
      return responder({ error: "Firma criptografica ausente." }, 400);
    }

    paso = "validar firma criptografica sha256";
    // Formula estandar ePayco: sha256(p_cust_id_cliente ^ p_key ^ x_ref_payco ^ x_transaction_id ^ x_amount ^ x_currency_code)
    const cadenaFirma = `${EPAYCO_P_CUST_ID}^${EPAYCO_P_KEY}^${xRefPayco}^${xTransactionId}^${xAmount}^${xCurrencyCode}`;
    const firmaCalculada = await calcularSha256(cadenaFirma);

    if (firmaCalculada.toLowerCase() !== xSignature.toLowerCase()) {
      console.error(
        `ALERTA DE SEGURIDAD: Firma de ePayco invalida. Recibida: ${xSignature} | Esperada: ${firmaCalculada}`
      );
      return responder({ error: "Firma criptografica de confirmacion invalida." }, 400);
    }
    console.log("Firma criptografica de ePayco verificada con exito en el servidor.");

    paso = "ejecutar rpc interna con service_role";
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const amountNum = Math.round(Number(xAmount) || 0);

    const { data, error } = await supabase.rpc("beautyos_procesar_evento_epayco", {
      p_tenant_id: xTenantId,
      p_x_ref_payco: xRefPayco,
      p_transaction_id: xTransactionId,
      p_transaction_state: xTransactionState,
      p_cod_transaction_state: xCodTransactionState,
      p_amount_cop: amountNum,
      p_currency_code: xCurrencyCode,
      p_payload: payload,
    });

    if (error) {
      console.error(`Error en beautyos_procesar_evento_epayco: ${error.message}`);
      return responder({ error: `Error procesando evento en base de datos: ${error.message}` }, 500);
    }

    console.log(`PASO: procesado exitoso | resultado:`, data);

    // Responder 200 OK a ePayco para confirmar recepcion e impedir reintentos
    return responder({ ok: true, resultado: data }, 200);
  } catch (fallo) {
    console.error(`FALLO INESPERADO en webhook epayco en paso "${paso}":`, fallo);
    return responder({ error: `Fallo interno en "${paso}": ${String(fallo)}`, paso }, 500);
  }
});
