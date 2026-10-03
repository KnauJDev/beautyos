import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invitacion_a_volver.dart';

/// Las funciones del paso 4B (D-314), migración `20261003200000`, control 242.
///
/// La lista y registrar una invitación: dueño, administrador y recepción. Los
/// tiempos de volver: dueño y administrador. La estilista no ve nada de esto
/// (D-266): no ve la base de clientas del salón.
class InvitarAVolverService {
  const InvitarAVolverService({required this.branchId});

  final String branchId;

  Future<List<InvitacionAVolver>> listar() async {
    final respuesta = await Supabase.instance.client.rpc(
      'get_return_invitations',
      params: {'p_branch_id': branchId},
    );
    return (respuesta as List)
        .map(
          (fila) =>
              InvitacionAVolver.fromMap(Map<String, dynamic>.from(fila as Map)),
        )
        .toList(growable: false);
  }

  /// Se registra ANTES de abrir WhatsApp: si la persona no termina de
  /// enviarlo, igual queda la intención, y así nadie le escribe dos veces
  /// creyendo que nadie lo hizo.
  Future<void> registrar({
    required String clientId,
    required String serviceId,
  }) async {
    await Supabase.instance.client.rpc(
      'register_return_invitation',
      params: {
        'p_branch_id': branchId,
        'p_client_id': clientId,
        'p_service_id': serviceId,
      },
    );
  }

  /// El tiempo propio de cada servicio (`null` = el del salón) y el del salón.
  Future<({Map<String, int?> porServicio, int delSalon})> tiempos() async {
    final respuesta = await Supabase.instance.client.rpc(
      'get_return_days',
      params: {'p_branch_id': branchId},
    );
    final filas = (respuesta as List).cast<Map>();
    var delSalon = 45;
    final porServicio = <String, int?>{};
    for (final fila in filas) {
      porServicio[fila['service_id'].toString()] =
          (fila['return_after_days'] as num?)?.toInt();
      delSalon = (fila['default_days'] as num?)?.toInt() ?? delSalon;
    }
    return (porServicio: porServicio, delSalon: delSalon);
  }

  Future<void> fijarTiempoDeServicio({
    required String serviceId,
    required int? dias,
  }) async {
    await Supabase.instance.client.rpc(
      'set_service_return_days',
      params: {
        'p_branch_id': branchId,
        'p_service_id': serviceId,
        'p_days': dias,
      },
    );
  }

  Future<void> fijarTiempoDelSalon(int dias) async {
    await Supabase.instance.client.rpc(
      'set_return_default_days',
      params: {'p_branch_id': branchId, 'p_days': dias},
    );
  }
}
