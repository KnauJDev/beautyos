import 'ticket_board.dart' show formatCOP;

/// Un servicio del catálogo público de un negocio (D-165).
class PublicSalonServiceItem {
  const PublicSalonServiceItem({
    required this.id,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.priceCop,
  });

  final String id;
  final String name;

  /// Viaja como `category` desde la base -- `services` no tiene una
  /// descripción propia (D-165).
  final String? description;

  final int durationMinutes;
  final num priceCop;

  factory PublicSalonServiceItem.fromMap(Map<String, dynamic> map) {
    return PublicSalonServiceItem(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Servicio',
      description: map['description']?.toString(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 0,
      priceCop: (map['price_cop'] as num?) ?? 0,
    );
  }

  String get durationLabel => '$durationMinutes min';

  String get priceLabel => formatCOP(priceCop);
}
