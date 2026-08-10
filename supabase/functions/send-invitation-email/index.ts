// BeautyOS - Correo automatico de invitacion de equipo (D-062).
//
// 10-ago: se quito la dependencia de `@supabase/server` (`withSupabase`).
//
// POR QUE. Esa libreria estaba anclada como `npm:@supabase/server@^1`, o sea
// "la version mas nueva que haya" -- cada despliegue traia un codigo distinto
// sin que nadie lo decidiera. Y se rompia **antes** de ejecutar la primera
// linea nuestra: los registros mostraban `booted` y nada mas, ni un solo
// `console.log` propio, y Supabase devolvia un `EDGE_FUNCTION_ERROR` sin
// detalle. Costo dos horas averiguar que el fallo no estaba en nuestro codigo
// sino en la capa de encima.
//
// Lo unico que hacia era leer la sesion de quien llama. Eso se hace aqui con
// `@supabase/supabase-js`, la misma libreria que usa la aplicacion.
//
// La sesion viaja en la cabecera `Authorization` y se le pasa tal cual al
// cliente: asi `get_team_invitation_email_context` (security definer) sigue
// viendo al usuario real y solo entrega datos si esa misma persona creo la
// invitacion. La clave de Resend nunca sale de este servidor.

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

const ROLE_LABELS: Record<string, string> = {
  admin: "Administrador",
  stylist: "Estilista",
  assistant: "Asistente",
};

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
      return responder({ error: "Falta la sesion de quien invita." }, 401);
    }

    paso = "leer cuerpo";
    let body: { invitation_id?: string; app_url?: string };
    try {
      body = await req.json();
    } catch {
      return responder({ error: "Cuerpo invalido." }, 400);
    }

    const invitationId = body.invitation_id;
    const appUrl = body.app_url;
    if (!invitationId || !appUrl) {
      return responder({ error: "Faltan invitation_id o app_url." }, 400);
    }

    paso = "consultar la invitacion";
    console.log("PASO:", paso, "| id:", invitationId);

    const supabase = createClient(SUPABASE_URL, CLAVE_PUBLICA, {
      global: { headers: { Authorization: autorizacion } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await supabase
      .rpc("get_team_invitation_email_context", {
        p_invitation_id: invitationId,
      })
      .maybeSingle();

    if (error || !data) {
      console.log("PASO:", paso, "| sin datos |", error?.message);
      return responder(
        {
          error: error?.message ??
            "Invitacion no encontrada, ya no esta pendiente, o no te pertenece.",
        },
        404,
      );
    }

    paso = "preparar el correo";
    const d = data as Record<string, string>;
    const roleText = ROLE_LABELS[d.role] ?? d.role;
    const expiresDate = new Date(d.expires_at).toLocaleDateString("es-CO", {
      day: "numeric",
      month: "long",
      year: "numeric",
    });

    paso = "enviar por Resend";
    console.log("PASO:", paso, "| para:", d.email);

    let respuestaResend: Response;
    try {
      respuestaResend = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "Salon y Mas <hola@salonymas.com>",
          to: [d.email],
          subject: `Te invitaron a unirte a ${d.tenant_name} en Salon y Mas`,
          html: `
          <p>Te invitaron a unirte a <strong>${d.tenant_name}</strong> como <strong>${roleText}</strong> en la sede ${d.branch_name}.</p>
          <p>Para unirte, entra a <a href="${appUrl}">${appUrl}</a> y registrate con este mismo correo (${d.email}).</p>
          <p>Esta invitacion vence el ${expiresDate}.</p>
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
      return responder(
        { error: `Resend rechazo el envio: ${detalle}` },
        502,
      );
    }

    return responder({ ok: true }, 200);
  } catch (fallo) {
    console.error("FALLO INESPERADO en el paso:", paso, "|", fallo);
    return responder(
      { error: `Fallo inesperado en "${paso}": ${String(fallo)}`, paso },
      500,
    );
  }
});
