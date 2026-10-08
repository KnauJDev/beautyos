/// Las redes del salón: qué se acepta y cómo se arma el enlace (D-321).
///
/// **Por qué existe.** El 08-oct David escribió en Configuración los
/// *nombres* de sus cuentas — "Inspirant salon" en Facebook, "Inspirant
/// peluquería" en TikTok — y no sus usuarios. Con un nombre la página armaba
/// un enlace a una cuenta que no existe, y TikTok devolvía a la clienta a la
/// página. En Instagram, TikTok y Facebook un usuario es de letras sin tilde,
/// números, punto o guion bajo: nunca lleva espacios.
library;

final _usuarioValido = RegExp(r'^[A-Za-z0-9._]+$');

/// Sí si [valor] está vacío (no hay nada que revisar), es un enlace
/// (`https://…` o `algo.com/…`) o es un usuario válido, con o sin "@".
bool esUsuarioOEnlaceDeRed(String? valor) {
  final v = valor?.trim() ?? '';
  if (v.isEmpty) return true;
  if (v.startsWith('http://') || v.startsWith('https://')) return true;
  if (v.contains('.com/')) return !v.contains(RegExp(r'\s'));
  final usuario = v.startsWith('@') ? v.substring(1) : v;
  return _usuarioValido.hasMatch(usuario);
}

/// Lo que dice Configuración cuando lo escrito no sirve para abrir el perfil.
const avisoDeRedInvalida =
    'Escribe tu usuario sin espacios (por ejemplo @tusalon) o pega el enlace '
    'de tu perfil.';

String? avisoDeRed(String valor) =>
    esUsuarioOEnlaceDeRed(valor) ? null : avisoDeRedInvalida;

/// El enlace al perfil, o null si lo escrito no lleva a ningún perfil: así
/// la página no enseña un botón que manda a una cuenta que no existe.
///
/// [dominio] es el de la red ('instagram.com'); [armar] hace la dirección a
/// partir del usuario sin "@".
Uri? enlaceDeRed(
  String? valor, {
  required String dominio,
  required Uri Function(String usuario) armar,
}) {
  final v = valor?.trim() ?? '';
  if (v.isEmpty || !esUsuarioOEnlaceDeRed(v)) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return Uri.tryParse(v);
  if (v.contains('$dominio/') || v.contains('.com/')) {
    return Uri.tryParse('https://$v');
  }
  final usuario = v.startsWith('@') ? v.substring(1) : v;
  return usuario.isEmpty ? null : armar(usuario);
}
