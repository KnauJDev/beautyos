/// Lo que se le dice a alguien cuando el enlace de un correo no funcionó
/// (hallazgo AM, 18-sep).
///
/// **El problema que resuelve.** Supabase devuelve a la persona a
/// `salonymas.com/?error=access_denied&error_code=otp_expired&error_description=...`
/// cuando un enlace de correo falla. Hasta hoy `main.dart` leía **doce**
/// parámetros de esa dirección — `reservar`, `resena`, `planes`, `terminos`,
/// `privacidad`, `partners`, `salon`, `ref`, `ref_payco`… — y **ninguno era el
/// error**. La persona veía una pantalla de acceso normal, sin una sola palabra
/// sobre lo que acababa de fallar.
///
/// El 18-sep un estilista invitado lo vivió entero: pulsó su enlace, Supabase
/// lo rechazó, y **entró igual porque acababa de escribir esa contraseña dos
/// minutos antes**. Quien abra el correo al día siguiente no tendrá esa pista.
///
/// **Por qué el mensaje no repite el de Supabase.** El texto original dice
/// *"Email link is invalid or has expired"*, que está en inglés y además no
/// dice qué hacer. Aquí se traduce a **una instrucción**: casi siempre la
/// cuenta ya quedó confirmada y basta con iniciar sesión (ver AH — el enlace
/// llega gastado porque el escáner del buzón lo visita antes que la persona).
///
/// Es un modelo puro a propósito: no toca pantallas ni Supabase, así que se
/// puede probar sin navegador.
class AvisoDeEnlaceDeCorreo {
  const AvisoDeEnlaceDeCorreo({required this.titulo, required this.queHacer});

  /// Qué pasó, en una línea y sin jerga.
  final String titulo;

  /// Qué tiene que hacer la persona ahora. **Nunca vacío:** un aviso que no
  /// dice qué hacer deja a alguien igual de perdido que el silencio de antes.
  final String queHacer;

  /// Lee la dirección con la que arrancó la aplicación y devuelve el aviso, o
  /// `null` si no hubo ningún error — que es el caso normal.
  ///
  /// Se le pasa la dirección en vez de leer `Uri.base` dentro para poder
  /// probarla: la regla de D-245 es que una prueba **ejecute** el
  /// comportamiento, y `Uri.base` no se puede simular.
  static AvisoDeEnlaceDeCorreo? desdeLaDireccion(Uri direccion) {
    final parametros = <String, String>{
      ...direccion.queryParameters,
      // Supabase manda el error en la parte de atras (`#`) en algunos flujos y
      // en la consulta (`?`) en otros. Mirar solo uno de los dos deja la mitad
      // de los casos sin aviso, que es justo el fallo que esto viene a cerrar.
      ..._parametrosDelFragmento(direccion.fragment),
    };

    final codigo = parametros['error_code']?.trim();
    final descripcion = parametros['error_description']?.trim();
    final error = parametros['error']?.trim();

    if ((codigo == null || codigo.isEmpty) &&
        (descripcion == null || descripcion.isEmpty) &&
        (error == null || error.isEmpty)) {
      return null;
    }

    switch (codigo) {
      // El caso de AH, y el más frecuente con diferencia.
      case 'otp_expired':
        return const AvisoDeEnlaceDeCorreo(
          titulo: 'Ese enlace del correo ya no servía.',
          queHacer:
              'Casi siempre tu cuenta quedó confirmada de todos modos: '
              'entra aquí con tu correo y tu contraseña. Si no te deja, '
              'vuelve a registrarte con el mismo correo.',
        );
      case 'access_denied':
        return const AvisoDeEnlaceDeCorreo(
          titulo: 'No pudimos abrir ese enlace del correo.',
          queHacer:
              'Entra con tu correo y tu contraseña. Si no te deja, pide que '
              'te envíen la invitación otra vez.',
        );
      default:
        // Un código que no conocemos **no se traga en silencio**: se avisa
        // igual, aunque sea con palabras generales. El silencio es el fallo.
        return const AvisoDeEnlaceDeCorreo(
          titulo: 'El enlace del correo no funcionó.',
          queHacer:
              'Intenta entrar con tu correo y tu contraseña. Si el problema '
              'sigue, escríbenos a hola@salonymas.com.',
        );
    }
  }

  static Map<String, String> _parametrosDelFragmento(String fragmento) {
    if (fragmento.isEmpty || !fragmento.contains('=')) return const {};
    try {
      return Uri.splitQueryString(fragmento);
    } catch (_) {
      // Un fragmento que no es una lista de parámetros (por ejemplo una ruta)
      // no es un error: simplemente no trae nada que leer.
      return const {};
    }
  }
}
