// BeautyOS - Alarma de stock por correo (punto 8 del benchmarking).
//
// Requiere sesion de usuario valida (auth: "user"): ctx.supabase queda
// autenticado como quien invoca, asi que get_low_stock_alert_context
// (security definer) solo entrega datos si esa persona es tenant_owner/admin
// de esa sede y el producto realmente esta en el minimo o por debajo. Se
// invoca desde Flutter justo despues de registrar un consumo interno.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

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

    let body: { branch_id?: string; product_id?: string };
    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "Cuerpo invalido." }, { status: 400 });
    }

    const branchId = body.branch_id;
    const productId = body.product_id;
    if (!branchId || !productId) {
      return Response.json(
        { error: "Faltan branch_id o product_id." },
        { status: 400 },
      );
    }

    const { data, error } = await ctx.supabase
      .rpc("get_low_stock_alert_context", {
        p_branch_id: branchId,
        p_product_id: productId,
      })
      .maybeSingle();

    if (error) {
      return Response.json({ error: error.message }, { status: 404 });
    }

    if (!data) {
      // No esta bajo el minimo, no autorizado, o sin correo de contacto: no
      // hay nada que enviar. No es un error.
      return Response.json({ ok: true, sent: false });
    }

    const brandText = data.brand ? ` (${data.brand})` : "";

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Salon y Mas <onboarding@resend.dev>",
        to: [data.contact_email],
        subject: `Stock bajo: ${data.product_name} en ${data.business_name}`,
        html: `
          <p>El producto <strong>${data.product_name}</strong>${brandText} de la sede ${data.branch_name} quedo con <strong>${data.current_stock} ${data.unit}</strong>, en o por debajo del minimo configurado (${data.minimum_stock} ${data.unit}).</p>
          <p>Registra una compra pronto para no quedarte sin stock.</p>
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

    return Response.json({ ok: true, sent: true });
  }),
};
