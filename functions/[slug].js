// La tarjeta de WhatsApp de cada salón (paso 3 del plan de David, D-316).
//
// POR QUÉ EXISTE
//
// La app es Flutter Web: el HTML que se descarga es el mismo `index.html` para
// todos, con el título "Salón y Más" y la descripción comercial del producto.
// WhatsApp, Facebook y las demás redes NO ejecutan la app: leen ese HTML para
// armar la tarjeta del enlace. Así, cuando David compartía
// `salonymas.com/inspirant-salon`, la tarjeta anunciaba Salón y Más y no su
// salón. El propietario lo pidió el 03-oct.
//
// QUÉ HACE
//
// Solo cuando quien pide la página es el lector de vistas previas de una red
// (WhatsApp, Facebook, Telegram…), busca el salón por su dirección con la
// misma función pública que usa la página del salón (`get_public_salon_by_slug`,
// rol anon, la llave publicable que ya va dentro de la app) y le cambia al
// HTML el título, la descripción y la imagen:
//   - título: el nombre del salón
//   - texto: "Agenda tu cita en línea · <ciudad>"   (decisión del 03-oct)
//   - imagen: la portada; si no hay portada, el logo (decisión del 03-oct)
//
// A LAS PERSONAS NO LES CAMBIA NADA: se les devuelve lo que devuelve hoy el
// servidor de archivos (`env.ASSETS.fetch`, que aplica `_headers` y
// `_redirects`, según la documentación de Cloudflare Pages). Y ante cualquier
// fallo —la base no responde, el salón no existe, la dirección no es de un
// salón— también se devuelve la página tal cual: lo peor que puede pasar es la
// tarjeta de siempre.
//
// `web/_routes.json` deja fuera de esta función los archivos de la app
// (main.dart.js, íconos…), para que no gasten invocaciones.

const SUPABASE_URL = 'https://eogppgbdnwxdtcbctaol.supabase.co';
// La llave PUBLICABLE (rol anon), la misma que está en `lib/main.dart` y que
// cualquiera puede leer en el JavaScript publicado. Nunca una llave secreta.
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_3MOOddcfu6tga68hPr06gw_IdEJ74Pc';

const SITIO = 'https://salonymas.com';

// Los lectores de vistas previas de las redes y mensajerías. Los buscadores
// (Google, Bing) quedan fuera a propósito: ejecutan la app y ven lo mismo que
// una persona.
const LECTORES_DE_VISTA_PREVIA =
  /WhatsApp|facebookexternalhit|Facebot|Twitterbot|TelegramBot|LinkedInBot|Slackbot|Discordbot|Pinterest|SkypeUriPreview|redditbot|Iframely|Embedly/i;

// El mismo formato que la restricción `tenants_slug_format_check`.
const FORMATO_DE_SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;

export function esLectorDeVistaPrevia(userAgent) {
  return LECTORES_DE_VISTA_PREVIA.test(userAgent || '');
}

export function slugValido(slug) {
  const limpio = String(slug || '').trim().toLowerCase();
  return limpio.length > 0 && limpio.length <= 80 && FORMATO_DE_SLUG.test(limpio)
    ? limpio
    : null;
}

function escapar(texto) {
  return String(texto)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function soloHttps(url) {
  const limpio = String(url || '').trim();
  return limpio.startsWith('https://') ? limpio : null;
}

// Lo que va en la tarjeta. Separado para poder probarlo sin Cloudflare.
export function tarjetaDelSalon(salon, slug) {
  const nombre = String(salon.name || '').trim();
  if (!nombre) return null;

  const ciudad = String(salon.city || '').trim();
  const portada = soloHttps(salon.cover_photo_url);
  const logo = soloHttps(salon.logo_url);

  return {
    titulo: nombre,
    descripcion: ciudad
      ? `Agenda tu cita en línea · ${ciudad}`
      : 'Agenda tu cita en línea',
    imagen: portada || logo,
    // Con portada, la imagen grande y ancha; con logo, la pequeña al lado.
    tipoDeTarjeta: portada ? 'summary_large_image' : 'summary',
    url: `${SITIO}/${slug}`,
  };
}

export function etiquetasDeLaTarjeta(tarjeta) {
  const meta = (atributo, clave, valor) =>
    `<meta ${atributo}="${clave}" content="${escapar(valor)}">`;

  const etiquetas = [
    meta('property', 'og:type', 'website'),
    meta('property', 'og:locale', 'es_CO'),
    meta('property', 'og:url', tarjeta.url),
    meta('property', 'og:title', tarjeta.titulo),
    meta('property', 'og:description', tarjeta.descripcion),
    meta('name', 'twitter:card', tarjeta.tipoDeTarjeta),
    meta('name', 'twitter:title', tarjeta.titulo),
    meta('name', 'twitter:description', tarjeta.descripcion),
  ];
  if (tarjeta.imagen) {
    etiquetas.push(meta('property', 'og:image', tarjeta.imagen));
    etiquetas.push(meta('name', 'twitter:image', tarjeta.imagen));
  }
  return etiquetas.join('\n  ');
}

async function buscarSalon(slug) {
  const respuesta = await fetch(
    `${SUPABASE_URL}/rest/v1/rpc/get_public_salon_by_slug`,
    {
      method: 'POST',
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ p_slug: slug }),
      signal: AbortSignal.timeout(3000),
    },
  );
  if (!respuesta.ok) return null;
  const filas = await respuesta.json();
  return Array.isArray(filas) && filas.length > 0 ? filas[0] : null;
}

export async function onRequest(context) {
  const { request, env, params } = context;
  const comoHoy = () => env.ASSETS.fetch(request);

  if (request.method !== 'GET' && request.method !== 'HEAD') return comoHoy();
  if (!esLectorDeVistaPrevia(request.headers.get('User-Agent'))) return comoHoy();

  const slug = slugValido(params.slug);
  if (!slug) return comoHoy();

  try {
    const salon = await buscarSalon(slug);
    const tarjeta = salon ? tarjetaDelSalon(salon, slug) : null;
    if (!tarjeta) return comoHoy();

    const pagina = await comoHoy();
    const tipo = pagina.headers.get('Content-Type') || '';
    if (!pagina.ok || !tipo.includes('text/html')) return pagina;

    return new HTMLRewriter()
      .on('title', {
        element(el) {
          el.setInnerContent(tarjeta.titulo);
        },
      })
      .on('meta[name="description"]', {
        element(el) {
          el.setAttribute('content', tarjeta.descripcion);
        },
      })
      .on('head', {
        element(el) {
          el.append(`\n  ${etiquetasDeLaTarjeta(tarjeta)}\n`, { html: true });
        },
      })
      .transform(pagina);
  } catch (_) {
    return comoHoy();
  }
}
