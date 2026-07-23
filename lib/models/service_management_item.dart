class ServiceManagementItem {
  const ServiceManagementItem({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
    required this.visibleToCustomer,
    required this.active,
  });

  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final num price;
  final bool visibleToCustomer;
  final bool active;

  factory ServiceManagementItem.fromMap(Map<String, dynamic> map) {
    return ServiceManagementItem(
      id: map['service_id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      category: map['category']?.toString() ?? 'Sin categoría',
      durationMinutes: map['duration_minutes'] as int? ?? 0,
      price: map['price'] as num? ?? 0,
      visibleToCustomer: map['visible_to_customer'] == true,
      active: map['active'] == true,
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
