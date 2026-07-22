class PlatformTenantSummary {
  const PlatformTenantSummary({
    required this.tenantId,
    required this.tenantName,
    required this.contactEmail,
    required this.whatsapp,
    required this.tenantActive,
    required this.planCode,
    required this.subscriptionStatus,
    required this.trialEndsAt,
    required this.currentPeriodEnd,
    required this.graceEndsAt,
    required this.createdAt,
  });

  final String tenantId;
  final String tenantName;
  final String contactEmail;
  final String? whatsapp;
  final bool tenantActive;
  final String? planCode;
  final String? subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? graceEndsAt;
  final DateTime? createdAt;

  factory PlatformTenantSummary.fromMap(Map<String, dynamic> map) {
    return PlatformTenantSummary(
      tenantId: map['tenant_id'].toString(),
      tenantName: map['tenant_name']?.toString() ?? 'Sin nombre',
      contactEmail: map['contact_email']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString(),
      tenantActive: map['tenant_active'] == true,
      planCode: map['plan_code']?.toString(),
      subscriptionStatus: map['subscription_status']?.toString(),
      trialEndsAt: _parseDate(map['trial_ends_at']),
      currentPeriodEnd: _parseDate(map['current_period_end']),
      graceEndsAt: _parseDate(map['grace_ends_at']),
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
