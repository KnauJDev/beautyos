import 'dart:js_interop';

@JS('location')
external _Location get _location;

extension type _Location(JSObject _) implements JSObject {
  external void reload();
}

/// Pide al navegador que vuelva a cargar todo desde el servidor.
///
/// Es lo unico que reemplaza de verdad el codigo ya descargado. Navegar dentro
/// de la aplicacion no sirve: seguiria ejecutandose la misma copia vieja.
void recargarPagina() => _location.reload();
