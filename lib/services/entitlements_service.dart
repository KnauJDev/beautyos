import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tenant_entitlements.dart';

/// Lee del backend qué permite el plan del negocio (TL-19, D-184).
///
/// La RPC `get_my_entitlements()` existe desde el 22-jul y hasta ahora **no la
/// llamaba nadie desde Flutter**: el backend hacía cumplir los planes y la
/// interfaz no se enteraba.
class EntitlementsService {
  const EntitlementsService();

  /// Devuelve lo que el plan permite, o `TenantEntitlements.desconocido()` si
  /// no se pudo averiguar.
  ///
  /// **Nunca lanza.** La RPC revienta a propósito cuando quien pregunta no
  /// tiene membresía activa de negocio ("No existe una membresia activa para
  /// este usuario") — le pasa al dueño de la plataforma y a la clienta final,
  /// que no son de ningún salón. Eso no es un error que haya que mostrar: es
  /// simplemente que la pregunta no aplica.
  ///
  /// Y si el fallo fuera de red, tampoco se bloquea nada: ver la explicación de
  /// por qué esto falla abierto en `TenantEntitlements.permite`.
  Future<TenantEntitlements> getMyEntitlements() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_my_entitlements',
      );

      if (response is List) {
        return TenantEntitlements.fromList(response);
      }

      return const TenantEntitlements.desconocido();
    } catch (_) {
      return const TenantEntitlements.desconocido();
    }
  }
}
