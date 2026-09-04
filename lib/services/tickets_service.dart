import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket_service_option.dart';
import '../models/available_appointment_slot.dart';
import '../models/recurring_booking_result.dart';
import '../models/ticket_service_management_item.dart';
import '../models/ticket_service_correction_option.dart';
import '../models/ticket_payment.dart';
import '../models/ticket_summary.dart';

/// Primer dia del rango que esta pantalla pide al servidor (D-204).
///
/// No es una fecha con significado de negocio: es un limite lo bastante atras
/// como para que "todos" siga queriendo decir todos. Existe porque la RPC
/// **exige** un rango y no acepta nulos (D-203).
final DateTime inicioDelHistorial = DateTime.utc(2000, 1, 1);

/// Ultimo dia del rango. Tiene que ir al futuro: los tickets programados son
/// citas que todavia no han ocurrido, y si el rango acabara hoy no se verian.
final DateTime finDelHistorial = DateTime.utc(2100, 1, 1);

/// Ordena los tickets como los espera ver el historial: **lo mas reciente
/// primero** (D-204).
///
/// `get_ticket_board_list_v2` los devuelve al reves --de mas antiguo a mas
/// nuevo-- porque es la RPC del Tablero de Agenda, que es una linea de tiempo.
/// Esta pantalla es un historial. Se reordena aqui, en el cliente, y no
/// cambiando el `order by` de la RPC, porque esa misma RPC la usa el Tablero
/// de Agenda (D-148) y ahi el orden ascendente es el correcto.
///
/// Reproduce el orden que la pantalla ha tenido siempre
/// (`scheduled_at desc nulls last`, de `get_tickets_summary_v2`). El desempate
/// es por numero de ticket descendente: el codigo va relleno de ceros a la
/// izquierda con el mismo ancho, asi que ordenarlo como texto ordena igual que
/// como numero.
List<TicketSummary> ordenarTicketsParaLaLista(List<TicketSummary> tickets) {
  final ordenados = List<TicketSummary>.of(tickets);

  ordenados.sort((a, b) {
    final fechaA = a.scheduledAt;
    final fechaB = b.scheduledAt;

    // Los que no tienen fecha van al final, como hacia `nulls last`.
    if (fechaA == null && fechaB == null) {
      return b.ticketCode.compareTo(a.ticketCode);
    }
    if (fechaA == null) return 1;
    if (fechaB == null) return -1;

    final porFecha = fechaB.compareTo(fechaA);
    if (porFecha != 0) return porFecha;

    return b.ticketCode.compareTo(a.ticketCode);
  });

  return ordenados;
}

class TicketsService {
  const TicketsService({required this.branchId});

  final String branchId;

  /// Lista los tickets de la sede (D-204).
  ///
  /// **Por que manda fechas y no nulos.** `get_ticket_board_list_v2` rechaza
  /// las fechas nulas desde que existe (D-147). Mandarselas nulas es lo que
  /// tumbo esta pantalla en produccion el 04-sep: fallaba en cada carga, un
  /// `catch (_)` lo tapaba, y la pantalla vivia de `get_tickets_summary_v2`
  /// sin que nadie lo supiera (D-199, D-203). El rango de abajo reproduce
  /// exactamente el "todo el historial" que la pantalla siempre ha mostrado.
  ///
  /// **Lo que se recupera al volver a esta RPC.** El respaldo devolvia menos
  /// columnas, y por eso durante dos semanas y media no se vio: el chip del
  /// numero de venta `VTA-0000045` (`sale_number`/`sale_code`, D-150), el
  /// boton de WhatsApp con mensaje pre-armado (`client_phone`, D-195) y la
  /// busqueda por telefono o por numero de venta. Volvian vacios sin quejarse
  /// porque en `TicketSummary` son opcionales.
  ///
  /// **El saldo llega con otro nombre, y esta previsto.** Esta RPC devuelve
  /// `pending_balance` donde la otra devolvia `balance_amount`.
  /// `TicketSummary.fromMap` lee las dos (`balance_amount ?? pending_balance`),
  /// asi que el saldo sigue siendo correcto. Se comprobo antes de cambiar:
  /// equivocarse ahi habria enseniado saldo cero en todos los tickets, o sea
  /// "esta todo pagado" cuando no lo esta.
  ///
  /// **Lo que este cambio NO cierra.** El tercio de TL-09 que decia que la
  /// consulta trae el historial completo **sigue abierto**: el rango es
  /// amplio a proposito, para no cambiar lo que la pantalla ensenia. Acotarlo
  /// de verdad es una decision de producto (que significa "todos") y va
  /// aparte.
  ///
  /// **El riesgo que queda anotado.** Esta RPC filtra
  /// `and tk.scheduled_at is not null`; la anterior no. El propietario
  /// confirmo el 04-sep que hoy hay **cero** tickets sin fecha programada,
  /// por eso se pudo cambiar. Pero la columna admite nulos, asi que si algun
  /// dia se crea uno sin fecha **desaparecera de esta lista en silencio**, y
  /// un ticket que no se ve es un ticket que no se cobra. El arreglo durable
  /// es una migracion que deje de excluirlos.
  ///
  /// **Sin `catch`**: si esto falla, la excepcion sube y la pantalla la
  /// ensenia. Es lo unico de D-199 que hay que conservar intacto.
  Future<List<TicketSummary>> getTicketsSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_ticket_board_list_v2',
      params: {
        'p_branch_id': branchId,
        'p_start_date': _soloFecha(inicioDelHistorial),
        'p_end_date': _soloFecha(finDelHistorial),
      },
    );

    final tickets = (response as List<dynamic>)
        .map<TicketSummary>(
          (item) => TicketSummary.fromMap(item as Map<String, dynamic>),
        )
        .toList();

    // La RPC ordena de mas antiguo a mas nuevo porque es la del **Tablero de
    // Agenda**, que es una linea de tiempo. Esta pantalla es un historial y
    // quiere lo contrario. Sin esto, y con la paginacion de diez en diez de
    // D-199, abrir Tickets enseniaria los diez tickets mas VIEJOS del salon.
    return ordenarTicketsParaLaLista(tickets);
  }

  String _soloFecha(DateTime fecha) {
    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '$anio-$mes-$dia';
  }

  Future<List<TicketServiceOption>> getTicketServiceOptions() async {
    final response = await Supabase.instance.client.rpc(
      'get_ticket_service_options_v2',
      params: {'p_branch_id': branchId},
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
      'add_ticket_service_v2',
      params: {
        'p_branch_id': branchId,
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
      'create_scheduled_ticket_with_service_v2',
      params: {
        'p_branch_id': branchId,
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

  Future<List<RecurringBookingResult>> createRecurringScheduledTicketWithService({
    required String clientId,
    required String serviceId,
    required String stylistId,
    required DateTime scheduledAt,
    required String repeatFrequency,
    required DateTime repeatUntil,
    String channel = 'manual',
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_recurring_scheduled_tickets_v2',
      params: {
        'p_branch_id': branchId,
        'p_client_id': clientId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'p_repeat_frequency': repeatFrequency,
        'p_repeat_until':
            '${repeatUntil.year.toString().padLeft(4, '0')}-'
            '${repeatUntil.month.toString().padLeft(2, '0')}-'
            '${repeatUntil.day.toString().padLeft(2, '0')}',
        'p_channel': channel,
        'p_notes': notes,
      },
    );

    return (response as List<dynamic>)
        .map(
          (item) => RecurringBookingResult.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<AvailableAppointmentSlot>> getAvailableAppointmentSlots({
    required String serviceId,
    required String stylistId,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final response = await Supabase.instance.client.rpc(
      'get_available_appointment_slots_v2',
      params: {
        'p_branch_id': branchId,
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
      'get_ticket_services_for_management_v2',
      params: {'p_branch_id': branchId, 'p_ticket_id': ticketId},
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
      'update_ticket_service_assignment_v2',
      params: {
        'p_branch_id': branchId,
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
      'remove_ticket_service_v2',
      params: {
        'p_branch_id': branchId,
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
      'reschedule_ticket_v2',
      params: {
        'p_branch_id': branchId,
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
      'change_ticket_status_v2',
      params: {
        'p_branch_id': branchId,
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
      'get_ticket_services_for_correction_v2',
      params: {'p_branch_id': branchId, 'p_ticket_id': ticketId},
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
      'reopen_finished_ticket_service_v2',
      params: {
        'p_branch_id': branchId,
        'p_ticket_service_id': ticketServiceId,
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }

  Future<TicketPaymentSummary> getTicketPaymentSummary(String ticketId) async {
    final response = await Supabase.instance.client.rpc(
      'get_ticket_payment_summary_v2',
      params: {'p_branch_id': branchId, 'p_ticket_id': ticketId},
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
      'get_ticket_payments_v2',
      params: {'p_branch_id': branchId, 'p_ticket_id': ticketId},
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
      'register_ticket_payment_v2',
      params: {
        'p_branch_id': branchId,
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
      'void_ticket_payment_v2',
      params: {
        'p_branch_id': branchId,
        'p_payment_id': paymentId,
        'p_reason': reason,
      },
    );

    return (response as List<dynamic>).isNotEmpty;
  }
}
