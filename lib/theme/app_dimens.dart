/// Escalas de espaciado y esquinas (D-097).
///
/// Una sola escala, en multiplos de 4. El descuadre que se ve hoy entre
/// pantallas viene de que cada una eligio sus propios margenes: 10 aqui, 14
/// alla, 18 mas alla. Con estos nombres eso deja de poder pasar.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Esquinas. Compactas con caracter: ni cuadradas ni de burbuja (D-097).
class AppRadius {
  AppRadius._();

  /// Tarjetas y dialogos.
  static const card = 14.0;

  /// Botones y campos de formulario.
  static const control = 10.0;

  /// Pildoras de estado. Un numero grande para que siempre sea semicircular
  /// sin importar la altura del texto.
  static const pill = 999.0;

  /// Barra de color a la izquierda de cada tarjeta: muestra la marca del
  /// negocio y el estado a la vez, sin gastar altura (D-097).
  static const accentBarWidth = 5.0;
}
