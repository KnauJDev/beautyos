// BeautyOS — Paso 9.48, Bloque 1. La mitad que SQL no puede hacer: firmar
// una URL temporal de una foto que todavía vive en el almacén PRIVADO
// (`work-photos-private`), para que la clienta pueda VERLA antes de decidir
// si autoriza publicarla.
//
// Por qué existe: `get_client_portal_data` (D-167, 29-ago) ya dejó escrito
// que esto faltaba -- "generar URLs firmadas... es infraestructura nueva...
// se deja fuera y se documenta, no se inventa a medias" -- y es exactamente
// el hueco del hallazgo AU. Sin poder ver la foto, pedirle que autorice
// publicarla no es un consentimiento informado.
//
// TODA la autorización vive en SQL, no aquí: esta función llama primero a
// `client_consent_get_photo_path` con la clave PÚBLICA (sin ningún
// privilegio), y esa RPC es la que decide si el token entregado de verdad
// identifica a la clienta dueña de esta foto. Solo después de que SQL lo
// confirma, esta función usa `service_role` para hablar con Storage --
// que es lo único que SQL no puede hacer por sí solo.
//
// Sin sesión de Supabase Auth: quien llama es una clienta anónima con un
// token (el de su portal o el de su enlace directo), igual que
// `client_portal_authenticate`. Por eso `verify_jwt = false` en config.toml,
// mismo criterio que `epayco-webhook`.

import {
  crearSupabaseAdmin,
  resolverClavePublica,
  SUPABASE_URL,
} from "../_shared/supabase_keys.ts";
import { createClient } from "@supabase/supabase-js";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SEGUNDOS_DE_VIGENCIA = 300; // 5 minutos: alcanza para verla y decidir.

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

    paso = "leer parámetros de solicitud";
    let body: { photoId?: string; portalToken?: string; consentToken?: string } = {};
    try {
      body = await req.json();
    } catch {
      // Body vacío
    }

    const photoId = (body.photoId ?? "").toString().trim();
    const portalToken = (body.portalToken ?? "").toString().trim() || null;
    const consentToken = (body.consentToken ?? "").toString().trim() || null;

    if (!photoId) {
      return responder({ error: "Falta photoId." }, 400);
    }
    if (!portalToken && !consentToken) {
      return responder({ error: "Falta el token de acceso." }, 400);
    }

    paso = "revisar configuración del servidor";
    const { key: publicKey } = resolverClavePublica();
    if (!SUPABASE_URL || !publicKey) {
      console.error("Falta SUPABASE_URL o clave pública en el servidor.");
      return responder({ error: "Error de configuración en el servidor." }, 500);
    }

    // Paso 1: la autorización, entera en SQL. Sin ningún privilegio todavía
    // -- si el token no es de esta foto, la RPC falla y aquí se detiene.
    paso = "verificar el acceso a la foto con su token";
    const supabasePublico = createClient(SUPABASE_URL, publicKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: ruta, error: rutaError } = await supabasePublico.rpc(
      "client_consent_get_photo_path",
      {
        p_photo_id: photoId,
        p_portal_token: portalToken,
        p_consent_token: consentToken,
      },
    );

    if (rutaError || !ruta) {
      return responder(
        { error: rutaError?.message ?? "No se pudo verificar el acceso a esta foto." },
        403,
      );
    }

    // Paso 2: lo que SQL no puede hacer. Storage se firma con service_role.
    paso = "generar la URL firmada de la foto";
    const supabaseAdmin = crearSupabaseAdmin();
    const { data: firmada, error: firmaError } = await supabaseAdmin.storage
      .from("work-photos-private")
      .createSignedUrl(ruta as string, SEGUNDOS_DE_VIGENCIA);

    if (firmaError || !firmada?.signedUrl) {
      console.error("Error al firmar la foto:", firmaError?.message);
      return responder({ error: "No se pudo generar el enlace de la foto." }, 500);
    }

    return responder({ url: firmada.signedUrl, expiresInSeconds: SEGUNDOS_DE_VIGENCIA }, 200);
  } catch (error) {
    console.error(`Excepción en client-consent-photo-url (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al generar la foto (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
