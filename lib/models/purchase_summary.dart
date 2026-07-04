class PurchaseSummary {
  final String id;
  final String supplierName;
  final String purchaseDate;
  final String? invoiceNumber;
  final double totalAmount;
  final String paymentMethod;
  final String? notes;

  const PurchaseSummary({
    required this.id,
    required this.supplierName,
    required this.purchaseDate,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.paymentMethod,
    required this.notes,
  });

  factory PurchaseSummary.fromMap(Map<String, dynamic> map) {
    return PurchaseSummary(
      id: map['id'] as String,
      supplierName: map['supplier_name'] as String,
      purchaseDate: map['purchase_date'] as String,
      invoiceNumber: map['invoice_number'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String?,
    );
  }

  String get formattedTotalAmount {
    return '\$${totalAmount.toStringAsFixed(0)}';
  }

  String get paymentMethodText {
    switch (paymentMethod) {
      case 'cash':
        return 'Efectivo';
      case 'transfer':
        return 'Transferencia';
      case 'card':
        return 'Tarjeta';
      case 'credit':
        return 'Crédito';
      case 'other':
        return 'Otro';
      default:
        return paymentMethod;
    }
  }

  String get invoiceText {
    if (invoiceNumber == null || invoiceNumber!.trim().isEmpty) {
      return 'Sin factura';
    }

    return invoiceNumber!;
  }

  String get notesText {
    if (notes == null || notes!.trim().isEmpty) {
      return 'Sin notas';
    }

    return notes!;
  }
}
