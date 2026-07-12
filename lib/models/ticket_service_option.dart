class TicketServiceOption {
  const TicketServiceOption({
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.stylistId,
    required this.stylistName,
  });

  final String serviceId;
  final String serviceName;
  final String category;
  final num price;
  final int durationMinutes;
  final String? stylistId;
  final String? stylistName;

  factory TicketServiceOption.fromMap(Map<String, dynamic> map) {
    return TicketServiceOption(
      serviceId: map['service_id'].toString(),
      serviceName: map['service_name']?.toString() ?? 'Sin servicio',
      category: map['category']?.toString() ?? 'Sin categoría',
      price: _readNumber(map['price']),
      durationMinutes: _readInt(map['duration_minutes']),
      stylistId: map['stylist_id']?.toString(),
      stylistName: map['stylist_name']?.toString(),
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
    final value = price.toInt().toString();
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
}
