class PlatformTenantSummary {
  const PlatformTenantSummary({
    required this.tenantId,
    required this.tenantName,
    this.contactName,
    this.businessType,
    this.city,
    this.estimatedBranches = 1,
    this.estimatedTeamSize = 1,
    this.referralSource,
    this.rejectionReason,
    required this.contactEmail,
    this.contactPhone,
    required this.whatsapp,
    this.instagram,
    this.facebook,
    this.realBranchesCount = 0,
    this.realTeamCount = 0,
    this.teamBreakdown,
    required this.tenantActive,
    required this.isDemo,
    required this.planCode,
    required this.subscriptionStatus,
    this.isFounder = false,
    this.priceCop,
    this.discountPercent,
    required this.trialEndsAt,
    required this.currentPeriodEnd,
    required this.graceEndsAt,
    required this.createdAt,
  });

  final String tenantId;
  final String tenantName;

  /// Nombre real del titular (user_profiles.full_name del owner). Null si el
  /// negocio todavía no tiene un owner con perfil activo.
  final String? contactName;
  final String? businessType;
  final String? city;
  final int estimatedBranches;
  final int estimatedTeamSize;
  final String? referralSource;
  final String? rejectionReason;
  final String contactEmail;
  final String? contactPhone;
  final String? whatsapp;
  final String? instagram;
  final String? facebook;

  /// Sedes activas contadas en vivo desde `branches` (D-162), no lo que el
  /// negocio declaró al registrarse (`estimatedBranches`).
  final int realBranchesCount;

  /// Equipo activo contado en vivo desde `user_profiles` (D-162), no lo
  /// declarado al registrarse (`estimatedTeamSize`).
  final int realTeamCount;

  /// Desglose por rol ya formateado por la RPC, ej. "1 dueño, 2 admins, 3
  /// estilistas". Null solo si la RPC vieja todavía no lo envía.
  final String? teamBreakdown;

  final bool tenantActive;

  /// Negocio de prueba del propietario de la plataforma, no un cliente
  /// real (D-112). Es una etiqueta: no restringe nada, solo evita que se
  /// cuente como cliente al mirar cualquier cifra.
  final bool isDemo;
  final String? planCode;
  final String? subscriptionStatus;
  final bool isFounder;
  final int? priceCop;
  final double? discountPercent;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? graceEndsAt;
  final DateTime? createdAt;

  bool get isPending => subscriptionStatus == 'pending';
  bool get isTrialing => subscriptionStatus == 'trialing';
  bool get isActive => subscriptionStatus == 'active';
  bool get isRejected => subscriptionStatus == 'rejected';
  bool get isGrace => subscriptionStatus == 'grace';
  bool get isPastDue => subscriptionStatus == 'past_due';
  bool get isSuspended => subscriptionStatus == 'suspended';
  bool get isCancelled => subscriptionStatus == 'cancelled';

  String get planNameFormatted {
    switch (planCode?.toLowerCase()) {
      case 'basico':
        return 'Básico';
      case 'business':
        return 'Business';
      case 'profesional':
        return 'Profesional';
      default:
        return planCode ?? 'Profesional';
    }
  }

  int get effectivePriceCop {
    if (priceCop != null && priceCop! > 0) {
      return priceCop!;
    }
    int basePrice = 240000;
    if (planCode == 'basico') basePrice = 160000;
    if (planCode == 'business') basePrice = 200000;

    if (isFounder) {
      return (basePrice * 0.5).round();
    }
    if (discountPercent != null && discountPercent! > 0) {
      return (basePrice * (1.0 - (discountPercent! / 100.0))).round();
    }
    return basePrice;
  }

  String get formattedEffectivePrice {
    final price = effectivePriceCop;
    final digits = price.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final pos = digits.length - i;
      buffer.write(digits[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write('.');
      }
    }
    return '\$$buffer COP/mes';
  }

  factory PlatformTenantSummary.fromMap(Map<String, dynamic> map) {
    return PlatformTenantSummary(
      tenantId: map['tenant_id'].toString(),
      tenantName: map['tenant_name']?.toString() ?? 'Sin nombre',
      contactName: map['contact_name']?.toString(),
      businessType: map['business_type']?.toString(),
      city: map['city']?.toString(),
      estimatedBranches: _parseInt(map['estimated_branches']) ?? 1,
      estimatedTeamSize: _parseInt(map['estimated_team_size']) ?? 1,
      referralSource: map['referral_source']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      contactEmail: map['contact_email']?.toString() ?? '',
      contactPhone: map['contact_phone']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      instagram: map['instagram']?.toString(),
      facebook: map['facebook']?.toString(),
      realBranchesCount: _parseInt(map['real_branches_count']) ?? 0,
      realTeamCount: _parseInt(map['real_team_count']) ?? 0,
      teamBreakdown: map['team_breakdown']?.toString(),
      tenantActive: map['tenant_active'] == true,
      isDemo: map['is_demo'] == true,
      planCode: map['plan_code']?.toString(),
      subscriptionStatus: map['subscription_status']?.toString(),
      isFounder: map['is_founder'] == true,
      priceCop: _parseInt(map['price_cop']),
      discountPercent: _parseDouble(map['discount_percent']),
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
