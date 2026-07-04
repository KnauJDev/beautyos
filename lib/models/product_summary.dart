class ProductSummary {
  final String id;
  final String name;
  final String category;
  final String productType;
  final String unit;
  final double currentStock;
  final double minimumStock;
  final double purchasePrice;
  final double salePrice;
  final bool visibleForSale;

  const ProductSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.productType,
    required this.unit,
    required this.currentStock,
    required this.minimumStock,
    required this.purchasePrice,
    required this.salePrice,
    required this.visibleForSale,
  });

  factory ProductSummary.fromMap(Map<String, dynamic> map) {
    return ProductSummary(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sin nombre',
      category: map['category']?.toString() ?? 'Sin categoría',
      productType: map['product_type']?.toString() ?? 'consumable',
      unit: map['unit']?.toString() ?? 'unidad',
      currentStock: _readDouble(map['current_stock']),
      minimumStock: _readDouble(map['minimum_stock']),
      purchasePrice: _readDouble(map['purchase_price']),
      salePrice: _readDouble(map['sale_price']),
      visibleForSale: map['visible_for_sale'] == true,
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get productTypeText {
    if (productType == 'sale') {
      return 'Producto para venta';
    }

    return 'Insumo interno';
  }

  String get stockText {
    return '${currentStock.toStringAsFixed(0)} $unit';
  }

  String get minimumStockText {
    return '${minimumStock.toStringAsFixed(0)} $unit';
  }

  String get formattedPurchasePrice {
    return '\$${purchasePrice.toStringAsFixed(0)}';
  }

  String get formattedSalePrice {
    return '\$${salePrice.toStringAsFixed(0)}';
  }

  bool get isLowStock {
    return currentStock <= minimumStock;
  }

  String get stockStatusText {
    if (isLowStock) {
      return 'Stock bajo';
    }

    return 'Stock suficiente';
  }
}
