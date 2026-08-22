/// Abre el modal interactivo de ePayco en la plataforma correspondiente.
///
/// En Web utiliza `dart:js_interop` para invocar el SDK `checkout.js` embebido.
/// En plataformas móviles/escritorio utiliza `url_launcher`.
library;

export 'epayco_modal_launcher_stub.dart'
    if (dart.library.js_interop) 'epayco_modal_launcher_web.dart';
