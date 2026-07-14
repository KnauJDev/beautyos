class TicketSummary {
  final String id;
  final String clientName;
  final DateTime? scheduledAt;
  final String status;
  final String channel;
  final String serviceNames;
  final String stylistNames;
  final num totalPrice;
  final int totalDurationMinutes;

  const TicketSummary({
    required this.id,
    required this.clientName,
    required this.scheduledAt,
    required this.status,
    required this.channel,
    required this.serviceNames,
    required this.stylistNames,
    required this.totalPrice,
    required this.totalDurationMinutes,
  });

  factory TicketSummary.fromMap(Map<String, dynamic> map) {
    return TicketSummary(
      id: map['id'].toString(),
      clientName: map['client_name']?.toString() ?? 'Cliente sin nombre',
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString()),
      status: map['status']?.toString() ?? 'Sin estado',
      channel: map['channel']?.toString() ?? 'Sin canal',
      serviceNames: map['service_names']?.toString() ?? 'Sin servicios',
      stylistNames: map['stylist_names']?.toString() ?? 'Sin estilista',
      totalPrice: _readNumber(map['total_price']),
      totalDurationMinutes: _readInt(map['total_duration_minutes']),
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
    final value = totalPrice.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final positionFromEnd = value.length - i;

      buffer.write(value[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }

  String get scheduledAtText {
    if (scheduledAt == null) {
      return 'Sin fecha';
    }

    final localDate = scheduledAt!.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    return '$day/$month/$year';
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'solicitado':
        return 'Solicitado';
      case 'cotizado':
        return 'Cotizado';
      case 'apartado':
        return 'Apartado';
      case 'confirmado':
        return 'Confirmado';
      case 'en_espera':
        return 'En espera';
      case 'en_proceso':
        return 'En proceso';
      case 'finalizado':
        return 'Finalizado';
      case 'cerrado':
        return 'Cerrado';
      case 'cancelado':
        return 'Cancelado';
      case 'no_asistio':
        return 'No asistio';
      default:
        return status;
    }
  }
}
