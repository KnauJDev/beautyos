// BeautyOS - Webhook Receptor y Validador de ePayco (Pasos 3.9 y 3.10 / D-141 / D-182 / D-192)
//
// BLINDAJE DE INTENCION DE PAGO (D-182, hallazgo TL-02 de la auditoria del 01-sep):
// La firma SHA-256 de ePayco cubre cust_id, key, ref_payco, transaction_id,
// monto y moneda -- pero NO cubre `x_extra1` (el negocio) ni `x_extra2` (el
// plan), que eran justamente los dos campos con los que este webhook decidia a
// quien activarle la suscripcion. Una confirmacion legitima se podia reenviar
// con `x_extra1` cambiado y la firma seguia siendo valida.
// (El UNIQUE de D-141 lo convertia en una carrera, no lo impedia.)
//
// Ahora el negocio y el plan salen de `subscription_payment_intents`, que el
// servidor escribe en `create-epayco-session` ANTES de mandar a nadie a pagar,
// y que se resuelve por el numero de factura (`x_id_invoice`). Si no hay
// intencion registrada, o si el payload declara otro negocio, no se procesa.
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
    // D-182 (TL-02): `x_extra1` y `x_extra2` YA NO DECIDEN NADA. La firma
    // SHA-256 de ePayco no los cubre (solo cubre cust_id, key, ref, tx, monto
    // y moneda), asi que se podian cambiar sin invalidarla y activarle la
    // suscripcion a otro negocio. Ahora solo se conservan para contrastarlos
    // contra la intencion que el servidor registro al abrir el checkout.
    const xTenantEnPayload = (payload.x_extra1 ?? payload.extra1 ?? payload.extras?.extra1 ?? "").toString().trim();
    const xInvoice = (payload.x_id_invoice ?? payload.x_id_factura ?? "").toString().trim();

    // Se retiro el rastreo por prefijo de factura contra `tenants`: adivinar el
    // negocio casando 8 caracteres hexadecimales es justo lo que se vino a
    // cerrar, y ahora la factura resuelve al negocio de forma exacta.

    console.log(
      `PASO: ${paso} | ref: ${xRefPayco} | tx: ${xTransactionId} | estado: ${xTransactionState} (cod: ${xCodTransactionState}) | monto: ${xAmount} | factura: ${xInvoice}`
    );

    if (!xRefPayco || !xInvoice) {
      console.warn("Webhook rechazado: faltan x_ref_payco o x_id_invoice.");
      return responder({ error: "Faltan parametros obligatorios: x_ref_payco o x_id_invoice." }, 400);
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

    paso = "preparar cliente de base de datos";
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // D-182 (TL-02): quien decide el negocio y el plan es la intencion que el
    // servidor escribio al abrir el checkout, no el payload. Si la factura no
    // tiene intencion registrada, o si el payload dice pertenecer a otro
    // negocio, no se procesa nada. FAIL-CLOSED.
    paso = "resolver la intencion de pago";
    const { data: intentData, error: intentError } = await supabase.rpc(
      "beautyos_resolver_intencion_pago",
      {
        p_invoice_number: xInvoice,
        p_tenant_en_payload: xTenantEnPayload || null,
        p_x_ref_payco: xRefPayco,
      },
    );

    if (intentError) {
      console.error("Error al resolver la intencion de pago:", intentError);
      return responder({ error: `Error resolviendo la intencion de pago: ${intentError.message}` }, 500);
    }

    const intent = Array.isArray(intentData) && intentData.length > 0 ? intentData[0] : null;

    if (!intent || intent.coincide !== true) {
      console.error(
        `ALERTA DE SEGURIDAD: confirmacion rechazada para la factura ${xInvoice} ` +
          `(ref ${xRefPayco}). Motivo: ${intent?.motivo ?? "sin intencion registrada"}. ` +
          `El payload declaraba el negocio "${xTenantEnPayload}".`,
      );
      return responder({
        error: intent?.motivo ?? "No hay una intencion de pago registrada para esta factura.",
      }, 403);
    }

    const xTenantId = intent.tenant_id as string;
    const xBranchId = (intent.branch_id ?? null) as string | null;
    const xPlanCode = (intent.plan_code ?? "") as string;

    console.log(
      `Intencion resuelta: factura ${xInvoice} -> negocio ${xTenantId}` +
        (xBranchId ? `, sede ${xBranchId}` : ", cobro del negocio entero") +
        `, plan ${xPlanCode}.`,
    );

    paso = "ejecutar rpc interna con service_role";
    const amountNum = Math.round(Number(xAmount) || 0);

    // D-192: dos caminos, y SOLO UNO corre por pago. No es duplicacion: las
    // reglas de monto son distintas -- un cobro prorrateado de sede puede estar
    // por debajo del piso de $10.000 que exige el cobro del negocio, y aquella
    // funcion lo rechazaria. La idempotencia de D-141 sigue siendo la que
    // garantiza que un pago se procese una sola vez, porque las dos escriben en
    // la misma tabla de eventos.
    const { data, error } = xBranchId
      ? await supabase.rpc("beautyos_procesar_pago_de_sede", {
          p_tenant_id: xTenantId,
          p_branch_id: xBranchId,
          p_x_ref_payco: xRefPayco,
          p_transaction_id: xTransactionId,
          p_transaction_state: xTransactionState,
          p_cod_transaction_state: xCodTransactionState,
          p_amount_cop: amountNum,
          p_currency_code: xCurrencyCode,
          p_payload: payload,
        })
      : await supabase.rpc("beautyos_procesar_evento_epayco", {
          p_tenant_id: xTenantId,
          p_x_ref_payco: xRefPayco,
          p_transaction_id: xTransactionId,
          p_transaction_state: xTransactionState,
          p_cod_transaction_state: xCodTransactionState,
          p_amount_cop: amountNum,
          p_currency_code: xCurrencyCode,
          p_payload: payload,
          p_plan_code: xPlanCode || null,
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
