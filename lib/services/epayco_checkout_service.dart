import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sesion_supabase.dart';

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

  // Modo de prueba de ePayco (false = Modo Producción con dinero real)
  static const bool defaultTestMode = bool.fromEnvironment(
    'EPAYCO_TEST_MODE',
    defaultValue: false,
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

    // D-193: el plan por defecto es el unico que queda. 'profesional' se
    // retiro con D-188 y seguia aqui de respaldo, ofreciendo un plan que ya
    // no existe.
    final planName = selectedPlanName ?? subscription.planName ?? 'Todo Incluido';
    final planCode = selectedPlanCode ?? subscription.planCode ?? 'pro';
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


  /// Muestra el selector interactivo de planes con cálculo de descuento Pionero
  /// y abre el Smart Checkout V2 de ePayco mediante sesión segura generada en backend.
  /// Abre el checkout de ePayco para la suscripción del negocio o para UNA sede.
  ///
  /// **Qué se quitó de aquí, y por qué importa (D-193).** Hasta hoy esta
  /// función abría un desplegable con los tres planes —Básico, Business,
  /// Profesional— y calculaba el precio en el cliente con las cifras escritas a
  /// mano: 160.000, 200.000 y 240.000.
  ///
  /// D-188 retiró esos tres planes el 01-sep y **esto se quedó como estaba**. El
  /// cobro salía bien, porque el monto lo calcula el servidor y un plan
  /// retirado cae al plan real (D-159, D-160), pero **al dueño se le enseñaba un
  /// precio que no era el suyo** y se le ofrecían planes que ya no existen.
  ///
  /// **Y por eso ahora no se muestra ninguna cifra calculada aquí.** El monto
  /// depende del ciclo —mes completo, renovación anticipada, o el prorrateo de
  /// una sede que se activa a mitad de mes (D-191)— y esa cuenta vive en el
  /// servidor, en un solo sitio. Repetirla en el cliente es cómo nació este
  /// problema. El importe exacto lo enseña ePayco antes de cobrar.
  Future<void> iniciarPago(
    BuildContext context,
    TenantSubscriptionStatus subscription, {
    VoidCallback? onPaymentLaunched,

    /// Si viene, se paga ESA sede con su prorrateo (D-191, D-192). Si no, es la
    /// suscripción del negocio, como siempre.
    String? branchId,
    String? branchName,
  }) async {
    final esSede = branchId != null && branchId.isNotEmpty;

    final confirmado = await showDialog<bool>(
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
            Expanded(
              child: Text(
                esSede ? 'Activar esta sede' : 'Activar o renovar tu plan',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esSede
                  ? 'Vas a pagar la sede "${branchName ?? 'seleccionada'}" del '
                        'plan Todo Incluido.'
                  : 'Vas a pagar tu plan Todo Incluido.',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandTintSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.brandDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      esSede
                          ? 'Si tu negocio ya tiene una fecha de corte, esta '
                                'sede se cobra solo hasta ese día y desde el '
                                'siguiente mes va completa. El importe exacto lo '
                                'verás en ePayco antes de pagar.'
                          : 'El importe exacto lo verás en ePayco antes de '
                                'pagar, calculado según tu fecha de corte.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('Continuar a ePayco'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

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
      // 1. Invocar Edge Function para crear sesión de pago en ePayco Apify.
      // El tenantId y el monto a cobrar los calcula el servidor a partir de la
      // sesión autenticada y del precio pactado: nunca se envían desde el
      // cliente, para que no puedan manipularse.
      FunctionResponse sessionResponse;
      try {
        sessionResponse = await Supabase.instance.client.functions.invoke(
          'create-epayco-session',
          headers: await cabecerasParaEdgeFunction(),
          body: {
            'planCode': 'pro',
            if (esSede) 'branchId': branchId,
          },
        );
      } on FunctionException catch (fe) {
        if (fe.status == 401) {
          // Si el token caducó en el servidor, forzar refresco y reintentar una vez
          await forzarRefresco();
          sessionResponse = await Supabase.instance.client.functions.invoke(
            'create-epayco-session',
            headers: await cabecerasParaEdgeFunction(),
            body: {
              'planCode': 'pro',
              if (esSede) 'branchId': branchId,
            },
          );
        } else {
          rethrow;
        }
      }

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
        motivo: esSede
            ? 'Fallo al inicializar Smart Checkout ePayco para la sede \$branchId'
            : 'Fallo al inicializar Smart Checkout ePayco para tenant \${subscription.tenantId}',
      );
      if (context.mounted) {
        String mensajeUsuario;
        final errorStr = e.toString();
        if (e is FunctionException && e.status == 401) {
          mensajeUsuario =
              'Tu sesión ha expirado. Por favor inicia sesión de nuevo para continuar con el pago.';
        } else if (errorStr.contains('401') ||
            errorStr.contains('sesión') ||
            errorStr.contains('session')) {
          mensajeUsuario =
              'Tu sesión ha expirado o no es válida. Por favor inicia sesión de nuevo.';
        } else {
          mensajeUsuario =
              'No se pudo abrir la pasarela de ePayco: ${errorStr.replaceAll('Exception: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeUsuario),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
