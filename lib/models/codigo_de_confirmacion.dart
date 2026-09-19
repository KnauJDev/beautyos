/// Valida el código que llega por correo para confirmar una cuenta (D-248).
///
/// **POR QUÉ ESTO NO SABE CUÁNTOS DÍGITOS TIENE UN CÓDIGO.**
///
/// La primera versión, del 18-sep, exigía **exactamente 6** — en el
/// `maxLength` del campo, en la validación y en tres textos. El 19-sep el
/// propietario lo probó de verdad y el correo trajo **ocho**:
/// `59875879`. El campo le habría cortado dos dígitos y la validación
/// habría rechazado el resto.
///
/// **La longitud no vive aquí: vive en Supabase** (Authentication → Sign In /
/// Providers → Email), y se puede cambiar desde el panel sin tocar el código.
/// Escribirla a mano en Dart es **el mismo error que costó D-245**, donde
/// `register_tenant` llevaba escrito el código de un plan que vivía en la
/// base y quedó roto dieciséis días cuando ese plan se jubiló.
///
/// Así que aquí **no se comprueba la longitud exacta**, solo lo que es cierto
/// de cualquier código: que son dígitos y que hay una cantidad razonable. Si
/// mañana alguien pone códigos de 10, esto sigue funcionando y **nadie tiene
/// que acordarse de venir a cambiarlo**. Quien decide de verdad si el código
/// vale es el servidor.
class CodigoDeConfirmacion {
  const CodigoDeConfirmacion._();

  /// Suelo y techo deliberadamente anchos: no son una regla de negocio, son
  /// una red para no mandar al servidor lo que es obviamente basura.
  static const minimoDigitos = 4;
  static const maximoDigitos = 12;

  /// Devuelve el código listo para enviar, o `null` si no vale la pena
  /// intentarlo.
  static String? normalizar(String escrito) {
    // La gente pega el código con espacios, guiones o saltos de línea: eso no
    // es un error suyo. Se limpia en vez de rechazarlo.
    final soloDigitos = escrito.replaceAll(RegExp(r'[^0-9]'), '');

    if (soloDigitos.length < minimoDigitos) return null;
    if (soloDigitos.length > maximoDigitos) return null;

    return soloDigitos;
  }

  /// El aviso que se le enseña a quien escribió algo que no puede ser un
  /// código. **No dice un número de dígitos a propósito**, porque esta capa
  /// no lo sabe y prometerlo es lo que fallo el 18-sep.
  static const avisoDeFormato =
      'Escribe el código completo que te llegó por correo, solo números.';
}
