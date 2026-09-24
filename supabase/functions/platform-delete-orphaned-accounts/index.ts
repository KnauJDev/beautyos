// BeautyOS — Hallazgo AS (segunda mitad): borra de Supabase Auth las
// cuentas de un equipo que se quedaron sin ningún negocio, DESPUÉS de que
// `platform_delete_demo_tenant` borró las filas.
//
// EL ORDEN NO ES OPCIONAL, es una restricción real de la base:
// `tenant_memberships.user_id references auth.users(id) on delete
// restrict`. Mientras exista una fila de membresía apuntando a una cuenta,
// Postgres se niega a borrar esa cuenta -- no es una regla de este
// proyecto, es la integridad referencial. Por eso esta función se llama
// DESPUÉS de `platform_delete_demo_tenant`, nunca antes: recibe la lista de
// `userIds` que `platform-delete-tenant-storage` capturó mientras el
// negocio todavía existía, y cuando esta función corre, esas filas ya se
// fueron -- ahora sí se puede.
//
// Por qué el propietario lo pidió: al ver los 5 correos del equipo de un
// negocio de prueba antes de borrarlo, preguntó qué les pasaría.
// `platform_delete_demo_tenant` (D-246) deliberadamente no toca
// `auth.users` -- esas cuentas quedarían huérfanas, inofensivas, pero ahí
// para siempre, y hacerse correos de prueba nuevos es trabajoso. Sin esto,
// cada negocio de prueba borrado deja basura de cuentas detrás.
//
// DOS SEGUROS:
//   1. Solo se borra una cuenta si, en el momento de llamar, no tiene
//      NINGUNA fila en tenant_memberships -- en ningún negocio, no solo en
//      el que se acaba de borrar. Si pertenece a otro negocio (de prueba o
//      real), se queda intacta.
//   2. Ningún operador de plataforma (`platform_operators`) se borra jamás
//      por esta vía, tenga o no membresías -- su acceso no depende de
//      ellas, y confundir "sin membresía" con "huérfano" lo borraría por
//      error.

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
    let body: { userIds?: unknown } = {};
    try {
      body = await req.json();
    } catch {
      // Body vacío
    }

    const userIds = Array.isArray(body.userIds)
      ? Array.from(new Set(body.userIds.map((u) => String(u).trim()).filter(Boolean)))
      : [];

    if (userIds.length === 0) {
      return responder({ success: true, cuentasBorradas: [] }, 200);
    }

    const supabaseAdmin = crearSupabaseAdmin();
    const errores: string[] = [];
    const cuentasBorradas: string[] = [];

    paso = "comprobar cuentas de operador de plataforma";
    const { data: operadores, error: operadoresError } = await supabaseAdmin
      .from("platform_operators")
      .select("user_id")
      .in("user_id", userIds);

    if (operadoresError) {
      console.error("Error al leer platform_operators:", operadoresError.message);
      return responder({ error: `No se pudo comprobar operadores de plataforma: ${operadoresError.message}` }, 500);
    }

    const idsOperadores = new Set((operadores ?? []).map((o) => o.user_id as string));

    for (const userId of userIds) {
      if (idsOperadores.has(userId)) continue; // nunca se borra un operador de plataforma

      paso = `comprobar membresías restantes de ${userId}`;
      const { count, error: memError } = await supabaseAdmin
        .from("tenant_memberships")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId);

      if (memError) {
        console.error(`Error al comprobar membresías de ${userId}:`, memError.message);
        errores.push(`cuenta ${userId}: ${memError.message}`);
        continue;
      }

      if ((count ?? 0) > 0) continue; // todavía pertenece a algún negocio: se queda

      paso = `borrar cuenta huérfana ${userId}`;
      const { error: borrarError } = await supabaseAdmin.auth.admin.deleteUser(userId);
      if (borrarError) {
        errores.push(`cuenta ${userId}: ${borrarError.message}`);
        continue;
      }
      cuentasBorradas.push(userId);
    }

    if (errores.length > 0) {
      console.error("Fallo al borrar cuentas huérfanas:", errores.join(" | "));
      return responder({
        error: "No se pudieron borrar todas las cuentas huérfanas. " + errores.join(" | "),
        cuentasBorradas,
      }, 500);
    }

    return responder({ success: true, cuentasBorradas }, 200);
  } catch (error) {
    console.error(`Excepción en platform-delete-orphaned-accounts (paso: ${paso}):`, error);
    return responder({
      error: `Error interno al borrar cuentas (${paso}): ${error instanceof Error ? error.message : String(error)}`,
    }, 500);
  }
});
