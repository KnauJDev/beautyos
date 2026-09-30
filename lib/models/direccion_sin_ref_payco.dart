/// CA (D-298): la dirección de la página sin `ref_payco`.
///
/// ePayco devuelve a `salonymas.com/?ref_payco=...`. La app lo lee una vez para
/// preguntar en qué quedó el pago (D-200), pero la dirección se quedaba así:
/// cada recarga volvía a preguntar y a enseñar el aviso, y el 24-sep una pestaña
/// que venía de un pago viejo le mostró "estamos validando tu pago" a un negocio
/// recién registrado.
///
/// Devuelve `null` si no hay nada que quitar. Conserva todo lo demás (otros
/// parámetros, el puerto, el fragmento), porque la app también lee la dirección
/// para otras cosas.
String? direccionSinRefPayco(Uri actual) {
  if (!actual.queryParameters.containsKey('ref_payco')) return null;

  final resto = Map<String, String>.of(actual.queryParameters)
    ..remove('ref_payco');

  return Uri(
    scheme: actual.scheme,
    host: actual.host,
    port: actual.hasPort ? actual.port : null,
    path: actual.path,
    queryParameters: resto.isEmpty ? null : resto,
    fragment: actual.hasFragment ? actual.fragment : null,
  ).toString();
}
