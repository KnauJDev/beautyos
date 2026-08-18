String formatUnitQuantity(num quantity, String unit) {
  final cleanUnit = unit.trim();
  final formattedNumber =
      quantity == quantity.toInt() ? quantity.toInt().toString() : quantity.toString();
  if (cleanUnit.toLowerCase() == 'unidad' || cleanUnit.toLowerCase() == 'unidades') {
    return quantity == 1 ? '$formattedNumber unidad' : '$formattedNumber unidades';
  }
  return '$formattedNumber $cleanUnit';
}

class ProductManagementItem {
  const ProductManagementItem({
    required this.id,
    required this.name,
    required this.category,
    this.brand,
    required this.productType,
    required this.unit,
    required this.sku,
    required this.currentStock,
    required this.minimumStock,
    required this.purchasePrice,
    required this.salePrice,
    required this.visibleForSale,
    required this.active,
  });

  final String id;
  final String name;
  final String category;
  final String? brand;
  final String productType;
  final String unit;
  final String? sku;
  final num currentStock;
  final num minimumStock;
  final num purchasePrice;
  final num salePrice;
  final bool visibleForSale;
  final bool active;

  factory ProductManagementItem.fromMap(Map<String, dynamic> map) {
    return ProductManagementItem(
      id: map['product_id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      category: map['category']?.toString() ?? 'Sin categoría',
      brand: map['brand']?.toString(),
      productType: map['product_type']?.toString() ?? 'consumable',
      unit: map['unit']?.toString() ?? 'unidad',
      sku: map['sku']?.toString(),
      currentStock: map['current_stock'] as num? ?? 0,
      minimumStock: map['minimum_stock'] as num? ?? 0,
      purchasePrice: map['purchase_price'] as num? ?? 0,
      salePrice: map['sale_price'] as num? ?? 0,
      visibleForSale: map['visible_for_sale'] == true,
      active: map['active'] == true,
    );
  }

  bool get isLowStock => currentStock <= minimumStock;

  String get productTypeText {
    return productType == 'sale' ? 'Producto para venta' : 'Insumo interno';
  }

  String get stockText => formatUnitQuantity(currentStock, unit);

  String get minimumStockText => formatUnitQuantity(minimumStock, unit);

  String get formattedPurchasePrice => _formatCop(purchasePrice);

  String get formattedSalePrice => _formatCop(salePrice);

  static String _formatCop(num value) {
    final digits = value.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final positionFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }
}
