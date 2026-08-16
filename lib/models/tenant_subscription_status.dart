class TenantSubscriptionStatus {
  const TenantSubscriptionStatus({
    required this.tenantId,
    required this.tenantName,
    required this.subscriptionStatus,
    this.planCode,
    this.planName,
    this.trialEndsAt,
    this.isFounder = false,
    this.priceCop,
    this.discountPercent,
    this.rejectionReason,
    this.createdAt,
  });

  final String tenantId;
  final String tenantName;
  final String subscriptionStatus;
  final String? planCode;
  final String? planName;
  final DateTime? trialEndsAt;
  final bool isFounder;
  final int? priceCop;
  final double? discountPercent;
  final String? rejectionReason;
  final DateTime? createdAt;

  bool get isPending => subscriptionStatus == 'pending';
  bool get isTrialing => subscriptionStatus == 'trialing';
  bool get isActive => subscriptionStatus == 'active';
  bool get isRejected => subscriptionStatus == 'rejected';
  bool get isSuspended => subscriptionStatus == 'suspended';

  int? get trialDaysRemaining {
    if (trialEndsAt == null) return null;
    final now = DateTime.now();
    return trialEndsAt!.difference(now).inDays;
  }

  factory TenantSubscriptionStatus.fromMap(Map<String, dynamic> map) {
    return TenantSubscriptionStatus(
      tenantId: map['tenant_id']?.toString() ?? '',
      tenantName: map['tenant_name']?.toString() ?? 'Mi Negocio',
      subscriptionStatus: map['subscription_status']?.toString() ?? 'pending',
      planCode: map['plan_code']?.toString(),
      planName: map['plan_name']?.toString(),
      trialEndsAt: _parseDate(map['trial_ends_at']),
      isFounder: map['is_founder'] == true,
      priceCop: _parseInt(map['price_cop']),
      discountPercent: _parseDouble(map['discount_percent']),
      rejectionReason: map['rejection_reason']?.toString(),
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
