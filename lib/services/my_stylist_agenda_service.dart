import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_stylist_agenda_item.dart';

class MyStylistAgendaService {
  const MyStylistAgendaService({required this.branchId});

  final String? branchId;

  Future<List<MyStylistAgendaItem>> getMyStylistAgenda(DateTime date) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_my_stylist_agenda_by_date'
          : 'get_my_stylist_agenda_by_date_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_date': _formatDate(date),
      },
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<bool> changeTicketServiceStatus({
    required String ticketServiceId,
    required String newStatus,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'change_ticket_service_status'
          : 'change_ticket_service_status_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_service_id': ticketServiceId,
        'p_new_status': newStatus,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }
}
