class InventoryMovementSummary {
  final String id;
  final String productName;
  final String productCategory;
  final String movementType;
  final double quantity;
  final String unit;
  final double unitCost;
  final String notes;
  final String createdAt;

  const InventoryMovementSummary({
    required this.id,
    required this.productName,
    required this.productCategory,
    required this.movementType,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.notes,
    required this.createdAt,
  });

  factory InventoryMovementSummary.fromMap(Map<String, dynamic> map) {
    return InventoryMovementSummary(
      id: map['id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Sin producto',
      productCategory: map['product_category']?.toString() ?? 'Sin categoría',
      movementType: map['movement_type']?.toString() ?? 'adjustment',
      quantity: _readDouble(map['quantity']),
      unit: map['unit']?.toString() ?? 'unidad',
      unitCost: _readDouble(map['unit_cost']),
      notes: map['notes']?.toString() ?? 'Sin notas',
      createdAt: map['created_at']?.toString() ?? '',
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get movementTypeText {
    switch (movementType) {
      case 'purchase':
        return 'Compra / entrada';
      case 'consumption':
        return 'Consumo interno';
      case 'sale':
        return 'Venta';
      case 'gift':
        return 'Obsequio';
      case 'package':
        return 'Paquete / promoción';
      case 'adjustment':
        return 'Ajuste manual';
      default:
        return 'Movimiento';
    }
  }

  String get quantityText {
    return '${quantity.toStringAsFixed(0)} $unit';
  }

  String get formattedUnitCost {
    return '\$${unitCost.toStringAsFixed(0)}';
  }

  String get createdDateText {
    final parsedDate = DateTime.tryParse(createdAt);

    if (parsedDate == null) {
      return 'Sin fecha';
    }

    final localDate = parsedDate.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    return '$day/$month/$year';
  }
}
