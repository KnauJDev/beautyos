class PurchaseItemSummary {
  final String id;
  final String purchaseId;
  final String supplierName;
  final String purchaseDate;
  final String? invoiceNumber;
  final String productName;
  final String productCategory;
  final double quantity;
  final String unit;
  final double unitCost;
  final double lineTotal;
  final String? notes;

  const PurchaseItemSummary({
    required this.id,
    required this.purchaseId,
    required this.supplierName,
    required this.purchaseDate,
    required this.invoiceNumber,
    required this.productName,
    required this.productCategory,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.lineTotal,
    required this.notes,
  });

  factory PurchaseItemSummary.fromMap(Map<String, dynamic> map) {
    return PurchaseItemSummary(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      supplierName: map['supplier_name'] as String,
      purchaseDate: map['purchase_date'] as String,
      invoiceNumber: map['invoice_number'] as String?,
      productName: map['product_name'] as String,
      productCategory: map['product_category'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      unitCost: (map['unit_cost'] as num).toDouble(),
      lineTotal: (map['line_total'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  String get invoiceText {
    if (invoiceNumber == null || invoiceNumber!.trim().isEmpty) {
      return 'Sin factura';
    }

    return invoiceNumber!;
  }

  String get quantityText {
    final cleanQuantity = quantity % 1 == 0
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);

    return '$cleanQuantity $unit';
  }

  String get formattedUnitCost {
    return '\$${unitCost.toStringAsFixed(0)}';
  }

  String get formattedLineTotal {
    return '\$${lineTotal.toStringAsFixed(0)}';
  }

  String get notesText {
    if (notes == null || notes!.trim().isEmpty) {
      return 'Sin notas';
    }

    return notes!;
  }
}
