// BeautyOS - Correo automatico de invitacion de equipo (D-062).
//
// Requiere sesion de usuario valida (auth: "user"): ctx.supabase queda
// autenticado como quien invoca, asi que get_team_invitation_email_context
// (security definer) solo entrega datos si esa misma persona creo la
// invitacion. La clave de Resend nunca sale de este servidor.

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
    if (req.method !== "POST") {
      return Response.json({ error: "Metodo no permitido." }, { status: 405 });
    }

    if (!RESEND_API_KEY) {
      return Response.json(
        { error: "RESEND_API_KEY no esta configurada en Supabase." },
        { status: 500 },
      );
    }

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

    const { data, error } = await ctx.supabase
      .rpc("get_team_invitation_email_context", {
        p_invitation_id: invitationId,
      })
      .maybeSingle();

    if (error || !data) {
      return Response.json(
        {
          error:
            error?.message ??
            "Invitacion no encontrada, ya no esta pendiente, o no te pertenece.",
        },
        { status: 404 },
      );
    }

    const roleText = ROLE_LABELS[data.role as string] ?? data.role;
    const expiresDate = new Date(data.expires_at as string).toLocaleDateString(
      "es-CO",
      { day: "numeric", month: "long", year: "numeric" },
    );

    const emailResponse = await fetch("https://api.resend.com/emails", {
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
        // El nombre vuelve a llevar tildes. D-089 las habia quitado por
        // precaucion -- el campo "De:" es propenso a mostrar simbolos raros
        // por codificacion y no se podia comprobar en sandbox. Ahora si se
        // puede: si el primer correo real llega con el nombre roto, se
        // vuelve a "Salon y Mas" y queda resuelto de una vez.
        from: "Salón y Más <hola@salonymas.com>",
        to: [data.email],
        subject: `Te invitaron a unirte a ${data.tenant_name} en Salon y Mas`,
        html: `
          <p>Te invitaron a unirte a <strong>${data.tenant_name}</strong> como <strong>${roleText}</strong> en la sede ${data.branch_name}.</p>
          <p>Para unirte, entra a <a href="${appUrl}">${appUrl}</a> y regístrate con este mismo correo (${data.email}). El sistema te va a reconocer automáticamente como invitado.</p>
          <p>Esta invitación vence el ${expiresDate}.</p>
        `,
      }),
    });

    if (!emailResponse.ok) {
      const details = await emailResponse.text();
      return Response.json(
        { error: `Resend rechazo el envio: ${details}` },
        { status: 502 },
      );
    }

    return Response.json({ ok: true });
  }),
};
