import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_subscription.dart';

/// El estado de pago de las sedes del negocio (D-190, D-193).
class BranchSubscriptionsService {
  const BranchSubscriptionsService();

  /// Devuelve una fila por sede, con su estado y su precio.
  ///
  /// **Lanza si falla, a diferencia de otros servicios de esta aplicación.** Y
  /// es a propósito: aquí se está hablando de dinero. Si la consulta no
  /// responde, el dueño tiene que ver un error y no una lista vacía que le haga
  /// creer que no tiene sedes que pagar.
  ///
  /// La RPC revienta para quien no es owner ni admin — eso no es un fallo, es
  /// que la pregunta no aplica —, así que solo se llama desde Configuración,
  /// que ya está restringida a esos dos roles.
  Future<List<BranchSubscription>> getBranchSubscriptions() async {
    final response = await Supabase.instance.client.rpc(
      'get_branch_subscriptions',
    );

    if (response is! List) return const <BranchSubscription>[];

    return response
        .whereType<Map>()
        .map(
          (fila) => BranchSubscription.fromMap(Map<String, dynamic>.from(fila)),
        )
        .toList(growable: false);
  }
}
