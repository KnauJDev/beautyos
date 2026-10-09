import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/precios_desde.dart';

/// Lo último que se leyó para el salón abierto. Las pantallas del salón que
/// enseñan precios (Servicios, Estilistas, Tickets y Caja, Nueva cita) lo
/// cargan al abrir con [PreciosDesdeService.cargarEnElSalon], y sus diálogos
/// lo leen sin pasarlo de mano en mano. La lista es del negocio, no de la
/// sede: es la misma en todas sus sedes.
final preciosDesdeDelSalon = ValueNotifier<PreciosDesde>(PreciosDesde.ninguno);

/// Las funciones de D-326, migración `20261009100000`, control 249.
///
/// La lista se puede pedir sin sesión (la página pública la usa); marcar una
/// categoría, solo dueño y administrador.
class PreciosDesdeService {
  const PreciosDesdeService({required this.branchId});

  final String branchId;

  /// **Nunca lanza**: si no se puede leer, los precios se ven como siempre.
  Future<PreciosDesde> leer() async {
    try {
      final respuesta = await Supabase.instance.client.rpc(
        'get_price_from_categories',
        params: {'p_branch_id': branchId},
      );
      return PreciosDesde.desdeLista(respuesta as List? ?? const []);
    } catch (_) {
      return PreciosDesde.ninguno;
    }
  }

  /// Lee la lista y la deja en [preciosDesdeDelSalon].
  Future<PreciosDesde> cargarEnElSalon() async {
    final lista = await leer();
    preciosDesdeDelSalon.value = lista;
    return lista;
  }

  /// Devuelve cómo quedó la lista y la deja en [preciosDesdeDelSalon].
  Future<PreciosDesde> marcar({
    required String categoria,
    required bool desde,
  }) async {
    final respuesta = await Supabase.instance.client.rpc(
      'set_price_from_category',
      params: {
        'p_branch_id': branchId,
        'p_category': categoria,
        'p_desde': desde,
      },
    );
    final lista = PreciosDesde.desdeLista(respuesta as List? ?? const []);
    preciosDesdeDelSalon.value = lista;
    return lista;
  }
}
