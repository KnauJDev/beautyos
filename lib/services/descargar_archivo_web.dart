import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Ver `descargar_archivo.dart`: un enlace con `download` sobre un `Blob`.
Future<void> descargarArchivo(
  Uint8List bytes, {
  required String nombre,
  required String tipo,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: tipo),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre;
  enlace.style.display = 'none';
  web.document.body!.appendChild(enlace);
  enlace.click();
  enlace.remove();
  // Se suelta un momento después: soltarlo en el acto puede cortar la
  // descarga en algunos navegadores.
  await Future<void>.delayed(const Duration(seconds: 2));
  web.URL.revokeObjectURL(url);
}
