// BeautyOS - Alarma de stock por correo (punto 8 del benchmarking, D-086).
//
// 11-ago: se quito la dependencia de `@supabase/server` (`withSupabase`).
// Es el paso 2.7 del Plan Maestro y el hallazgo T.
//
// POR QUE. Identico arreglo al de `send-invitation-email` (D-128): esa
// libreria estaba anclada como `npm:@supabase/server@^1`, o sea "la version
// mas nueva que haya" -- cada despliegue traia un codigo distinto sin que
// nadie lo decidiera --, y se rompia **antes** de ejecutar la primera linea
// nuestra: los registros mostraban `booted` y nada mas, ni un solo
// `console.log` propio. Alli costo dos horas averiguarlo; aqui no hace falta
// repetir el diagnostico, la causa es la misma y esta probada en produccion.
//
// POR QUE NADIE SE HABIA ENTERADO DE QUE ESTABA ROTA. `LowStockAlertService`
// se traga cualquier error a proposito ("mejor esfuerzo": el consumo interno
// ya quedo registrado y no se le muestra un error a quien solo queria
// descontar stock). Eso esta bien para el usuario, pero significa que **la
// unica prueba valida es que el correo llegue**: la aplicacion nunca se queja.
//
// Lo unico que hacia `withSupabase` era leer la sesion de quien llama. Eso se
// hace aqui con `@supabase/supabase-js`, la misma libreria que usa la app.
// La sesion viaja en la cabecera `Authorization` y se le pasa tal cual al
// cliente: asi `get_low_stock_alert_context` (security definer) sigue viendo
// al usuario real y solo entrega datos si esa persona es tenant_owner/admin
// de esa sede y el producto realmente esta en el minimo o por debajo.
// La clave de Resend nunca sale de este servidor.

import { createClient } from "@supabase/supabase-js";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");

// Se prefiere la clave publicable nueva y se cae a la antigua solo si hace
// falta. Asi las claves heredadas se pueden volver a apagar sin romper esto
// (H-04): el proyecto ya no depende de ellas.
const CLAVE_PUBLICA = (() => {
  const nuevas = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (nuevas) {
    try {
      const dic = JSON.parse(nuevas) as Record<string, string>;
      const primera = Object.values(dic)[0];
      if (primera) return primera;
    } catch {
      return nuevas;
    }
  }
  return Deno.env.get("SUPABASE_ANON_KEY") ?? "";
})();

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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
      return responder({ error: "Metodo no permitido." }, 405);
    }

    paso = "revisar configuracion";
    console.log(
      "PASO:", paso,
      "| resend:", Boolean(RESEND_API_KEY),
      "| url:", Boolean(SUPABASE_URL),
      "| clave:", Boolean(CLAVE_PUBLICA),
    );

    if (!RESEND_API_KEY) {
      return responder(
        { error: "RESEND_API_KEY no esta configurada en Supabase." },
        500,
      );
    }
    if (!SUPABASE_URL || !CLAVE_PUBLICA) {
      return responder(
        { error: "Falta la configuracion de Supabase en la funcion." },
        500,
      );
    }

    paso = "leer sesion";
    const autorizacion = req.headers.get("Authorization");
    if (!autorizacion) {
      return responder({ error: "Falta la sesion de quien registra." }, 401);
    }

    paso = "leer cuerpo";
    let body: { branch_id?: string; product_id?: string };
    try {
      body = await req.json();
    } catch {
      return responder({ error: "Cuerpo invalido." }, 400);
    }

    const branchId = body.branch_id;
    const productId = body.product_id;
    if (!branchId || !productId) {
      return responder({ error: "Faltan branch_id o product_id." }, 400);
    }

    paso = "consultar el stock";
    console.log("PASO:", paso, "| sede:", branchId, "| producto:", productId);

    const supabase = createClient(SUPABASE_URL, CLAVE_PUBLICA, {
      global: { headers: { Authorization: autorizacion } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await supabase
      .rpc("get_low_stock_alert_context", {
        p_branch_id: branchId,
        p_product_id: productId,
      })
      .maybeSingle();

    if (error) {
      console.log("PASO:", paso, "| error |", error.message);
      return responder({ error: error.message }, 404);
    }

    if (!data) {
      // No esta bajo el minimo, no autorizado, o sin correo de contacto: no
      // hay nada que enviar. No es un error.
      console.log("PASO:", paso, "| sin fila: no hay nada que enviar");
      return responder({ ok: true, sent: false }, 200);
    }

    paso = "preparar el correo";
    const d = data as Record<string, unknown>;
    const brandText = d.brand ? ` (${d.brand})` : "";

    paso = "enviar por Resend";
    console.log("PASO:", paso, "| para:", d.contact_email);

    let respuestaResend: Response;
    try {
      respuestaResend = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          // Remitente propio desde el 10-ago (paso 2.3, cierra H-12).
          // Antes salia de `onboarding@resend.dev`, la direccion compartida de
          // pruebas de Resend, que **solo entrega al dueno de la cuenta**: por
          // eso ninguna invitacion llegaba a nadie mas.
          //
          // El nombre sigue SIN tildes, como decidio D-089: el campo "De:" es
          // el mas propenso a mostrar simbolos raros por codificacion. Ahora
          // que hay dominio propio ya se podria comprobar, pero no vale una
          // publicacion nueva solo por dos acentos. Queda para cuando se toque
          // esta funcion por otro motivo.
          from: "Salon y Mas <hola@salonymas.com>",
          to: [d.contact_email],
          subject: `Stock bajo: ${d.product_name} en ${d.business_name}`,
          html: `
          <p>El producto <strong>${d.product_name}</strong>${brandText} de la sede ${d.branch_name} quedo con <strong>${d.current_stock} ${d.unit}</strong>, en o por debajo del minimo configurado (${d.minimum_stock} ${d.unit}).</p>
          <p>Registra una compra pronto para no quedarte sin stock.</p>
        `,
        }),
      });
    } catch (fallo) {
      console.error("FALLO al contactar a Resend:", fallo);
      return responder(
        { error: `No se pudo contactar a Resend: ${String(fallo)}` },
        502,
      );
    }

    console.log("PASO: respuesta de Resend |", respuestaResend.status);

    if (!respuestaResend.ok) {
      const detalle = await respuestaResend.text();
      console.error("Resend rechazo el envio:", detalle);
      return responder({ error: `Resend rechazo el envio: ${detalle}` }, 502);
    }

    return responder({ ok: true, sent: true }, 200);
  } catch (fallo) {
    console.error("FALLO INESPERADO en el paso:", paso, "|", fallo);
    return responder(
      { error: `Fallo inesperado en "${paso}": ${String(fallo)}`, paso },
      500,
    );
  }
});
