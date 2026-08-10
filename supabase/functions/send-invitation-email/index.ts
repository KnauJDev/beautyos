// BeautyOS - Correo automatico de invitacion de equipo (D-062).
//
// Requiere sesion de usuario valida (auth: "user"): ctx.supabase queda
// autenticado como quien invoca, asi que get_team_invitation_email_context
// (security definer) solo entrega datos si esa misma persona creo la
// invitacion. La clave de Resend nunca sale de este servidor.
//
// 10-ago: se agrego captura de errores. Antes, cualquier fallo dentro del
// manejador mataba la funcion en silencio y Supabase devolvia un
// EDGE_FUNCTION_ERROR generico -- costo mas de una hora averiguar donde
// moria. Ahora cada paso deja rastro en los registros y el error real viaja
// en la respuesta.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

const ROLE_LABELS: Record<string, string> = {
  admin: "Administrador",
  stylist: "Estilista",
  assistant: "Asistente",
};

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    let paso = "inicio";
    try {
      if (req.method !== "POST") {
        return Response.json({ error: "Metodo no permitido." }, { status: 405 });
      }

      paso = "leer RESEND_API_KEY";
      console.log("PASO:", paso, "| definida:", Boolean(RESEND_API_KEY));

      if (!RESEND_API_KEY) {
        return Response.json(
          { error: "RESEND_API_KEY no esta configurada en Supabase." },
          { status: 500 },
        );
      }

      paso = "leer cuerpo";
      let body: { invitation_id?: string; app_url?: string };
      try {
        body = await req.json();
      } catch {
        return Response.json({ error: "Cuerpo invalido." }, { status: 400 });
      }

      const invitationId = body.invitation_id;
      const appUrl = body.app_url;
      if (!invitationId || !appUrl) {
        return Response.json(
          { error: "Faltan invitation_id o app_url." },
          { status: 400 },
        );
      }

      paso = "consultar get_team_invitation_email_context";
      console.log("PASO:", paso, "| invitation_id:", invitationId);

      const { data, error } = await ctx.supabase
        .rpc("get_team_invitation_email_context", {
          p_invitation_id: invitationId,
        })
        .maybeSingle();

      if (error || !data) {
        console.log("PASO:", paso, "| sin datos. error:", error?.message);
        return Response.json(
          {
            error:
              error?.message ??
              "Invitacion no encontrada, ya no esta pendiente, o no te pertenece.",
          },
          { status: 404 },
        );
      }

      paso = "preparar texto del correo";
      const roleText = ROLE_LABELS[data.role as string] ?? data.role;
      const expiresDate = new Date(data.expires_at as string)
        .toLocaleDateString("es-CO", {
          day: "numeric",
          month: "long",
          year: "numeric",
        });

      paso = "llamar a Resend";
      console.log("PASO:", paso, "| destinatario:", data.email);

      // Esta llamada estaba sin red: si fallaba, se llevaba la funcion entera
      // por delante y el mensaje que llegaba a la pantalla no decia nada.
      let emailResponse: Response;
      try {
        emailResponse = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${RESEND_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "Salon y Mas <hola@salonymas.com>",
            to: [data.email],
            subject:
              `Te invitaron a unirte a ${data.tenant_name} en Salon y Mas`,
            html: `
          <p>Te invitaron a unirte a <strong>${data.tenant_name}</strong> como <strong>${roleText}</strong> en la sede ${data.branch_name}.</p>
          <p>Para unirte, entra a <a href="${appUrl}">${appUrl}</a> y regístrate con este mismo correo (${data.email}). El sistema te va a reconocer automáticamente como invitado.</p>
          <p>Esta invitación vence el ${expiresDate}.</p>
        `,
          }),
        });
      } catch (fallo) {
        console.error("FALLO al contactar a Resend:", fallo);
        return Response.json(
          { error: `No se pudo contactar a Resend: ${String(fallo)}` },
          { status: 502 },
        );
      }

      console.log("PASO: respuesta de Resend |", emailResponse.status);

      if (!emailResponse.ok) {
        const details = await emailResponse.text();
        console.error("Resend rechazo el envio:", details);
        return Response.json(
          { error: `Resend rechazo el envio: ${details}` },
          { status: 502 },
        );
      }

      return Response.json({ ok: true });
    } catch (fallo) {
      // La red de seguridad. Sin esto, cualquier error inesperado mata la
      // funcion y Supabase responde un EDGE_FUNCTION_ERROR sin detalle.
      console.error("FALLO INESPERADO en el paso:", paso, "|", fallo);
      return Response.json(
        {
          error: `Fallo inesperado en el paso "${paso}": ${String(fallo)}`,
          paso,
        },
        { status: 500 },
      );
    }
  }),
};
