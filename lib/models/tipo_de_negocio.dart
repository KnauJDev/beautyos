/// Los tipos de negocio que ofrece el registro, en un solo sitio (BV).
///
/// La base guarda el código (`salon`, `unas`...) y el registro lo traduce al
/// elegirlo. La página pública lo pintaba tal cual y decía «salon». Una sola
/// lista, no una copia: la lección de D-198.
const List<Map<String, String>> tiposDeNegocio = [
  {'value': 'salon', 'label': 'Peluquería / Salón de Belleza'},
  {'value': 'unas', 'label': 'Spa de Uñas (Nail Spa)'},
  {'value': 'barberia', 'label': 'Barbería'},
  {'value': 'spa', 'label': 'Centro de Estética / Spa'},
  {'value': 'canina', 'label': 'Peluquería / Estética Canina'},
  {'value': 'otro', 'label': 'Otro centro de cuidado personal'},
];

/// Traduce el código al texto que se le enseña a la gente.
///
/// Configuración y el Panel de plataforma dejan escribir el tipo a mano, así
/// que también llega texto libre («Peluquería canina», por ejemplo): si no es
/// un código conocido, se respeta tal como lo escribió quien lo puso.
String etiquetaDelTipoDeNegocio(String tipo) {
  final limpio = tipo.trim();
  final buscado = limpio.toLowerCase();

  for (final opcion in tiposDeNegocio) {
    if (opcion['value'] == buscado) {
      return opcion['label']!;
    }
  }

  return limpio;
}
