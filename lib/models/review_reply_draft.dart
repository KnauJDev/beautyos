/// Borrador determinista de respuesta a una reseña (paso 6.3, D-170): una
/// plantilla por franja de calificación, sin IA externa, que el salón edita
/// antes de guardar. Lógica pura y separada del widget, mismo criterio de
/// testabilidad que [NarrativaNegocioBuilder] (D-168) y [PeriodoDashboard]
/// (D-110): nada aquí depende de un `BuildContext` ni del reloj.
class ReviewReplyDraftBuilder {
  const ReviewReplyDraftBuilder._();

  static String generar({
    required int rating,
    required String clientName,
    required String serviceName,
    required String businessName,
  }) {
    final nombre = _primerNombre(clientName);
    final saludo = nombre == null ? '' : ', $nombre';
    final servicio = _servicioLegible(serviceName);

    if (rating >= 5) {
      return '¡Muchas gracias$saludo! Nos alegra muchísimo que hayas '
          'quedado feliz con $servicio. Te esperamos pronto en '
          '$businessName. 💜';
    }

    if (rating == 4) {
      return '¡Gracias por tu comentario$saludo! Nos alegra que hayas '
          'disfrutado $servicio. Cuéntanos qué podemos mejorar para que la '
          'próxima vez sea perfecta -- te esperamos en $businessName.';
    }

    if (rating == 3) {
      return 'Gracias por contarnos tu experiencia$saludo. Nos gustaría '
          'mejorar $servicio la próxima vez -- escríbenos cuando quieras. '
          'Un abrazo de parte de $businessName.';
    }

    return 'Lamentamos mucho que tu experiencia con $servicio no haya sido '
        'la que esperabas$saludo. Tu opinión nos importa: escríbenos para '
        'poder ayudarte y hacerlo bien la próxima vez. -- $businessName';
  }

  /// `null` cuando no hay un nombre real que saludar (cliente eliminado o
  /// nunca asociado) -- mejor omitir el saludo que insertar un genérico
  /// como "Cliente" a mitad de una frase.
  static String? _primerNombre(String nombreCompleto) {
    final limpio = nombreCompleto.trim();
    if (limpio.isEmpty || limpio == 'Cliente no asociado') return null;
    return limpio.split(RegExp(r'\s+')).first;
  }

  static String _servicioLegible(String serviceName) {
    final limpio = serviceName.trim();
    if (limpio.isEmpty || limpio == 'Servicio no asociado') {
      return 'el servicio';
    }
    return limpio;
  }
}
