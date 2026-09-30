import 'dart:js_interop';

extension type _Historial._(JSObject _) implements JSObject {
  external JSAny? get state;
  external void replaceState(JSAny? data, JSString unused, JSString url);
}

@JS('history')
external _Historial get _historial;

void reemplazarDireccionSinRecargar(String direccion) {
  // Se conserva el `state`: Flutter guarda ahí su control del historial, y
  // pisarlo con otra cosa rompe el botón de atrás.
  _historial.replaceState(_historial.state, ''.toJS, direccion.toJS);
}
