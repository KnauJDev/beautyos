class CommissionPolicy {
  final String id;
  final String commissionType;
  final double commissionPercentage;
  final double fixedCommissionAmount;
  final bool appliesAfterDiscount;
  final String notes;

  const CommissionPolicy({
    required this.id,
    required this.commissionType,
    required this.commissionPercentage,
    required this.fixedCommissionAmount,
    required this.appliesAfterDiscount,
    required this.notes,
  });

  factory CommissionPolicy.fromMap(Map<String, dynamic> map) {
    return CommissionPolicy(
      id: map['id']?.toString() ?? '',
      commissionType: map['commission_type']?.toString() ?? 'percentage',
      commissionPercentage: _readDouble(map['commission_percentage']),
      fixedCommissionAmount: _readDouble(map['fixed_commission_amount']),
      appliesAfterDiscount: map['applies_after_discount'] == true,
      notes: map['notes']?.toString() ?? 'Sin notas',
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get commissionTypeText {
    if (commissionType == 'fixed') {
      return 'Valor fijo';
    }

    return 'Porcentaje';
  }

  String get commissionValueText {
    if (commissionType == 'fixed') {
      return '\$${fixedCommissionAmount.toStringAsFixed(0)} por servicio';
    }

    return '${commissionPercentage.toStringAsFixed(0)}% del servicio';
  }

  String get discountText {
    return appliesAfterDiscount
        ? 'Se calcula después de descuentos'
        : 'Se calcula antes de descuentos';
  }
}
