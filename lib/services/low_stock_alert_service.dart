import 'package:supabase_flutter/supabase_flutter.dart';
import 'sesion_supabase.dart';

/// Dispara la alarma de stock por correo (punto 8 del benchmarking) tras
/// registrar un consumo interno. La Edge Function `send-low-stock-alert`
/// decide si realmente hay que enviar algo (RPC security definer
/// `get_low_stock_alert_context`); esta llamada es "mejor esfuerzo": si
/// falla, no interrumpe el flujo de registrar el consumo.
class LowStockAlertService {
  const LowStockAlertService();

  Future<void> maybeSendAlert({
    required String branchId,
    required String productId,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-low-stock-alert',
        // Token fresco (D-207). Aqui el 401 era **invisible**: el `catch` de
        // abajo se lo tragaba por diseno, asi que la alerta de stock bajo
        // simplemente no salia y no habia forma de notarlo.
        headers: await cabecerasParaEdgeFunction(),
        body: {'branch_id': branchId, 'product_id': productId},
      );
    } catch (_) {
      // Mejor esfuerzo: el consumo ya quedo registrado, no se avisa al
      // usuario si el correo de alarma falla.
    }
  }
}
