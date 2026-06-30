class BeautyService {
  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final num price;

  const BeautyService({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
  });

  factory BeautyService.fromMap(Map<String, dynamic> map) {
    return BeautyService(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      category: map['category']?.toString() ?? 'Sin categor\u00eda',
      durationMinutes: map['duration_minutes'] as int? ?? 0,
      price: map['price'] as num? ?? 0,
    );
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
