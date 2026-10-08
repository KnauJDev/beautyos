import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cuando_vuelve.dart';

/// Las funciones del paso 9.63 (D-323), migración `20261008200000`, control
/// 248.
///
/// Al cerrar: dueño, administrador, recepción y la estilista (solo en sus
/// servicios). La ficha de la clienta: dueño, administrador y recepción; la
/// estilista no ve la base de clientas del salón (D-266).
class CuandoVuelveService {
  const CuandoVuelveService({required this.branchId});

  final String branchId;

  /// Los servicios de la cita, con lo que viene lleno.
  Future<List<VueltaAlCerrar>> paraCerrar(String ticketId) async {
    final respuesta = await Supabase.instance.client.rpc(
      'get_return_days_for_ticket',
      params: {'p_branch_id': branchId, 'p_ticket_id': ticketId},
    );
    return (respuesta as List)
        .map((f) => VueltaAlCerrar.fromMap(Map<String, dynamic>.from(f as Map)))
        .toList(growable: false);
  }

  /// La respuesta de un servicio ya terminado. `dias` vacío = el del
  /// servicio; `invitar` en falso = "esta vez no" (su número no se borra).
  Future<void> guardarAlCerrar({
    required String ticketServiceId,
    required int? dias,
    required bool invitar,
  }) async {
    await Supabase.instance.client.rpc(
      'set_client_return_after_close',
      params: {
        'p_branch_id': branchId,
        'p_ticket_service_id': ticketServiceId,
        'p_days': dias,
        'p_invitar': invitar,
      },
    );
  }

  Future<List<VueltaDeLaClienta>> deLaClienta(String clientId) async {
    final respuesta = await Supabase.instance.client.rpc(
      'get_client_return_days',
      params: {'p_branch_id': branchId, 'p_client_id': clientId},
    );
    return (respuesta as List)
        .map(
          (f) => VueltaDeLaClienta.fromMap(Map<String, dynamic>.from(f as Map)),
        )
        .toList(growable: false);
  }

  /// `dias` vacío = "Usar el del servicio".
  Future<void> fijarDeLaClienta({
    required String clientId,
    required String serviceId,
    required int? dias,
  }) async {
    await Supabase.instance.client.rpc(
      'set_client_return_days',
      params: {
        'p_branch_id': branchId,
        'p_client_id': clientId,
        'p_service_id': serviceId,
        'p_days': dias,
      },
    );
  }
}
