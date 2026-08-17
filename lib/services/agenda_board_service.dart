import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket_board.dart';

/// Servicio para consultar los conteos y listas del Tablero de Agenda (D-101 / D-147).
class AgendaBoardService {
  final String branchId;
  final SupabaseClient? client;

  AgendaBoardService({
    required this.branchId,
    this.client,
  });

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Obtiene los conteos agregados para el Tablero (Nivel 1).
  Future<List<TicketBoardCount>> getBoardCounts({
    required DateTime startDate,
    required DateTime endDate,
    String granularity = '15min',
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_ticket_board_counts_v2',
        params: {
          'p_branch_id': branchId,
          'p_start_date': _formatDate(startDate),
          'p_end_date': _formatDate(endDate),
          'p_granularity': granularity,
        },
      );

      if (response == null) return [];
      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((item) => TicketBoardCount.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error en getBoardCounts: $e');
      rethrow;
    }
  }

  /// Obtiene la lista detallada de tickets al tocar una celda (Nivel 2).
  Future<List<TicketBoardItem>> getBoardList({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? statuses,
    String? bucket,
    String? granularity,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_ticket_board_list_v2',
        params: {
          'p_branch_id': branchId,
          'p_start_date': _formatDate(startDate),
          'p_end_date': _formatDate(endDate),
          'p_statuses': statuses,
          'p_bucket': bucket,
          'p_granularity': granularity,
        },
      );

      if (response == null) return [];
      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((item) => TicketBoardItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error en getBoardList: $e');
      rethrow;
    }
  }

  /// Suscripción Realtime para refrescar en vivo cuando haya cambios en los tickets de la sede.
  RealtimeChannel? subscribeToTickets({
    required VoidCallback onTicketChanged,
  }) {
    try {
      final channel = _supabase
          .channel('agenda_board_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tickets',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) {
              onTicketChanged();
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('No se pudo establecer suscripción Realtime en Agenda: $e');
      return null;
    }
  }
}
