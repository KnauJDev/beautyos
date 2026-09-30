/// Cambia la dirección que muestra el navegador sin recargar la página (CA, D-298).
///
/// En Web usa `history.replaceState` mediante `dart:js_interop`. Fuera del
/// navegador no hay barra de direcciones que limpiar y no hace nada.
library;

export 'limpiar_direccion_stub.dart'
    if (dart.library.js_interop) 'limpiar_direccion_web.dart';
