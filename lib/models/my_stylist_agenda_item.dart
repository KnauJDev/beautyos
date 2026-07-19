class MyStylistAgendaItem {
  const MyStylistAgendaItem({
    required this.ticketServiceId,
    required this.ticketId,
    required this.scheduledAt,
    required this.clientName,
    required this.serviceName,
    required this.ticketStatus,
    required this.serviceStatus,
    required this.price,
    required this.durationMinutes,
    required this.notes,
  });

  final String ticketServiceId;
  final String ticketId;
  final DateTime? scheduledAt;
  final String clientName;
  final String serviceName;
  final String ticketStatus;
  final String serviceStatus;
  final double price;
  final int durationMinutes;
  final String? notes;

  factory MyStylistAgendaItem.fromMap(Map<String, dynamic> map) {
    return MyStylistAgendaItem(
      ticketServiceId: map['ticket_service_id']?.toString() ?? '',
      ticketId: map['ticket_id']?.toString() ?? '',
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString())?.toLocal(),
      clientName: map['client_name']?.toString() ?? 'Cliente sin nombre',
      serviceName: map['service_name']?.toString() ?? 'Servicio sin nombre',
      ticketStatus: map['ticket_status']?.toString() ?? '',
      serviceStatus: map['service_status']?.toString() ?? '',
      price: _readDouble(map['price']),
      durationMinutes: _readInt(map['duration_minutes']),
      notes: map['notes']?.toString(),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get scheduledDateText {
    final value = scheduledAt;

    if (value == null) {
      return 'Sin fecha';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day/$month/$year';
  }

  String get scheduledTimeText {
    final value = scheduledAt;

    if (value == null) {
      return 'Sin hora';
    }

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String get formattedPrice {
    final rounded = price.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;

      buffer.write(rounded[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }

  String get durationText {
    return '$durationMinutes min';
  }

  String get ticketStatusText {
    return _humanizeStatus(ticketStatus);
  }

  String get serviceStatusText {
    return _humanizeStatus(serviceStatus);
  }

  String get notesText {
    final value = notes;

    if (value == null || value.trim().isEmpty) {
      return 'Sin notas';
    }

    return value;
  }

  static String _humanizeStatus(String status) {
    switch (status) {
      case 'inicio':
        return 'Inicio';
      case 'cotizado':
        return 'Cotizado';
      case 'solicitado':
        return 'Solicitado';
      case 'confirmado':
        return 'Confirmado';
      case 'en_proceso':
        return 'En proceso';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      case 'pendiente':
        return 'Pendiente';
      default:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }
}
