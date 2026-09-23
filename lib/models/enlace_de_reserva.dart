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
