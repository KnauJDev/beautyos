/// Precios "desde", por categoría (D-326).
///
/// El salón marca una categoría en Servicios y todos sus precios dicen
/// "Desde $…": un balayage no cuesta lo mismo en un cabello corto que en uno
/// largo. Las categorías son texto libre en cada servicio; se comparan sin
/// mirar mayúsculas ni espacios a los lados, como los cuadritos de D-322.
///
/// El total de una cita, el saldo y "Cobrar $…" NO llevan "Desde": no se
/// cobra "desde".
class PreciosDesde {
  const PreciosDesde(this.categorias);

  /// Ninguna categoría marcada: los precios se ven como siempre.
  static const ninguno = PreciosDesde(<String>{});

  /// Las categorías marcadas, ya como [clave].
  final Set<String> categorias;

  factory PreciosDesde.desdeLista(Iterable<Object?> lista) =>
      PreciosDesde({for (final c in lista) clave(c?.toString())}..remove(''));

  static String clave(String? categoria) =>
      (categoria ?? '').trim().toLowerCase();

  bool aplica(String? categoria) => categorias.contains(clave(categoria));

  /// "$400.000" → "Desde $400.000" si su categoría está marcada.
  String precio(String precio, String? categoria) =>
      aplica(categoria) ? 'Desde $precio' : precio;
}
