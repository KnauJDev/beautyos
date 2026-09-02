import 'ticket_board.dart' show formatCOP;

class PurchaseManagementItem {
  const PurchaseManagementItem({
    required this.id,
    required this.supplierName,
    required this.purchaseDate,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.paymentMethod,
    required this.notes,
    required this.active,
  });

  final String id;
  final String supplierName;
  final String purchaseDate;
  final String? invoiceNumber;
  final num totalAmount;
  final String paymentMethod;
  final String? notes;
  final bool active;

  factory PurchaseManagementItem.fromMap(Map<String, dynamic> map) {
    return PurchaseManagementItem(
      id: map['purchase_id'].toString(),
      supplierName: map['supplier_name']?.toString() ?? 'Sin proveedor',
      purchaseDate: map['purchase_date']?.toString() ?? '',
      invoiceNumber: map['invoice_number']?.toString(),
      totalAmount: map['total_amount'] as num? ?? 0,
      paymentMethod: map['payment_method']?.toString() ?? 'cash',
      notes: map['notes']?.toString(),
      active: map['active'] == true,
    );
  }

  String get formattedTotalAmount => formatCOP(totalAmount);

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

  String get purchaseDateText {
    final parsedDate = DateTime.tryParse(purchaseDate);

    if (parsedDate == null) {
      return purchaseDate;
    }

    final day = parsedDate.day.toString().padLeft(2, '0');
    final month = parsedDate.month.toString().padLeft(2, '0');
    final year = parsedDate.year.toString();

    return '$day/$month/$year';
  }
}
