// BeautyOS — Módulo compartido para resolución unificada y segura de claves de Supabase.
// Soporta claves modernas (sb_secret_..., sb_publishable_...), variables personalizadas y fallback heredado.

import { createClient, SupabaseClient } from "@supabase/supabase-js";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";

/**
 * Resuelve la clave secreta (service_role / secret key) con prioridad para evitar el error
 * 'Legacy API keys are disabled' cuando Supabase desactiva los JWTs heredados.
 */
export function resolverClaveSecreta(): { key: string; isLegacy: boolean; source: string } {
  // 1. Variable personalizada no reservada (permite fijar explícitamente la secret key en Supabase Secrets)
  const customSecret = Deno.env.get("BEAUTYOS_SUPABASE_SECRET_KEY");
  if (customSecret && customSecret.trim().length > 0) {
    const k = customSecret.trim();
    return { key: k, isLegacy: k.startsWith("eyJ"), source: "BEAUTYOS_SUPABASE_SECRET_KEY" };
  }

  // 2. Diccionario o cadena de secret keys del nuevo sistema de Supabase
  const secretas = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (secretas) {
    try {
      const dic = JSON.parse(secretas);
      if (typeof dic === "object" && dic !== null) {
        const valores = Object.values(dic) as string[];
        if (valores.length > 0 && valores[0]) {
          const k = valores[0].trim();
          return { key: k, isLegacy: k.startsWith("eyJ"), source: "SUPABASE_SECRET_KEYS(json)" };
        }
      }
    } catch {
      if (secretas.trim().length > 0) {
        const k = secretas.trim();
        return { key: k, isLegacy: k.startsWith("eyJ"), source: "SUPABASE_SECRET_KEYS(raw)" };
      }
    }
  }

  // 3. Clave legacy heredada
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return { key: legacy, isLegacy: legacy.startsWith("eyJ"), source: "SUPABASE_SERVICE_ROLE_KEY" };
}

/**
 * Resuelve la clave pública / publishable key con prioridad moderna.
 */
export function resolverClavePublica(): { key: string; isLegacy: boolean; source: string } {
  const customPublic = Deno.env.get("BEAUTYOS_SUPABASE_PUBLIC_KEY");
  if (customPublic && customPublic.trim().length > 0) {
    const k = customPublic.trim();
    return { key: k, isLegacy: k.startsWith("eyJ"), source: "BEAUTYOS_SUPABASE_PUBLIC_KEY" };
  }

  const nuevas = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (nuevas) {
    try {
      const dic = JSON.parse(nuevas);
      if (typeof dic === "object" && dic !== null) {
        const valores = Object.values(dic) as string[];
        if (valores.length > 0 && valores[0]) {
          const k = valores[0].trim();
          return { key: k, isLegacy: k.startsWith("eyJ"), source: "SUPABASE_PUBLISHABLE_KEYS(json)" };
        }
      }
    } catch {
      if (nuevas.trim().length > 0) {
        const k = nuevas.trim();
        return { key: k, isLegacy: k.startsWith("eyJ"), source: "SUPABASE_PUBLISHABLE_KEYS(raw)" };
      }
    }
  }

  const legacy = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  return { key: legacy, isLegacy: legacy.startsWith("eyJ"), source: "SUPABASE_ANON_KEY" };
}

/**
 * Crea un cliente Supabase administrativo con clave secreta segura.
 */
export function crearSupabaseAdmin(): SupabaseClient {
  const { key, isLegacy, source } = resolverClaveSecreta();
  if (!key) {
    console.error("CRÍTICO: No se encontró ninguna clave secreta configurada.");
  } else if (isLegacy) {
    console.warn(`AVISO DE SEGURIDAD: Usando clave secreta legacy (${source}) que podría ser rechazada si el proyecto desactivó legacy API keys.`);
  } else {
    console.log(`Cliente admin inicializado exitosamente con clave moderna desde ${source}.`);
  }

  return createClient(SUPABASE_URL, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * Crea un cliente Supabase en el contexto autenticado del usuario que realiza la solicitud.
 */
export function crearSupabaseUsuario(authHeader: string): SupabaseClient {
  const { key } = resolverClavePublica();
  return createClient(SUPABASE_URL, key, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
