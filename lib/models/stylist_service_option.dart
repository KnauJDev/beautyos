class StylistServiceOption {
  const StylistServiceOption({
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.assigned,
  });

  final String serviceId;
  final String serviceName;
  final String category;
  final num price;
  final int durationMinutes;
  final bool assigned;

  factory StylistServiceOption.fromMap(Map<String, dynamic> map) {
    return StylistServiceOption(
      serviceId: map['service_id'].toString(),
      serviceName: map['service_name']?.toString() ?? 'Sin servicio',
      category: map['category']?.toString() ?? 'Sin categoria',
      price: _readNumber(map['price']),
      durationMinutes: _readInt(map['duration_minutes']),
      assigned: map['assigned'] as bool? ?? false,
    );
  }

  static num _readNumber(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get formattedPrice {
    final value = price.toInt().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < value.length; index++) {
      final positionFromEnd = value.length - index;
      buffer.write(value[index]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }
}
