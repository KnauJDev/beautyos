import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ticket_status.dart';

/// Formateador de moneda colombiana (\$ 50.000).
String formatCOP(num amount) {
  final str = amount.round().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '\$${buffer.toString()}';
}

/// Representa el conteo y valores agregados de tickets por cubeta y estado (Nivel 1).
///
/// Devuelto por la RPC `get_ticket_board_counts_v2` (D-101 / D-147).
class TicketBoardCount {
  final String bucket;
  final String status;
  final int ticketCount;
  final double totalPrice;
  final double totalPendingBalance;

  const TicketBoardCount({
    required this.bucket,
    required this.status,
    required this.ticketCount,
    required this.totalPrice,
    required this.totalPendingBalance,
  });

  factory TicketBoardCount.fromMap(Map<String, dynamic> map) {
    return TicketBoardCount(
      bucket: map['bucket']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      ticketCount: (map['ticket_count'] as num?)?.toInt() ?? 0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      totalPendingBalance:
          (map['total_pending_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  TicketStatus get ticketStatus => TicketStatus.desde(status);
}

/// Representa una fila en la lista ampliada de tickets (Nivel 2).
///
/// Devuelto por la RPC `get_ticket_board_list_v2` al hacer clic en una casilla (D-101 / D-116 / D-147).
class TicketBoardItem {
  final String id;
  final int? ticketNumber;
  final String ticketCode;
  final int? saleNumber;
  final String? saleCode;
  final DateTime? closedAt;
  final String? clientId;
  final String clientName;
  final String clientPhone;
  final DateTime? scheduledAt;
  final String status;
  final String channel;
  final String serviceNames;
  final String stylistNames;
  final double totalPrice;
  final int totalDurationMinutes;
  final double paidAmount;
  final double pendingBalance;
  final String paymentStatus;

  const TicketBoardItem({
    required this.id,
    this.ticketNumber,
    required this.ticketCode,
    this.saleNumber,
    this.saleCode,
    this.closedAt,
    this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.scheduledAt,
    required this.status,
    required this.channel,
    required this.serviceNames,
    required this.stylistNames,
    required this.totalPrice,
    required this.totalDurationMinutes,
    required this.paidAmount,
    required this.pendingBalance,
    required this.paymentStatus,
  });

  factory TicketBoardItem.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    if (map['scheduled_at'] != null) {
      parsedDate = DateTime.tryParse(map['scheduled_at'].toString());
    }

    DateTime? parsedClosedAt;
    if (map['closed_at'] != null) {
      parsedClosedAt = DateTime.tryParse(map['closed_at'].toString());
    }

    return TicketBoardItem(
      id: map['id']?.toString() ?? '',
      ticketNumber: (map['ticket_number'] as num?)?.toInt(),
      ticketCode: map['ticket_code']?.toString() ?? '',
      saleNumber: (map['sale_number'] as num?)?.toInt(),
      saleCode: map['sale_code']?.toString(),
      closedAt: parsedClosedAt,
      clientId: map['client_id']?.toString(),
      clientName: map['client_name']?.toString() ?? 'Cliente sin nombre',
      clientPhone: map['client_phone']?.toString() ?? '',
      scheduledAt: parsedDate,
      status: map['status']?.toString() ?? '',
      channel: map['channel']?.toString() ?? 'manual',
      serviceNames: map['service_names']?.toString() ?? 'Sin servicios',
      stylistNames: map['stylist_names']?.toString() ?? 'Sin estilista',
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      totalDurationMinutes:
          (map['total_duration_minutes'] as num?)?.toInt() ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      pendingBalance: (map['pending_balance'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['payment_status']?.toString() ?? 'sin_pago',
    );
  }

  TicketStatus get ticketStatus => TicketStatus.desde(status);
}

/// Definición de las 5 columnas agrupadas de la vista DÍA (D-101).
enum DayBoardColumn {
  porConfirmar(
    titulo: 'Por confirmar',
    subtitulo: 'Solicitado, cotizado, apartado',
    estados: ['solicitado', 'cotizado', 'apartado'],
    color: AppColors.statePending,
    colorFondo: AppColors.statePendingTint,
  ),
  confirmado(
    titulo: 'Confirmado',
    subtitulo: 'Confirmado, en espera',
    estados: ['confirmado', 'en_espera'],
    color: AppColors.stateConfirmed,
    colorFondo: AppColors.stateConfirmedTint,
  ),
  enProceso(
    titulo: 'En proceso',
    subtitulo: 'Sucediendo ahora',
    estados: ['en_proceso'],
    color: AppColors.stateInProgress,
    colorFondo: AppColors.stateInProgressTint,
  ),
  porCobrar(
    titulo: 'Por cobrar',
    subtitulo: 'Finalizado sin cerrar caja',
    estados: ['finalizado'],
    color: AppColors.stateToCollect,
    colorFondo: AppColors.stateToCollectTint,
  ),
  cerrado(
    titulo: 'Cerrado',
    subtitulo: 'Cobrado y completado',
    estados: ['cerrado'],
    color: AppColors.stateClosed,
    colorFondo: AppColors.stateClosedTint,
  );

  final String titulo;
  final String subtitulo;
  final List<String> estados;
  final Color color;
  final Color colorFondo;

  const DayBoardColumn({
    required this.titulo,
    required this.subtitulo,
    required this.estados,
    required this.color,
    required this.colorFondo,
  });

  bool contiene(String estado) =>
      estados.contains(estado.toLowerCase().trim());
}

/// Definición de las 6 columnas discriminadas de la vista SEMANA (D-101).
enum WeekBoardColumn {
  solicitado(
    titulo: 'Solicitado',
    estados: ['solicitado'],
    color: AppColors.statePending,
  ),
  cotizado(
    titulo: 'Cotizado',
    estados: ['cotizado'],
    color: AppColors.statePending,
  ),
  apartado(
    titulo: 'Apartado',
    estados: ['apartado'],
    color: AppColors.statePending,
  ),
  confirmado(
    titulo: 'Confirmado',
    estados: ['confirmado', 'en_espera'],
    color: AppColors.stateConfirmed,
  ),
  porCobrar(
    titulo: 'Por cobrar',
    estados: ['finalizado'],
    color: AppColors.stateToCollect,
  ),
  cerrado(
    titulo: 'Cerrado',
    estados: ['cerrado'],
    color: AppColors.stateClosed,
  );

  final String titulo;
  final List<String> estados;
  final Color color;

  const WeekBoardColumn({
    required this.titulo,
    required this.estados,
    required this.color,
  });

  bool contiene(String estado) =>
      estados.contains(estado.toLowerCase().trim());
}
