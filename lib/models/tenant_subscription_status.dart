class TenantSubscriptionStatus {
  const TenantSubscriptionStatus({
    required this.tenantId,
    required this.tenantName,
    required this.subscriptionStatus,
    this.planCode,
    this.planName,
    this.trialEndsAt,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.graceEndsAt,
    this.isFounder = false,
    this.priceCop,
    this.discountPercent,
    this.rejectionReason,
    this.createdAt,
    this.hasPactadoPrice = false,
    this.priceReason,
  });

  final String tenantId;
  final String tenantName;
  final String subscriptionStatus;
  final String? planCode;
  final String? planName;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? graceEndsAt;
  final bool isFounder;
  final int? priceCop;
  final double? discountPercent;
  final String? rejectionReason;
  final DateTime? createdAt;
  final bool hasPactadoPrice;
  final String? priceReason;

  bool get isPending => subscriptionStatus == 'pending';
  bool get isTrialing => subscriptionStatus == 'trialing';
  bool get isActive => subscriptionStatus == 'active';
  bool get isRejected => subscriptionStatus == 'rejected';
  bool get isSuspended => subscriptionStatus == 'suspended';
  bool get isPastDue => subscriptionStatus == 'past_due';
  bool get isGrace =>
      subscriptionStatus == 'grace' ||
      (subscriptionStatus == 'past_due' && isGracePeriodActive);

  bool get isGracePeriodActive =>
      graceEndsAt != null && graceEndsAt!.isAfter(DateTime.now());

  int? get trialDaysRemaining {
    if (trialEndsAt == null) return null;
    final diff = trialEndsAt!.difference(DateTime.now());
    if (diff.isNegative) return -1;
    return (diff.inHours / 24).ceil();
  }

  int? get graceDaysRemaining {
    if (graceEndsAt == null) return null;
    final diff = graceEndsAt!.difference(DateTime.now());
    if (diff.isNegative) return 0;
    final days = (diff.inHours / 24).ceil();
    return days <= 0 ? 1 : days;
  }

  int? get periodDaysRemaining {
    if (currentPeriodEnd == null) return null;
    final diff = currentPeriodEnd!.difference(DateTime.now());
    if (diff.isNegative) return -1;
    return (diff.inHours / 24).ceil();
  }

  String get formattedPrice {
    if (priceCop == null || priceCop == 0) return 'Sin costo';
    final str = priceCop.toString();
    final buffer = StringBuffer('\$');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    buffer.write(' COP / mes');
    return buffer.toString();
  }

  String get statusLabel {
    switch (subscriptionStatus) {
      case 'active':
        return 'Suscripción Activa';
      case 'trialing':
        return 'Prueba Gratis';
      case 'grace':
      case 'past_due':
        return isGracePeriodActive ? 'Periodo de Gracia' : 'En Mora';
      case 'suspended':
        return 'Suspendida';
      case 'rejected':
        return 'Solicitud No Aprobada';
      case 'pending':
        return 'En Revisión';
      default:
        return subscriptionStatus;
    }
  }

  factory TenantSubscriptionStatus.fromMap(Map<String, dynamic> map) {
    return TenantSubscriptionStatus(
      tenantId: map['tenant_id']?.toString() ?? '',
      tenantName: map['tenant_name']?.toString() ?? 'Mi Negocio',
      subscriptionStatus: map['subscription_status']?.toString() ?? 'pending',
      planCode: map['plan_code']?.toString(),
      planName: map['plan_name']?.toString(),
      trialEndsAt: _parseDate(map['trial_ends_at']),
      currentPeriodStart: _parseDate(map['current_period_start']),
      currentPeriodEnd: _parseDate(map['current_period_end']),
      graceEndsAt: _parseDate(map['grace_ends_at']),
      isFounder: map['is_founder'] == true,
      priceCop: _parseInt(map['price_cop']),
      discountPercent: _parseDouble(map['discount_percent']),
      rejectionReason: map['rejection_reason']?.toString(),
      createdAt: _parseDate(map['created_at']),
      hasPactadoPrice: map['has_pactado_price'] == true,
      priceReason: map['price_reason']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return num.tryParse(value.toString())?.toInt();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
