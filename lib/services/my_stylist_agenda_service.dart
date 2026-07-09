import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_stylist_agenda_item.dart';

class MyStylistAgendaService {
  const MyStylistAgendaService();

  Future<List<MyStylistAgendaItem>> getMyStylistAgenda() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_stylist_agenda',
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => MyStylistAgendaItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
