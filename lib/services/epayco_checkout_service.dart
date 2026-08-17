import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tenant_subscription_status.dart';
import '../theme/app_colors.dart';
import 'monitoreo_service.dart';

/// Servicio para orquestar el inicio del Checkout seguro de ePayco (D-141).
///
/// **Regla de seguridad fundamental (AGENTS.md):**
/// En Flutter solo se manejan credenciales públicas o enlaces parametrizados.
/// Las llaves privadas (P_KEY) y la validación criptográfica SHA-256 residen
/// exclusivamente en la Edge Function `epayco-webhook` de Supabase.
class EpaycoCheckoutService {
  const EpaycoCheckoutService();

  // ID público de comercio ePayco por defecto (configurable por variables de entorno)
  static const String defaultCustId = '1302824';
  static const String defaultPublicKey = '248dfeb1765c82eb5c21f2bb406cf658';

  // URL del webhook de confirmación en Supabase Edge Functions
  static const String confirmationWebhookUrl =
      'https://eogppgbdnwxdtcbctaol.supabase.co/functions/v1/epayco-webhook';

  /// Construye la URL del Checkout hospedado o estándar de ePayco.
  Uri buildCheckoutUri(TenantSubscriptionStatus subscription, {bool isTest = true}) {
    final amount = subscription.priceCop ?? 240000;
    final planName = subscription.planName ?? 'Profesional';
    final tenantName = subscription.tenantName;

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
      'x_extra2': subscription.planCode ?? 'profesional',
      'x_extra3': 'beautyos_app',
      'x_test_request': isTest ? 'true' : 'false',
      'x_confirmation_url': confirmationWebhookUrl,
    };

    // Usamos el portal estándar de checkout de ePayco
    return Uri.https('checkout.epayco.co', '/checkout.php', queryParams);
  }

  /// Muestra un diálogo explicativo y abre el Checkout de ePayco para el usuario.
  Future<void> iniciarPago(
    BuildContext context,
    TenantSubscriptionStatus subscription, {
    VoidCallback? onPaymentLaunched,
  }) async {
    final amountText = subscription.formattedPrice;
    final planName = subscription.planName ?? 'Profesional';

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                'Pago de Suscripción',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás a punto de renovar tu suscripción a Salón y Más:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
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
                    'Plan: $planName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Valor: $amountText',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (subscription.isFounder) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningTint,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '★ 50% DESCUENTO PIONERO APLICADO',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
                    'Medios disponibles: PSE, Nequi, Daviplata y Tarjetas.',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.flash_on_outlined, color: AppColors.brand, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reactivación automática e inmediata tras confirmar.',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('Continuar a ePayco'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    final uri = buildCheckoutUri(subscription);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        onPaymentLaunched?.call();
      } else {
        throw Exception('No se pudo abrir el navegador para ePayco.');
      }
    } catch (e, st) {
      MonitoreoService.reportarError(
        e,
        st,
        motivo: 'Fallo al abrir Checkout de ePayco para tenant ${subscription.tenantId}',
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
