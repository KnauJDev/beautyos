import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket_service_option.dart';
import '../models/available_appointment_slot.dart';
import '../models/ticket_service_management_item.dart';
import '../models/ticket_service_correction_option.dart';
import '../models/ticket_payment.dart';
import '../models/ticket_summary.dart';

class TicketsService {
  const TicketsService({required this.branchId});

  final String? branchId;

  Future<List<TicketSummary>> getTicketsSummary() async {
    final response = await Supabase.instance.client.rpc(
      branchId == null ? 'get_tickets_summary' : 'get_tickets_summary_v2',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return response
        .map<TicketSummary>((item) => TicketSummary.fromMap(item))
        .toList();
  }

  Future<List<TicketServiceOption>> getTicketServiceOptions() async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_ticket_service_options'
          : 'get_ticket_service_options_v2',
      params: {if (branchId != null) 'p_branch_id': branchId},
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
      branchId == null ? 'add_ticket_service' : 'add_ticket_service_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<bool> createScheduledTicketWithService({
    required String clientId,
    required String serviceId,
    required String stylistId,
    required DateTime scheduledAt,
    String channel = 'manual',
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'create_scheduled_ticket_with_service'
          : 'create_scheduled_ticket_with_service_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_client_id': clientId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'p_channel': channel,
        'p_notes': notes,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<List<AvailableAppointmentSlot>> getAvailableAppointmentSlots({
    required String serviceId,
    required String stylistId,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_available_appointment_slots'
          : 'get_available_appointment_slots_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
        'p_date': day.toIso8601String().substring(0, 10),
      },
    );

    return (response as List<dynamic>)
        .map(
          (item) => AvailableAppointmentSlot.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<TicketServiceManagementItem>> getTicketServicesForManagement(
    String ticketId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_ticket_services_for_management'
          : 'get_ticket_services_for_management_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
      },
    );

    return (response as List<dynamic>)
        .map(
          (item) => TicketServiceManagementItem.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<bool> updateTicketServiceAssignment({
    required String ticketServiceId,
    required String serviceId,
    String? stylistId,
    required String reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'update_ticket_service_assignment'
          : 'update_ticket_service_assignment_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_service_id': ticketServiceId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<bool> removeTicketService({
    required String ticketServiceId,
    required String reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'remove_ticket_service'
          : 'remove_ticket_service_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_service_id': ticketServiceId,
        'p_reason': reason,
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
      branchId == null ? 'reschedule_ticket' : 'reschedule_ticket_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
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
      branchId == null ? 'change_ticket_status' : 'change_ticket_status_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
        'p_new_status': newStatus,
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<List<TicketServiceCorrectionOption>> getTicketServicesForCorrection(
    String ticketId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_ticket_services_for_correction'
          : 'get_ticket_services_for_correction_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
      },
    );

    return (response as List<dynamic>)
        .map(
          (item) => TicketServiceCorrectionOption.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<bool> reopenFinishedTicketService({
    required String ticketServiceId,
    required String reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'reopen_finished_ticket_service'
          : 'reopen_finished_ticket_service_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_service_id': ticketServiceId,
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<TicketPaymentSummary> getTicketPaymentSummary(String ticketId) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_ticket_payment_summary'
          : 'get_ticket_payment_summary_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
      },
    );
    final rows = response as List<dynamic>;

    if (rows.isEmpty) {
      throw StateError('No se pudo consultar el saldo del ticket.');
    }

    return TicketPaymentSummary.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<List<TicketPaymentRecord>> getTicketPayments(String ticketId) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null ? 'get_ticket_payments' : 'get_ticket_payments_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
      },
    );

    return (response as List<dynamic>)
        .map(
          (item) => TicketPaymentRecord.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<bool> registerTicketPayment({
    required String ticketId,
    required num amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'register_ticket_payment'
          : 'register_ticket_payment_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_ticket_id': ticketId,
        'p_amount': amount,
        'p_method': method,
        'p_reference': reference,
        'p_notes': notes,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<bool> voidTicketPayment({
    required String paymentId,
    required String reason,
  }) async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'void_ticket_payment'
          : 'void_ticket_payment_v2',
      params: {
        if (branchId != null) 'p_branch_id': branchId,
        'p_payment_id': paymentId,
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
      paidAmount: 0,
      balanceAmount: 0,
      paymentStatus: 'sin_pago',
    );
  }
}
