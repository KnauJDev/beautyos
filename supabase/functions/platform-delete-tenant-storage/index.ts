// BeautyOS — Hallazgo AS (primera mitad): borra los archivos de Storage de
// un negocio DE PRUEBA antes de que `platform_delete_demo_tenant` borre sus
// filas, y devuelve la lista de cuentas de su equipo para que, DESPUÉS de
// borrar las filas, `platform-delete-orphaned-accounts` pueda limpiar las
// que se queden huérfanas.
//
// `platform_delete_demo_tenant` (D-246) descubre y borra por `tenant_id`
// cualquier tabla de `public`, pero deliberadamente NO toca Storage — los
// archivos viven fuera de la base y su comentario lo deja escrito: "Las
// filas de fotos se van; los archivos viven fuera de la base". Sin esto,
// borrar un negocio de prueba deja fotos, logo, portada y fotos de
// estilistas huérfanos en cinco almacenes, para siempre.
//
// MISMO ORDEN que ya usan `delete_work_photo` y `setPortfolioApproval` en
// este proyecto: el archivo se borra ANTES que la fila que lo referencia.
// Si algo falla a medias aquí, el negocio sigue existiendo intacto (esta
// función no toca ninguna tabla, solo Storage) y se puede reintentar.
//
// Por qué una función de servidor y no ampliar las políticas de `delete` de
// Storage (como se hizo en BC con las de `select`): esto SÍ borra, y
// ampliar el permiso de borrado directo del operador de plataforma sobre el
// Storage de cualquier negocio es una superficie mayor que ampliar el de
// lectura. Aquí el borrado pasa por un solo camino con `service_role`, sin
// tocar ninguna política — decisión del propietario, 24-sep.
//
// El seguro NO se le pide prestado al cliente ni a `platform_delete_demo_
// tenant`: esta función vuelve a comprobar `is_demo = true` por su cuenta,
// con su propia consulta a `service_role`, antes de borrar un solo archivo.
//
// Por qué la lista de `equipoUserIds` sale de AQUÍ y no de
// `platform-delete-orphaned-accounts`: una vez que `platform_delete_demo_
// tenant` borra las filas de `tenant_memberships`, ya no queda ningún
// registro de quién formaba parte de este negocio. La lista hay que
// capturarla ANTES, mientras el negocio todavía existe.

import {
  crearSupabaseAdmin,
  crearSupabaseUsuario,
  resolverClaveSecreta,
  SUPABASE_URL,
} from "../_shared/supabase_keys.ts";

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

// Los cinco almacenes son públicos salvo `work-photos-private`, y todos
// guardan la dirección pública con el mismo patrón:
// `.../object/public/{bucket}/{ruta}`. Es el mismo separador que ya usó el
// backfill de work_photos el 09-ago para reconstruir `storage_path` desde
// `photo_url` — no se inventa uno nuevo.
function rutaDesdeUrlPublica(url: string, bucket: string): string | null {
  const marca = `/object/public/${bucket}/`;
  const indice = url.indexOf(marca);
  if (indice === -1) return null;
  const ruta = url.slice(indice + marca.length);
  return ruta.trim() || null;
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
      return responder({ error: "Error de configuración de base de datos en el servidor." }, 500);
    }

    paso = "verificar sesión autenticada";
    const autorizacion = req.headers.get("Authorization");
    if (!autorizacion) {
      return responder({ error: "Se requiere una sesión autenticada." }, 401);
    }

    paso = "verificar rol de plataforma";
    const { data: rol, error: rolError } = await crearSupabaseUsuario(autorizacion)
      .rpc("get_my_platform_role");

    if (rolError || !rol) {
      if (rolError) console.error("Error al comprobar rol de plataforma:", rolError.message);
      return responder({ error: "No autorizado: se requiere rol de plataforma." }, 403);
    }

    paso = "leer parámetros de solicitud";
    let body: { tenantId?: string } = {};
    try {
      body = await req.json();
    } catch {
      // Body vacío
    }

    const tenantId = (body.tenantId ?? "").toString().trim();
    if (!tenantId) {
      return responder({ error: "Falta tenantId." }, 400);
    }

    const supabaseAdmin = crearSupabaseAdmin();

    // EL SEGURO. Se vuelve a comprobar aquí, sin fiarse de nadie más: solo
    // negocios de PRUEBA. Mismo criterio, mismo mensaje que D-246.
    paso = "comprobar que el negocio es de prueba";
    const { data: tenant, error: tenantError } = await supabaseAdmin
      .from("tenants")
      .select("id, name, is_demo, logo_url, cover_photo_url")
      .eq("id", tenantId)
      .maybeSingle();

    if (tenantError) {
      console.error("Error al leer el negocio:", tenantError.message);
      return responder({ error: `No se pudo leer el negocio: ${tenantError.message}` }, 500);
    }
    if (!tenant) {
      return responder({ error: `No existe el negocio ${tenantId}.` }, 404);
    }
    if (tenant.is_demo !== true) {
      return responder({
        error: `El negocio "${tenant.name}" NO está marcado como de prueba, así que no se borra ` +
          "ningún archivo. Esta función solo toca negocios con is_demo = true, igual que " +
          "platform_delete_demo_tenant (D-225, D-246).",
      }, 403);
    }

    const eliminados: Record<string, number> = {
      "work-photos": 0,
      "work-photos-private": 0,
      "tenant-logos": 0,
      "tenant-covers": 0,
      "stylist-photos": 0,
    };
    const errores: string[] = [];

    async function borrar(bucket: string, rutas: string[]) {
      if (rutas.length === 0) return;
      const { data, error } = await supabaseAdmin.storage.from(bucket).remove(rutas);
      if (error) {
        errores.push(`${bucket}: ${error.message}`);
        return;
      }
      eliminados[bucket] = (eliminados[bucket] ?? 0) + (data?.length ?? rutas.length);
    }

    // 1. Fotos de trabajo: ya traen su almacén y su ruta, sin adivinar nada.
    paso = "leer fotos de trabajo";
    const { data: fotos, error: fotosError } = await supabaseAdmin
      .from("work_photos")
      .select("storage_bucket, storage_path")
      .eq("tenant_id", tenantId)
      .eq("active", true)
      .not("storage_path", "is", null);

    if (fotosError) {
      console.error("Error al leer work_photos:", fotosError.message);
      return responder({ error: `No se pudo leer las fotos de trabajo: ${fotosError.message}` }, 500);
    }

    const porAlmacen = new Map<string, string[]>();
    for (const foto of fotos ?? []) {
      const bucket = foto.storage_bucket as string;
      const ruta = foto.storage_path as string;
      if (!porAlmacen.has(bucket)) porAlmacen.set(bucket, []);
      porAlmacen.get(bucket)!.push(ruta);
    }

    paso = "borrar fotos de trabajo";
    for (const [bucket, rutas] of porAlmacen) {
      await borrar(bucket, rutas);
    }

    // 2. Logo y portada del negocio: la dirección pública se leyó junto con
    //    el seguro is_demo, arriba. Se deriva la ruta del mismo modo que el
    //    backfill de work_photos derivó storage_path desde photo_url.
    paso = "borrar logo y portada";
    if (tenant.logo_url) {
      const ruta = rutaDesdeUrlPublica(tenant.logo_url, "tenant-logos");
      if (ruta) await borrar("tenant-logos", [ruta]);
    }
    if (tenant.cover_photo_url) {
      const ruta = rutaDesdeUrlPublica(tenant.cover_photo_url, "tenant-covers");
      if (ruta) await borrar("tenant-covers", [ruta]);
    }

    // 3. Fotos de estilistas.
    paso = "leer fotos de estilistas";
    const { data: estilistas, error: estilistasError } = await supabaseAdmin
      .from("stylists")
      .select("photo_url")
      .eq("tenant_id", tenantId)
      .not("photo_url", "is", null);

    if (estilistasError) {
      console.error("Error al leer stylists:", estilistasError.message);
      return responder({ error: `No se pudo leer las fotos de estilistas: ${estilistasError.message}` }, 500);
    }

    paso = "borrar fotos de estilistas";
    const rutasEstilistas: string[] = [];
    for (const estilista of estilistas ?? []) {
      const ruta = rutaDesdeUrlPublica(estilista.photo_url as string, "stylist-photos");
      if (ruta) rutasEstilistas.push(ruta);
    }
    await borrar("stylist-photos", rutasEstilistas);

    // 4. La lista del equipo, para limpiar cuentas huérfanas DESPUÉS de que
    //    platform_delete_demo_tenant borre las filas de tenant_memberships
    //    -- no antes: mientras esa fila exista, auth.users no se puede
    //    borrar (tenant_memberships.user_id es "on delete restrict").
    paso = "leer equipo del negocio";
    const { data: membresias, error: membresiasError } = await supabaseAdmin
      .from("tenant_memberships")
      .select("user_id")
      .eq("tenant_id", tenantId);

    if (membresiasError) {
      console.error("Error al leer tenant_memberships:", membresiasError.message);
      return responder({ error: `No se pudo leer el equipo del negocio: ${membresiasError.message}` }, 500);
    }

    const equipoUserIds = Array.from(
      new Set((membresias ?? []).map((m) => m.user_id as string)),
    );

    if (errores.length > 0) {
      console.error(`Fallo al borrar archivos del negocio ${tenantId}:`, errores.join(" | "));
      return responder({
        error: "No se pudieron borrar todos los archivos. No se borró ninguna fila de la base: " +
          "es seguro reintentar. " + errores.join(" | "),
        eliminados,
      }, 500);
    }

    return responder({ success: true, tenantId, eliminados, equipoUserIds }, 200);
  } catch (error) {
    console.error(`Excepción en platform-delete-tenant-storage (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al borrar archivos (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
