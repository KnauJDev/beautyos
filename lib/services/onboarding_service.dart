import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_progress.dart';

/// Los "Primeros pasos" del salón nuevo (paso 8.8, D-186).
class OnboardingService {
  const OnboardingService();

  /// Qué lleva hecho el salón en esta sede.
  ///
  /// **Nunca lanza.** La RPC revienta a propósito para quien no es owner ni
  /// admin, y eso no es un error que haya que mostrar: es que la pregunta no
  /// aplica. En ese caso, y ante cualquier otro fallo, devuelve
  /// `desconocido()`, que **no muestra la lista**. Mismo criterio que los
  /// candados de plan (D-184): ante la duda, no molestar.
  Future<OnboardingProgress> getProgress(String branchId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_onboarding_progress',
        params: {'p_branch_id': branchId},
      );

      if (response is List && response.isNotEmpty) {
        final first = response.first;
        if (first is Map) {
          return OnboardingProgress.fromMap(Map<String, dynamic>.from(first));
        }
      }

      if (response is Map) {
        return OnboardingProgress.fromMap(Map<String, dynamic>.from(response));
      }

      return const OnboardingProgress.desconocido();
    } catch (_) {
      return const OnboardingProgress.desconocido();
    }
  }

  /// "Ya lo tengo listo": deja de mostrarse para todo el negocio.
  ///
  /// Esta sí propaga el fallo: si el salón pulsa el botón y no se guarda, tiene
  /// que enterarse, porque si no la lista reaparecerá y parecerá que el botón
  /// no hace nada.
  Future<void> dismiss() async {
    await Supabase.instance.client.rpc('dismiss_onboarding');
  }
}
