import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_summary.dart';

class ClientsService {
  const ClientsService();

  Future<List<ClientSummary>> getClientsSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_clients_summary');

    return response
        .map<ClientSummary>((item) => ClientSummary.fromMap(item))
        .toList();
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

    return ClientSummary.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
