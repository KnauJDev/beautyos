class ExpenseManagementItem {
  const ExpenseManagementItem({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
    required this.active,
  });

  final String id;
  final String expenseDate;
  final String category;
  final String description;
  final num amount;
  final String paymentMethod;
  final String? notes;
  final bool active;

  factory ExpenseManagementItem.fromMap(Map<String, dynamic> map) {
    return ExpenseManagementItem(
      id: map['expense_id'].toString(),
      expenseDate: map['expense_date']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Sin categoría',
      description: map['description']?.toString() ?? '',
      amount: map['amount'] as num? ?? 0,
      paymentMethod: map['payment_method']?.toString() ?? 'cash',
      notes: map['notes']?.toString(),
      active: map['active'] == true,
    );
  }

  String get formattedAmount => _formatCop(amount);

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

  String get notesText {
    if (notes == null || notes!.trim().isEmpty) {
      return 'Sin notas';
    }

    return notes!;
  }

  String get expenseDateText {
    final parsedDate = DateTime.tryParse(expenseDate);

    if (parsedDate == null) {
      return expenseDate;
    }

    final day = parsedDate.day.toString().padLeft(2, '0');
    final month = parsedDate.month.toString().padLeft(2, '0');
    final year = parsedDate.year.toString();

    return '$day/$month/$year';
  }

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
