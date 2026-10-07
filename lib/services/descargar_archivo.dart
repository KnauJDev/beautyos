import 'dart:typed_data';

import 'descargar_archivo_stub.dart'
    if (dart.library.js_interop) 'descargar_archivo_web.dart'
    as impl;

/// Descarga [bytes] como un archivo llamado [nombre] (D-319, el código QR
/// del enlace del salón).
///
/// En el navegador es una descarga de verdad: un enlace con `download` sobre
/// un `Blob`. No se abre una pestaña con un `data:` como hace el Estudio de
/// publicación, porque Chrome bloquea abrir esas direcciones en una pestaña
/// nueva y la deja en blanco.
///
/// Fuera del navegador (las pruebas) no hay a dónde descargar: lanza
/// [UnsupportedError].
Future<void> descargarArchivo(
  Uint8List bytes, {
  required String nombre,
  required String tipo,
}) => impl.descargarArchivo(bytes, nombre: nombre, tipo: tipo);
