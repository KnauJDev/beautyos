import 'dart:js_interop';

@JS('openEpaycoSmartCheckout')
external void _openEpaycoSmartCheckout(JSObject data);

Future<bool> lanzarEpaycoSmartCheckout({
  required String sessionId,
  required bool testMode,
}) async {
  final payload = {
    'sessionId': sessionId,
    'testMode': testMode,
  }.jsify();

  _openEpaycoSmartCheckout(payload as JSObject);
  return true;
}
