import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_summary.dart';

class AgendaService {
  const AgendaService({required this.branchId});

  final String? branchId;

  Future<List<AgendaSummary>> getAgendaSummary() async {
    final response = branchId == null
        ? await Supabase.instance.client.rpc('get_agenda_summary')
        : await Supabase.instance.client.rpc(
            'get_agenda_summary_v2',
            params: {'p_branch_id': branchId},
          );

    return response
        .map<AgendaSummary>((item) => AgendaSummary.fromMap(item))
        .toList();
  }
}
