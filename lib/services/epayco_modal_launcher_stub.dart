import 'package:url_launcher/url_launcher.dart';

Future<bool> lanzarEpaycoSmartCheckout({
  required String sessionId,
  required bool testMode,
}) async {
  final uri = Uri.parse('https://checkout.epayco.co/checkout?sessionId=$sessionId');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
