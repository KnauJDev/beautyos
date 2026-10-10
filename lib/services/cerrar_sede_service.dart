import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cerrar_sede.dart';

/// Las funciones del paso 9.65 (D-328), migración `20261010100000`, control
/// 250. El dueño del salón (`close_branch`, `reopen_branch`) o la plataforma
/// desde el Panel (`platform_close_branch`, `platform_reopen_branch`). Al
/// reabrirla el dueño queda pendiente de pago, como una sede nueva; al
/// reabrirla la plataforma, activa.
class CerrarSedeService {
  const CerrarSedeService({this.desdeLaPlataforma = false});

  final bool desdeLaPlataforma;

  /// Las citas desde hoy que impiden cerrarla (como mucho 20).
  Future<List<CitaProxima>> proximasCitas(String branchId) async {
    final respuesta = await Supabase.instance.client.rpc(
      'get_branch_upcoming_appointments',
      params: {'p_branch_id': branchId},
    );
    return (respuesta as List)
        .map((f) => CitaProxima.fromMap(Map<String, dynamic>.from(f as Map)))
        .toList(growable: false);
  }

  Future<void> cerrar(String branchId) async {
    await Supabase.instance.client.rpc(
      desdeLaPlataforma ? 'platform_close_branch' : 'close_branch',
      params: {'p_branch_id': branchId},
    );
  }

  Future<void> reabrir(String branchId) async {
    await Supabase.instance.client.rpc(
      desdeLaPlataforma ? 'platform_reopen_branch' : 'reopen_branch',
      params: {'p_branch_id': branchId},
    );
  }
}
