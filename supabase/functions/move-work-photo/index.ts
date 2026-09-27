// BeautyOS — Hallazgo BX (D-285). Mueve el archivo de una foto de trabajo
// entre el almacén privado y el público: publicarla en el portafolio o
// retirarla de él.
//
// Por qué una función de servidor y no una política de UPDATE en Storage:
// mover exige ese permiso y no lo tiene nadie, así que desde el 09-ago
// (D-119) ninguna foto llegó nunca al almacén público. El propietario
// decidió el 27-sep no dárselo al dueño ni al administrador -- mismo criterio
// que en AS (D-278) --: con él podrían pasar una foto a público sin
// aprobación ni consentimiento de la clienta.
//
// TODA la autorización vive en SQL: primero se llama a
// `work_photo_authorize_move` CON LA SESIÓN DE LA PERSONA (no con
// service_role), y esa función decide si puede mover esa foto a ese
// destino: a público, solo si ya está aprobada y con consentimiento. Solo
// después se mueve el archivo con service_role.
//
// Reintentar es seguro: si el archivo ya está en el destino y no en el
// origen, no se hace nada más. `existeEn` es la misma que en
// client-consent-revoke-photo -- copiada a propósito para no tener que volver
// a publicar esa función, ya verificada, solo por compartir doce líneas.
//
// Con sesión obligatoria: `verify_jwt = true` en config.toml, y Flutter la
// llama con `cabecerasParaEdgeFunction()` (D-207).

import {
  crearSupabaseAdmin,
  crearSupabaseUsuario,
  resolverClaveSecreta,
  SUPABASE_URL,
} from "../_shared/supabase_keys.ts";
import { SupabaseClient } from "@supabase/supabase-js";

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

    paso = "revisar configuración del servidor";
    const { key: secretKey } = resolverClaveSecreta();
    if (!SUPABASE_URL || !secretKey) {
      console.error("Falta SUPABASE_URL o clave secreta en el servidor.");
      return responder({ error: "Error de configuración en el servidor." }, 500);
    }

    paso = "verificar sesión autenticada";
    const autorizacion = req.headers.get("Authorization");
    if (!autorizacion) {
      return responder({ error: "Se requiere una sesión autenticada." }, 401);
    }

    paso = "leer parámetros de solicitud";
    let body: { branchId?: string; photoId?: string; destino?: string } = {};
    try {
      body = await req.json();
    } catch {
      // Body vacío
    }
    const branchId = (body.branchId ?? "").toString().trim();
    const photoId = (body.photoId ?? "").toString().trim();
    const destino = (body.destino ?? "").toString().trim();
    if (!branchId || !photoId || (destino !== "publico" && destino !== "privado")) {
      return responder({ error: "Faltan branchId, photoId o un destino valido (publico/privado)." }, 400);
    }

    // 1. La autorización, en SQL, con la sesión de quien llama.
    paso = "autorizar el movimiento";
    const { data: ruta, error: rutaError } = await crearSupabaseUsuario(autorizacion).rpc(
      "work_photo_authorize_move",
      { p_branch_id: branchId, p_photo_id: photoId, p_destino: destino },
    );
    if (rutaError || !ruta) {
      return responder(
        { error: rutaError?.message ?? "No se pudo autorizar el movimiento de esta foto." },
        403,
      );
    }

    // 2. Mover, con service_role.
    paso = "mover el archivo";
    const origen = destino === "publico" ? BUCKET_PRIVADO : BUCKET_PUBLICO;
    const llegada = destino === "publico" ? BUCKET_PUBLICO : BUCKET_PRIVADO;
    const admin = crearSupabaseAdmin();
    const { error: moverError } = await admin.storage
      .from(origen)
      .move(ruta as string, ruta as string, { destinationBucket: llegada });

    if (moverError) {
      // ¿Ya estaba donde tiene que estar? Entonces no hay nada que hacer.
      const yaLlego = await existeEn(admin, llegada, ruta as string);
      const sigueEnOrigen = await existeEn(admin, origen, ruta as string);
      if (!yaLlego || sigueEnOrigen) {
        console.error(`Error al mover ${ruta} de ${origen} a ${llegada}:`, moverError.message);
        return responder({
          error: "No se pudo mover el archivo de la foto. Intenta otra vez: es seguro repetirlo.",
        }, 500);
      }
    }

    return responder({ success: true, destino }, 200);
  } catch (error) {
    console.error(`Excepción en move-work-photo (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al mover la foto (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
