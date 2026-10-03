/// El enlace de reserva en línea de UNA sede: `salonymas.com/?reservar=<sede>`.
///
/// Lo abre `main.dart` sin sesión (D-005) y lleva directo a la reserva de esa
/// sede. Vive aquí, en un solo sitio, porque desde el 23-sep lo usan dos
/// pantallas: la tarjeta del dueño en Configuración y la del estilista en
/// *Mi agenda* (D-267). Dos copias del mismo enlace son dos enlaces el día que
/// cambie uno.
///
/// [origen] solo lo pasan las pruebas: fuera del navegador `Uri.base` no tiene
/// origen web.
String enlaceDeReservaDeSede(String branchId, {String? origen}) =>
    '${origen ?? Uri.base.origin}/?reservar=$branchId';

/// El enlace que se comparte para reservar, **la regla para todos** (D-313,
/// 03-oct): la página del salón, `salonymas.com/<nombre-del-salon>`, que
/// lleva el nombre a la vista y enseña sus servicios, su equipo y sus
/// reseñas antes de agendar. La usan la tarjeta de la estilista y la de
/// *Reserva pública* en Configuración. El propietario: *"a todos les
/// gustaría no ver esa correa de números… y sería regla, no nos
/// desgastaríamos cambiando a cada uno después"*.
///
/// **Solo para la sede principal.** La página del salón agenda siempre en la
/// sede principal (`primary_branch_id`), así que a otra sede se le deja el
/// enlace directo de la suya: si no, sus clientas reservarían en la sede
/// equivocada. Y si no se conoce la dirección del salón, también el de
/// siempre. Darle dirección con nombre a cada sede (`<salon>/<sede>`) queda
/// pendiente: necesita el servidor.
String enlaceParaCompartir({
  required String branchId,
  required bool esSedePrincipal,
  String? slugDelSalon,
  String? origen,
}) {
  final slug = slugDelSalon?.trim() ?? '';
  if (esSedePrincipal && slug.isNotEmpty) {
    return '${origen ?? Uri.base.origin}/$slug';
  }
  return enlaceDeReservaDeSede(branchId, origen: origen);
}
