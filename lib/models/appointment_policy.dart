class AppointmentPolicy {
  final String id;
  final bool requiresDeposit;
  final double depositPercentage;
  final int cancellationHours;
  final int rescheduleHours;
  final bool manualConfirmationRequired;
  final bool customerRescheduleAllowed;

  const AppointmentPolicy({
    required this.id,
    required this.requiresDeposit,
    required this.depositPercentage,
    required this.cancellationHours,
    required this.rescheduleHours,
    required this.manualConfirmationRequired,
    required this.customerRescheduleAllowed,
  });

  factory AppointmentPolicy.fromMap(Map<String, dynamic> map) {
    return AppointmentPolicy(
      id: map['id']?.toString() ?? '',
      requiresDeposit: map['requires_deposit'] == true,
      depositPercentage: _readDouble(map['deposit_percentage']),
      cancellationHours: _readInt(map['cancellation_hours']),
      rescheduleHours: _readInt(map['reschedule_hours']),
      manualConfirmationRequired:
          map['manual_confirmation_required'] == true,
      customerRescheduleAllowed:
          map['customer_reschedule_allowed'] == true,
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get depositText {
    if (!requiresDeposit) {
      return 'No requiere anticipo';
    }

    return 'Requiere anticipo del ${depositPercentage.toStringAsFixed(0)}%';
  }

  String get cancellationText {
    return 'Cancelar con mínimo $cancellationHours horas de anticipación';
  }

  String get rescheduleText {
    return 'Reagendar con mínimo $rescheduleHours horas de anticipación';
  }

  String get manualConfirmationText {
    return manualConfirmationRequired
        ? 'Requiere confirmación manual'
        : 'No requiere confirmación manual';
  }

  String get customerRescheduleText {
    return customerRescheduleAllowed
        ? 'El cliente puede solicitar reagendamiento'
        : 'El cliente no puede reagendar directamente';
  }
}
