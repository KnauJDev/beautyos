import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_summary.dart';
import 'monitoreo_service.dart';

class ClientsService {
  const ClientsService();

  Future<List<ClientSummary>> getClientsSummary() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client.rpc('get_clients_summary');

        return response
            .map<ClientSummary>((item) => ClientSummary.fromMap(item))
            .toList();
      },
      motivo: 'Fallo al consultar get_clients_summary()',
    );
  }

  Future<List<ClientSummary>> getClientsManagementSummary() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client.rpc(
          'get_clients_management_summary',
        );

        return response
            .map<ClientSummary>((item) => ClientSummary.fromMap(item))
            .toList();
      },
      motivo: 'Fallo al consultar get_clients_management_summary()',
    );
  }

  Future<ClientSummary?> createClient({
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_client',
      params: {
        'p_name': name,
        'p_phone': phone,
        'p_email': email,
        'p_notes': notes,
      },
    );

    final rows = response as List<dynamic>;

    if (rows.isEmpty) {
      return null;
    }

    return ClientSummary.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<ClientSummary?> updateClient({
    required String clientId,
    required String name,
    required String phone,
    String? email,
    String? notes,
    required bool active,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'update_client',
      params: {
        'p_client_id': clientId,
        'p_name': name,
        'p_phone': phone,
        'p_email': email,
        'p_notes': notes,
        'p_active': active,
      },
    );

    final rows = response as List<dynamic>;

    if (rows.isEmpty) {
      return null;
    }

    return ClientSummary.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  /// Asigna o restablece el PIN de 4 dígitos del portal de la clienta
  /// (D-167). Exclusivo owner/admin. Cierra cualquier sesión que tuviera
  /// abierta con el PIN anterior.
  Future<void> resetPortalPin({
    required String clientId,
    required String newPin,
  }) async {
    await Supabase.instance.client.rpc(
      'admin_reset_client_portal_pin',
      params: {'p_client_id': clientId, 'p_new_pin': newPin},
    );
  }
}
