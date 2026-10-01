/// CB (D-300): una cifra de dinero leída como la escribe una persona en
/// Colombia.
///
/// **El fallo que cierra.** Los tres campos de dinero del Panel de plataforma
/// leían con `int.tryParse` o `double.tryParse`, que no entienden el punto de
/// miles, y ninguno avisaba:
///
/// - **El precio de una sede:** *"15.000"* daba vacío, y en esa ventana vacío
///   significa "volver a la tarifa vigente" (D-237). El acuerdo se borraba.
/// - **El precio especial al aprobar un negocio:** *"75.000"* daba vacío y el
///   negocio se aprobaba a la tarifa del plan.
/// - **La comisión fija de un aliado:** `double.tryParse("15.000")` sí lee algo,
///   quince con tres decimales, así que se guardaban **$15**. Y lo que no era un
///   número se convertía en 15 sin decir nada.
///
/// **Lo que cambia:** se distingue *vacío* de *ilegible*, que era justo lo que
/// se confundía. Lo ilegible no se guarda: la ventana lo dice y espera.
class CifraEscrita {
  const CifraEscrita._(this.valor, {required this.esLegible});

  /// La cifra, o `null` si el campo estaba vacío o no se pudo leer.
  final num? valor;

  /// `false` si se escribió algo que no es una cifra válida.
  final bool esLegible;

  /// El campo estaba vacío (o solo con espacios). No es un error: en la
  /// ventana de la sede, por ejemplo, significa "a tarifa vigente".
  bool get estaVacia => esLegible && valor == null;

  static const _vacia = CifraEscrita._(null, esLegible: true);
  static const _ilegible = CifraEscrita._(null, esLegible: false);

  /// Pesos enteros: `75000`, `75.000`, `$75.000`, `$ 75.000`, `75 000` o
  /// `75,000`. El separador de miles va cada tres cifras y es siempre el mismo;
  /// con centavos (`75000,50`) no se lee, porque en pesos no se pactan.
  ///
  /// **Centavos en cero sí** (`75000.0`, `75000.00`, `75.000,00`), y no por
  /// cortesía (CC, D-302): varias casillas se precargan con `valor.toString()`,
  /// y fuera del navegador un número decimal se escribe `35000.0`. Rechazarlo
  /// dejaría sin poder guardar una edición en la que nadie tocó el precio.
  /// Dos ceros como mucho, así que `75.000` sigue siendo setenta y cinco mil.
  static CifraEscrita pesos(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return _vacia;
    final partes = _pesos.firstMatch(limpio);
    if (partes == null) return _ilegible;
    final digitos = partes.group(1)!.replaceAll(RegExp(r'\D'), '');
    // Doce cifras son cien mil millones: más que eso no es un precio, es un
    // dedo apoyado en el teclado.
    if (digitos.length > 12) return _ilegible;
    return CifraEscrita._(int.parse(digitos), esLegible: true);
  }

  /// Un porcentaje: `15`, `12,5`, `12.5` o `15%`. Hasta dos decimales, con
  /// coma o punto. `15.000` no se lee: como porcentaje no tiene sentido y casi
  /// seguro era un valor en pesos escrito en el campo equivocado.
  static CifraEscrita porcentaje(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return _vacia;
    final partes = _porcentaje.firstMatch(limpio);
    if (partes == null) return _ilegible;
    return CifraEscrita._(
      double.parse(partes.group(1)!.replaceAll(',', '.')),
      esLegible: true,
    );
  }

  static final _pesos = RegExp(
    r'^\$?\s*(\d+|\d{1,3}([.,\s])\d{3}(?:\2\d{3})*)(?:[.,]0{1,2})?$',
  );
  static final _porcentaje = RegExp(r'^(\d{1,3}(?:[.,]\d{1,2})?)\s*%?$');
}
