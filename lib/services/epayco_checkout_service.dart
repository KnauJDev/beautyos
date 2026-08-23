import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tenant_subscription_status.dart';
import '../theme/app_colors.dart';
import 'epayco_modal_launcher.dart';
import 'monitoreo_service.dart';

/// Servicio para orquestar el inicio del Smart Checkout V2 seguro de ePayco (D-141 / D-158).
///
/// **Regla de seguridad fundamental (AGENTS.md):**
/// En Flutter solo se manejan credenciales públicas y sesiones creadas por el servidor.
/// Las llaves privadas (PRIVATE_KEY / P_KEY) residen exclusivamente en las Edge Functions
/// de Supabase (`create-epayco-session` y `epayco-webhook`).
class EpaycoCheckoutService {
  const EpaycoCheckoutService();

  // ID público de comercio ePayco (configurable por variables de entorno)
  static const String defaultCustId = String.fromEnvironment(
    'EPAYCO_PUBLIC_CUST_ID',
    defaultValue: '1588792',
  );

  // Llave pública de ePayco para checkout (NUNCA la llave privada P_KEY)
  static const String defaultPublicKey = String.fromEnvironment(
    'EPAYCO_PUBLIC_KEY',
    defaultValue: 'a20a90e36c84335c754a73fba80a0978',
  );

  // Modo de prueba de ePayco (activo mientras la cuenta de ePayco esté en Explorar/Pruebas)
  static const bool defaultTestMode = bool.fromEnvironment(
    'EPAYCO_TEST_MODE',
    defaultValue: true,
  );

  // URL del webhook de confirmación en Supabase Edge Functions
  static const String confirmationWebhookUrl =
      'https://eogppgbdnwxdtcbctaol.supabase.co/functions/v1/epayco-webhook';

  /// Construye la URL parametrizada para ePayco (compatibilidad y pruebas).
  Uri buildCheckoutUri(
    TenantSubscriptionStatus subscription, {
    String? selectedPlanCode,
    String? selectedPlanName,
    int? customAmount,
    bool? isTest,
  }) {
    final amount = customAmount ?? subscription.priceCop;
    if (amount == null || amount <= 0) {
      throw ArgumentError(
        'No se puede construir el Checkout de ePayco: el precio efectivo de la suscripción es nulo o inválido.',
      );
    }

    final planName = selectedPlanName ?? subscription.planName ?? 'Profesional';
    final planCode = selectedPlanCode ?? subscription.planCode ?? 'profesional';
    final tenantName = subscription.tenantName;
    final testFlag = isTest ?? defaultTestMode;

    final queryParams = {
      'p_cust_id_cliente': defaultCustId,
      'p_key': defaultPublicKey,
      'x_amount': amount.toString(),
      'x_tax': '0',
      'x_amount_base': amount.toString(),
      'x_currency_code': 'COP',
      'x_country': 'CO',
      'x_description': 'Suscripcion Salon y Mas - $planName - $tenantName',
      'x_extra1': subscription.tenantId,
      'x_extra2': planCode,
      'x_extra3': 'beautyos_app',
      'x_test_request': testFlag ? 'true' : 'false',
      'x_confirmation_url': confirmationWebhookUrl,
    };

    return Uri.https('checkout.epayco.co', '/checkout.php', queryParams);
  }

  static String _formatCOP(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final pos = digits.length - i;
      buffer.write(digits[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write('.');
      }
    }
    return '\$$buffer COP';
  }

  /// Muestra el selector interactivo de planes con cálculo de descuento Pionero
  /// y abre el Smart Checkout V2 de ePayco mediante sesión segura generada en backend.
  Future<void> iniciarPago(
    BuildContext context,
    TenantSubscriptionStatus subscription, {
    VoidCallback? onPaymentLaunched,
  }) async {
    String chosenPlanCode = subscription.planCode ?? 'profesional';
    if (chosenPlanCode.isEmpty) chosenPlanCode = 'profesional';

    int calculatePlanPrice(String planCode) {
      if (subscription.priceCop != null &&
          subscription.priceCop! > 0 &&
          planCode == subscription.planCode) {
        return subscription.priceCop!;
      }

      int base = 240000;
      if (planCode == 'basico') base = 160000;
      if (planCode == 'business') base = 200000;

      if (subscription.isFounder) {
        return (base * 0.5).round();
      }
      if (subscription.discountPercent != null && subscription.discountPercent! > 0) {
        return (base * (1.0 - (subscription.discountPercent! / 100.0))).round();
      }
      return base;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentPrice = calculatePlanPrice(chosenPlanCode);
          final priceText = '${_formatCOP(currentPrice)}/mes';

          String chosenPlanName = 'Profesional';
          if (chosenPlanCode == 'basico') chosenPlanName = 'Básico';
          if (chosenPlanCode == 'business') chosenPlanName = 'Business';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.payment_outlined, color: AppColors.brand),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Activar / Renovar Plan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elige el plan que mejor se adapte a tu salón:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    // Selector de Plan
                    DropdownButtonFormField<String>(
                      initialValue: chosenPlanCode,
                      decoration: const InputDecoration(
                        labelText: 'Plan a contratar',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'basico',
                          child: Text('Básico (1 sede, hasta 5 cuentas)'),
                        ),
                        DropdownMenuItem(
                          value: 'business',
                          child: Text('Business (Hasta 3 sedes, 15 cuentas)'),
                        ),
                        DropdownMenuItem(
                          value: 'profesional',
                          child: Text('Profesional (Ilimitado + IA & Marketing)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => chosenPlanCode = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tarjeta de Valor a Pagar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan: $chosenPlanName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Valor a pagar: $priceText',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (subscription.isFounder) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.brandTint,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '★ 50% DESCUENTO PIONERO APLICADO',
                                style: TextStyle(
                                  color: AppColors.brandDeep,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Medios: PSE, Nequi, Daviplata y Tarjetas.',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.flash_on_outlined, color: AppColors.brand, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Activación automática e inmediata tras pagar.',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.of(dialogContext).pop({
                  'planCode': chosenPlanCode,
                  'planName': chosenPlanName,
                  'amount': currentPrice,
                }),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Continuar a ePayco'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    final finalPlanCode = result['planCode'] as String;
    final finalAmount = result['amount'] as int;

    // Mostrar diálogo de carga mientras el backend genera la sesión segura
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Conectando con ePayco Smart Checkout...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final currentSession = Supabase.instance.client.auth.currentSession;
      final headers = <String, String>{};
      if (currentSession?.accessToken != null) {
        headers['Authorization'] = 'Bearer ${currentSession!.accessToken}';
      }

      // 1. Invocar Edge Function para crear sesión de pago en ePayco Apify
      final sessionResponse = await Supabase.instance.client.functions.invoke(
        'create-epayco-session',
        headers: headers,
        body: {
          'tenantId': subscription.tenantId,
          'planCode': finalPlanCode,
          'amount': finalAmount,
        },
      );

      // Cerrar modal de carga
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (sessionResponse.status != 200 || sessionResponse.data == null) {
        final errorMsg = sessionResponse.data?['error'] ?? 'Error desconocido al crear sesión de pago.';
        throw Exception(errorMsg);
      }

      final sessionId = sessionResponse.data['sessionId'] as String?;
      final testMode = sessionResponse.data['testMode'] as bool? ?? defaultTestMode;

      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('ePayco no retornó un identificador de sesión válido.');
      }

      // 2. Abrir Smart Checkout V2 oficial en el frontend
      final launched = await lanzarEpaycoSmartCheckout(
        sessionId: sessionId,
        testMode: testMode,
      );

      if (launched) {
        onPaymentLaunched?.call();
      } else {
        throw Exception('No se pudo abrir el componente de ePayco.');
      }
    } catch (e, st) {
      // Cerrar modal de carga si sigue abierto
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }

      MonitoreoService.reportarError(
        e,
        st,
        motivo: 'Fallo al inicializar Smart Checkout ePayco para tenant ${subscription.tenantId}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la pasarela de ePayco: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
