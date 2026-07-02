import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket_summary.dart';

class TicketsService {
  const TicketsService();

  Future<List<TicketSummary>> getTicketsSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_tickets_summary');

    return response
        .map<TicketSummary>((item) => TicketSummary.fromMap(item))
        .toList();
  }
}
