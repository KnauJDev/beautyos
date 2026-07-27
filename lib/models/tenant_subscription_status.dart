class TenantSubscriptionStatus {
  const TenantSubscriptionStatus({
    required this.planCode,
    required this.planName,
    required this.status,
    required this.trialEndsAt,
    required this.currentPeriodEnd,
    required this.graceEndsAt,
  });

  final String planCode;
  final String planName;
  final String status;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? graceEndsAt;

  factory TenantSubscriptionStatus.fromMap(Map<String, dynamic> map) {
    return TenantSubscriptionStatus(
      planCode: map['plan_code']?.toString() ?? '',
      planName: map['plan_name']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      trialEndsAt: map['trial_ends_at'] == null
          ? null
          : DateTime.tryParse(map['trial_ends_at'].toString())?.toLocal(),
      currentPeriodEnd: map['current_period_end'] == null
          ? null
          : DateTime.tryParse(
              map['current_period_end'].toString(),
            )?.toLocal(),
      graceEndsAt: map['grace_ends_at'] == null
          ? null
          : DateTime.tryParse(map['grace_ends_at'].toString())?.toLocal(),
    );
  }

  /// Días restantes de prueba gratis (negativo si ya venció). Null si no
  /// aplica (no está en prueba o no tiene fecha de fin).
  int? get trialDaysRemaining {
    final endsAt = trialEndsAt;

    if (status != 'trialing' || endsAt == null) {
      return null;
    }

    return endsAt.difference(DateTime.now()).inHours ~/ 24;
  }

  bool get isTrialExpired {
    final remaining = trialDaysRemaining;
    return remaining != null && remaining < 0;
  }
}
