// BeautyOS - Verificador Inmediato de Transacciones ePayco (D-141 / D-158 / D-181)
//
// Valida transacciones ePayco en tiempo real mediante la API oficial de consulta de referencias
// y activa inmediatamente la suscripción en la base de datos sin depender de latencias del webhook.
//
// BLINDAJE DE PERÍMETRO (D-181, hallazgo TL-01 de la auditoría del 01-sep):
// Antes esta función era pública (`verify_jwt = false`), aceptaba cualquier
// `ref_payco` de quien la llamara, y sacaba el negocio a activar del campo
// `x_extra1` que venía en la respuesta de ePayco — o, si faltaba, de adivinar
// por el prefijo de la factura recorriendo `tenant_subscriptions` y `tenants`.
// Nunca comprobaba que la transacción fuera **del comercio de Salón y Más**.
//
// El camino de abuso era concreto: abrir una cuenta de comercio ePayco propia,
// generar un pago con `extra1 = <uuid del negocio víctima>` (el uuid es público:
// `get_public_salon_by_slug` se lo devuelve a `anon`), y llamar a esta función
// con esa referencia. La validación de monto de D-159 obliga a pagar el precio
// real del plan, pero **a la cuenta del atacante**: el negocio quedaba activado
// sin que a Salón y Más le entrara un peso.
//
// Ahora hay tres candados, y los tres fallan cerrado:
//   1. Sesión obligatoria (`verify_jwt = true` en `config.toml`).
//   2. La transacción tiene que ser de NUESTRO comercio: se compara
//      `x_cust_id_cliente` contra `EPAYCO_P_CUST_ID`, el mismo secreto que ya
//      usa el webhook para la firma.
//   3. El negocio a activar sale de la **membresía activa de quien llama**, no
//      del payload. Si el pago dice pertenecer a otro negocio, se rechaza.
//
// Esta ruta sigue siendo solo una verificación de conveniencia al volver de la
// pasarela: la vía autoritativa de activación es el webhook servidor-a-servidor
// (`epayco-webhook`), que valida la firma SHA-256. Si esta falla, el negocio se
// activa igual por esa vía.

import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const EPAYCO_P_CUST_ID = Deno.env.get("EPAYCO_P_CUST_ID") ?? Deno.env.get("EPAYCO_CUSTOMER_ID") ?? "";

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

    // FAIL-CLOSED (D-181): sin el identificador de comercio no se puede saber si
    // la transacción es nuestra, y confirmar a ciegas es justo lo que se vino a
    // cerrar. Mismo criterio que el webhook.
    if (!EPAYCO_P_CUST_ID) {
      console.error("CRITICO: falta EPAYCO_P_CUST_ID en los secretos de la Edge Function.");
      return responder({ error: "Configuración de seguridad de pasarela incompleta en el servidor." }, 500);
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1er CANDADO (D-181): sesión obligatoria. `verify_jwt = true` ya rechaza en
    // el perímetro sin despertar este contenedor, pero el usuario hace falta
    // igualmente para resolver el negocio, así que se vuelve a leer aquí.
    paso = "verificar sesión autenticada";
    const autorizacion = req.headers.get("Authorization");
    let userId: string | null = null;

    if (autorizacion) {
      const token = autorizacion.replace(/^Bearer\s+/i, "").trim();
      if (token) {
        const { data: userData } = await supabaseAdmin.auth.getUser(token);
        userId = userData?.user?.id ?? null;
      }
    }

    if (!userId) {
      return responder({ error: "Se requiere una sesión autenticada para verificar un pago." }, 401);
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
    const xPlanCode = (data.x_extra2 ?? data.extra2 ?? "").toString().trim();

    // 2º CANDADO (D-181 / TL-01): la transacción tiene que ser de NUESTRO
    // comercio. Sin esto, un pago hecho en cualquier otra cuenta de comercio de
    // ePayco servía para activar una suscripción aquí.
    //
    // FAIL-CLOSED a propósito: si ePayco no devuelve el identificador de
    // comercio, no se confirma. El costo de equivocarse por exceso es que el
    // dueño no vea la confirmación instantánea; el webhook lo activa igual.
    paso = "validar que la transacción sea de nuestro comercio";
    const xCustIdCliente = (data.x_cust_id_cliente ?? data.x_cust_id ?? "").toString().trim();

    if (!xCustIdCliente) {
      console.error(
        `ALERTA DE SEGURIDAD: la referencia ${xRefPayco} no trae x_cust_id_cliente. No se confirma.`,
      );
      return responder({ error: "La transacción no se pudo atribuir a un comercio. No se confirmó." }, 403);
    }

    if (xCustIdCliente !== EPAYCO_P_CUST_ID.toString().trim()) {
      console.error(
        `ALERTA DE SEGURIDAD: referencia ${xRefPayco} pertenece al comercio ${xCustIdCliente}, ` +
          `no al de Salón y Más. Intento rechazado (usuario ${userId}).`,
      );
      return responder({ error: "Esta transacción no pertenece a Salón y Más." }, 403);
    }

    // 3er CANDADO (D-181 / TL-01): el negocio a activar sale de la membresía
    // activa de quien llama, NUNCA del payload. `x_extra1` solo sirve para
    // desambiguar cuando la persona pertenece a más de un negocio, y siempre
    // contrastado contra sus membresías reales.
    paso = "resolver negocio desde la sesión";
    const { data: membresias, error: memError } = await supabaseAdmin
      .from("tenant_memberships")
      .select("tenant_id")
      .eq("user_id", userId)
      .eq("active", true);

    if (memError) {
      console.error("Error al leer membresías:", memError);
      return responder({ error: "No se pudo resolver el negocio del usuario." }, 500);
    }

    const tenantsDelUsuario = (membresias ?? []).map((m) => m.tenant_id as string);

    if (tenantsDelUsuario.length === 0) {
      return responder({ error: "El usuario autenticado no tiene un negocio activo asociado." }, 403);
    }

    const tenantEnPago = (data.x_extra1 ?? data.extra1 ?? "").toString().trim();
    let tenantId: string;

    if (tenantEnPago) {
      if (!tenantsDelUsuario.includes(tenantEnPago)) {
        console.error(
          `ALERTA DE SEGURIDAD: el usuario ${userId} intentó confirmar la referencia ${xRefPayco}, ` +
            `que corresponde al negocio ${tenantEnPago}, del que no es miembro activo.`,
        );
        return responder({ error: "Este pago no corresponde a tu negocio." }, 403);
      }
      tenantId = tenantEnPago;
    } else if (tenantsDelUsuario.length === 1) {
      // Pago sin `extra1` (no debería pasar: `create-epayco-session` siempre lo
      // pone). Si la persona pertenece a un solo negocio no hay ambigüedad.
      tenantId = tenantsDelUsuario[0];
    } else {
      // Se prefiere no confirmar antes que adivinar. El webhook activa igual.
      console.warn(
        `Referencia ${xRefPayco} sin extra1 y usuario ${userId} con ${tenantsDelUsuario.length} negocios activos. No se confirma.`,
      );
      return responder(
        { error: `No se pudo identificar con certeza el negocio de la factura (${xInvoice}).` },
        409,
      );
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
      p_plan_code: xPlanCode || null,
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
