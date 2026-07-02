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
}
