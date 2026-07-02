import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_summary.dart';

class AgendaService {
  const AgendaService();

  Future<List<AgendaSummary>> getAgendaSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_agenda_summary');

    return response
        .map<AgendaSummary>((item) => AgendaSummary.fromMap(item))
        .toList();
  }
}
