import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket_service_option.dart';
import '../models/ticket_summary.dart';

class TicketsService {
  const TicketsService();

  Future<List<TicketSummary>> getTicketsSummary() async {
    final response = await Supabase.instance.client.rpc('get_tickets_summary');

    return response
        .map<TicketSummary>((item) => TicketSummary.fromMap(item))
        .toList();
  }

  Future<List<TicketServiceOption>> getTicketServiceOptions() async {
    final response = await Supabase.instance.client.rpc(
      'get_ticket_service_options',
    );

    return response
        .map<TicketServiceOption>((item) => TicketServiceOption.fromMap(item))
        .toList();
  }

  Future<bool> addTicketService({
    required String ticketId,
    required String serviceId,
    String? stylistId,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'add_ticket_service',
      params: {
        'p_ticket_id': ticketId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<bool> rescheduleTicket({
    required String ticketId,
    required DateTime newScheduledAt,
    required String reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'reschedule_ticket',
      params: {
        'p_ticket_id': ticketId,
        'p_new_scheduled_at': newScheduledAt.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<bool> changeTicketStatus({
    required String ticketId,
    required String newStatus,
    String? reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'change_ticket_status',
      params: {
        'p_ticket_id': ticketId,
        'p_new_status': newStatus,
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<TicketSummary?> createTicket({
    required String clientId,
    DateTime? scheduledAt,
    String channel = 'manual',
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_ticket',
      params: {
        'p_client_id': clientId,
        'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'p_channel': channel,
        'p_notes': notes,
      },
    );

    final rows = response as List<dynamic>;

    if (rows.isEmpty) {
      return null;
    }

    final createdTicket = Map<String, dynamic>.from(rows.first as Map);

    return TicketSummary(
      id: createdTicket['id'].toString(),
      clientName: 'Cliente seleccionado',
      scheduledAt: createdTicket['scheduled_at'] == null
          ? null
          : DateTime.tryParse(createdTicket['scheduled_at'].toString()),
      status: createdTicket['status']?.toString() ?? 'solicitado',
      channel: createdTicket['channel']?.toString() ?? channel,
      serviceNames: 'Sin servicios',
      stylistNames: 'Sin estilista',
      totalPrice: 0,
      totalDurationMinutes: 0,
    );
  }
}
