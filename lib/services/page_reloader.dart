/// Recarga la pagina del navegador.
///
/// Se resuelve por importacion condicional porque `dart:js_interop` solo
/// existe en web, y el proyecto todavia compila para Android y Windows. En
/// esas plataformas no hay nada que recargar y la llamada no hace nada.
library;

export 'page_reloader_stub.dart'
    if (dart.library.js_interop) 'page_reloader_web.dart';
