class ExpenseSummary {
  final String id;
  final String expenseDate;
  final String category;
  final String description;
  final double amount;
  final String paymentMethod;
  final String? notes;

  const ExpenseSummary({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
  });

  factory ExpenseSummary.fromMap(Map<String, dynamic> map) {
    return ExpenseSummary(
      id: map['id'] as String,
      expenseDate: map['expense_date'] as String,
      category: map['category'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String?,
    );
  }

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(0)}';
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
        return 'Cr\u00e9dito';
      case 'other':
        return 'Otro';
      default:
        return paymentMethod;
    }
  }

  String get notesText {
    if (notes == null || notes!.trim().isEmpty) {
      return 'Sin notas';
    }

    return notes!;
  }
}
