class CommissionPolicy {
  final String id;
  final String commissionType;
  final double commissionPercentage;
  final double fixedCommissionAmount;
  final bool appliesAfterDiscount;
  final String notes;

  /// Cuándo la aprobó alguien a propósito. `null` quiere decir que sigue
  /// siendo **el 40% por defecto que nadie miró** (hallazgo AJ).
  ///
  /// Se guarda la fecha y no un `bool` para poder decirle al dueño *cuándo*
  /// la confirmó: una cifra aprobada hace un año no es lo mismo que una
  /// aprobada ayer, y él sabrá si le sirve.
  final DateTime? confirmedAt;

  const CommissionPolicy({
    required this.id,
    required this.commissionType,
    required this.commissionPercentage,
    required this.fixedCommissionAmount,
    required this.appliesAfterDiscount,
    required this.notes,
    this.confirmedAt,
  });

  /// **Lo que decide si se avisa.** Nace en `false` para todo el mundo: en la
  /// base había 3 políticas, las 3 en el 40%, y **ninguna tocada desde que
  /// nació**.
  bool get confirmada => confirmedAt != null;

  factory CommissionPolicy.fromMap(Map<String, dynamic> map) {
    return CommissionPolicy(
      id: map['id']?.toString() ?? '',
      commissionType: map['commission_type']?.toString() ?? 'percentage',
      commissionPercentage: _readDouble(map['commission_percentage']),
      fixedCommissionAmount: _readDouble(map['fixed_commission_amount']),
      appliesAfterDiscount: map['applies_after_discount'] == true,
      notes: map['notes']?.toString() ?? 'Sin notas',
      confirmedAt: _readDate(map['confirmed_at']),
    );
  }

  /// Ante una fecha que no se entiende devuelve `null`, o sea **sin
  /// confirmar**. Es el lado seguro: se avisa de más, no de menos.
  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
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
