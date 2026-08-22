import 'dart:js_interop';

@JS('openEpaycoCheckout')
external void _openEpaycoCheckout(JSObject data);

Future<bool> lanzarEpaycoModal({
  required String publicKey,
  required bool testMode,
  required String name,
  required String description,
  required String invoice,
  required int amount,
  required String extra1,
  required String extra2,
  required String extra3,
  required String confirmationUrl,
  required String responseUrl,
  String? nameBilling,
  String? emailBilling,
  String? phoneBilling,
}) async {
  final payload = {
    'publicKey': publicKey,
    'testMode': testMode,
    'name': name,
    'description': description,
    'invoice': invoice,
    'amount': amount.toString(),
    'extra1': extra1,
    'extra2': extra2,
    'extra3': extra3,
    'confirmation': confirmationUrl,
    'response': responseUrl,
    'nameBilling': nameBilling ?? '',
    'emailBilling': emailBilling ?? '',
    'phoneBilling': phoneBilling ?? '',
  }.jsify();

  _openEpaycoCheckout(payload as JSObject);
  return true;
}
