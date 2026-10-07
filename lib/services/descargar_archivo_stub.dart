import 'dart:typed_data';

/// Ver `descargar_archivo.dart`. Fuera del navegador no hay a dónde descargar.
Future<void> descargarArchivo(
  Uint8List bytes, {
  required String nombre,
  required String tipo,
}) async {
  throw UnsupportedError('Descargar un archivo solo funciona en el navegador.');
}
