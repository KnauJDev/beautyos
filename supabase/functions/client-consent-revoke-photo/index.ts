// BeautyOS — Paso 9.48, Bloque 2 (D-282). La clienta retira su autorización
// de una foto que YA está publicada (Ley 1581: puede revocarla).
//
// Retirarla de verdad es sacarla de internet: mover el archivo del almacén
// público (`work-photos`) al privado. SQL no puede mover archivos, y la
// clienta no tiene sesión para hacerlo desde la app, así que lo hace esta
// función con `service_role` -- el mismo `move` que usa el salón en
// `WorkPhotoStorage.despublicar`, y en el MISMO ORDEN que
// `setPortfolioApproval`: primero se saca de internet, después se anota.
//
// TRES PASOS, y la autorización vive entera en SQL:
//   1. `client_consent_get_published_photo_path`, con la clave PÚBLICA: si
//      el token no es de la dueña de esta foto, falla y aquí se detiene.
//   2. Mover el archivo, con `service_role`.
//   3. `client_consent_finish_revoke`, con `service_role` (es la única que
//      puede llamarla): vuelve a resolver a la clienta con su token y anota.
//
// SI SE CORTA ENTRE EL 2 Y EL 3 (el archivo ya es privado y la base dice
// que sigue publicado), reintentar es seguro: el paso 2 comprueba si el
// archivo ya está en el almacén privado y, si está, sigue al 3 en vez de
// fallar por "no existe en el público".
//
// Sin sesión de Supabase Auth, igual que client-consent-photo-url:
// `verify_jwt = false` en config.toml.

import {
  crearSupabaseAdmin,
  resolverClavePublica,
  SUPABASE_URL,
} from "../_shared/supabase_keys.ts";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BUCKET_PUBLICO = "work-photos";
const BUCKET_PRIVADO = "work-photos-private";

function responder(cuerpo: unknown, status: number) {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ¿Está este archivo en este almacén? Se usa `list` con búsqueda por nombre
// dentro de su carpeta, que existe en todas las versiones del cliente.
async function existeEn(
  admin: SupabaseClient,
  bucket: string,
  ruta: string,
): Promise<boolean> {
  const corte = ruta.lastIndexOf("/");
  const carpeta = corte === -1 ? "" : ruta.slice(0, corte);
  const nombre = corte === -1 ? ruta : ruta.slice(corte + 1);
  const { data, error } = await admin.storage.from(bucket).list(carpeta, {
    search: nombre,
  });
  if (error) return false;
  return (data ?? []).some((archivo) => archivo.name === nombre);
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

    const parametros = {
      p_photo_id: photoId,
      p_portal_token: portalToken,
      p_consent_token: consentToken,
    };

    // 1. La autorización, entera en SQL, sin ningún privilegio todavía.
    paso = "verificar que la foto es suya y está publicada";
    const supabasePublico = createClient(SUPABASE_URL, publicKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: ruta, error: rutaError } = await supabasePublico.rpc(
      "client_consent_get_published_photo_path",
      parametros,
    );
    if (rutaError || !ruta) {
      return responder(
        { error: rutaError?.message ?? "No se pudo verificar esta foto." },
        403,
      );
    }

    // 2. Sacarla de internet.
    paso = "sacar la foto del almacén público";
    const admin = crearSupabaseAdmin();
    const { error: moverError } = await admin.storage
      .from(BUCKET_PUBLICO)
      .move(ruta as string, ruta as string, { destinationBucket: BUCKET_PRIVADO });

    if (moverError) {
      // ¿Un intento anterior ya la movió y se cortó antes de anotarlo?
      const yaPrivada = await existeEn(admin, BUCKET_PRIVADO, ruta as string);
      const sigueEnPublico = await existeEn(admin, BUCKET_PUBLICO, ruta as string);
      if (!yaPrivada || sigueEnPublico) {
        console.error("Error al mover la foto al almacén privado:", moverError.message);
        return responder({
          error: "No se pudo retirar la foto. No se cambió nada: sigue igual que antes, " +
            "puedes intentarlo otra vez.",
        }, 500);
      }
    }

    // 3. Anotarlo, solo ahora que ya no está en internet.
    paso = "anotar la foto como retirada";
    const { error: anotarError } = await admin.rpc("client_consent_finish_revoke", parametros);
    if (anotarError) {
      console.error("La foto salió de internet pero no se pudo anotar:", anotarError.message);
      return responder({
        error: "La foto ya no está en internet, pero no se pudo terminar de anotar. " +
          "Intenta otra vez: es seguro repetirlo.",
      }, 500);
    }

    return responder({ success: true }, 200);
  } catch (error) {
    console.error(`Excepción en client-consent-revoke-photo (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al retirar la foto (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
