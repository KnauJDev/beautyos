class StylistServiceSummary {
  final String id;
  final String stylistName;
  final String serviceName;
  final String category;
  final num price;
  final int durationMinutes;
  final bool active;

  const StylistServiceSummary({
    required this.id,
    required this.stylistName,
    required this.serviceName,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.active,
  });

  factory StylistServiceSummary.fromMap(Map<String, dynamic> map) {
    return StylistServiceSummary(
      id: map['id'].toString(),
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      serviceName: map['service_name']?.toString() ?? 'Sin servicio',
      category: map['category']?.toString() ?? 'Sin categoría',
      price: _readNumber(map['price']),
      durationMinutes: _readInt(map['duration_minutes']),
      active: map['active'] as bool? ?? false,
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
