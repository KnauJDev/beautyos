import 'package:url_launcher/url_launcher.dart';

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
  // En plataformas nativas (Windows/Android), se abre como URL externa
  final queryParams = {
    'p_key': publicKey,
    'x_amount': amount.toString(),
    'x_currency_code': 'COP',
    'x_country': 'CO',
    'x_description': description,
    'x_extra1': extra1,
    'x_extra2': extra2,
    'x_extra3': extra3,
    'x_test_request': testMode ? 'true' : 'false',
    'x_confirmation_url': confirmationUrl,
    'x_response_url': responseUrl,
  };
  final uri = Uri.https('secure.payco.co', '/checkout.php', queryParams);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
