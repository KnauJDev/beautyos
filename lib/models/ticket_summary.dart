import '../widgets/ticket_status.dart';
import 'ticket_board.dart' show formatCOP;

class TicketSummary {
  final String id;

  /// El consecutivo del negocio tal como se le muestra a una persona
  /// ("#0000701", o "FE-0000042" si el negocio usa prefijo propio).
  ///
  /// Existe desde D-117. El identificador interno (`id`) sigue siendo el que
  /// viaja a la base de datos: este solo se lee, se busca y se dice en voz
  /// alta. Nunca cambia una vez emitido.
  final String ticketCode;

  /// Número de venta contable consecutivo e inmutable por sede (D-150 / D-151).
  /// Se asigna de forma atómica únicamente al pasar a estado `cerrado`.
  final int? saleNumber;

  /// Código visible de venta/factura (ej. "VTA-0000045" o "FJ-020000").
  final String? saleCode;

  /// Fecha y hora exacta en la que se cerró el ticket contablemente.
  final DateTime? closedAt;

  final String? clientId;
  final String clientName;
  final String clientPhone;
  final DateTime? scheduledAt;
  final String status;
  final String channel;
  final String serviceNames;
  final String stylistNames;
  final num totalPrice;
  final int totalDurationMinutes;
  final num paidAmount;
  final num balanceAmount;
  final String paymentStatus;

  const TicketSummary({
    required this.id,
    required this.ticketCode,
    this.saleNumber,
    this.saleCode,
    this.closedAt,
    this.clientId,
    required this.clientName,
    this.clientPhone = '',
    required this.scheduledAt,
    required this.status,
    required this.channel,
    required this.serviceNames,
    required this.stylistNames,
    required this.totalPrice,
    required this.totalDurationMinutes,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentStatus,
  });

  factory TicketSummary.fromMap(Map<String, dynamic> map) {
    return TicketSummary(
      id: map['id'].toString(),
      ticketCode: map['ticket_code']?.toString() ?? '',
      saleNumber: map['sale_number'] != null ? _readInt(map['sale_number']) : null,
      saleCode: map['sale_code']?.toString(),
      closedAt: map['closed_at'] == null
          ? null
          : DateTime.tryParse(map['closed_at'].toString()),
      clientId: map['client_id']?.toString(),
      clientName: map['client_name']?.toString() ?? 'Cliente sin nombre',
      clientPhone: map['client_phone']?.toString() ??
          map['phone']?.toString() ??
          map['whatsapp']?.toString() ??
          '',
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString()),
      status: map['status']?.toString() ?? 'Sin estado',
      channel: map['channel']?.toString() ?? 'Sin canal',
      serviceNames: map['service_names']?.toString() ?? 'Sin servicios',
      stylistNames: map['stylist_names']?.toString() ?? 'Sin estilista',
      totalPrice: _readNumber(map['total_price']),
      totalDurationMinutes: _readInt(map['total_duration_minutes']),
      paidAmount: _readNumber(map['paid_amount']),
      balanceAmount: _readNumber(map['balance_amount'] ?? map['pending_balance']),
      paymentStatus: map['payment_status']?.toString() ?? 'sin_pago',
    );
  }

  static num _readNumber(dynamic value) {
    if (value is num) {
      return value;
    }

    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get formattedPrice {
    return formatCOP(totalPrice);
  }

  String get formattedPaidAmount {
    return formatCOP(paidAmount);
  }

  String get formattedBalanceAmount {
    return formatCOP(balanceAmount);
  }

  bool get showsPaymentInfo {
    return status == 'finalizado' || status == 'cerrado' || paidAmount > 0;
  }

  bool get isClosed => status == 'cerrado';

  bool get hasPendingBalance => balanceAmount > 0;

  String get scheduledAtText {
    if (scheduledAt == null) {
      return 'Sin fecha';
    }

    final localDate = scheduledAt!.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String get closedAtText {
    if (closedAt == null) {
      return '';
    }

    final localDate = closedAt!.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  /// Delega en `TicketStatus` (D-107).
  TicketStatus get ticketStatus => TicketStatus.desde(status);

  String get statusLabel => ticketStatus.etiqueta;
}
