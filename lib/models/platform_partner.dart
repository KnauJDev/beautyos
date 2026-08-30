// Partners y Referidos (D-173, paso 7.3): un salón aliado o una persona
// externa que trae clientes nuevos y gana comisión cuando ese salón paga.

String partnerPayoutChannelLabel(String? channel) {
  switch (channel) {
    case 'bre_b':
      return 'Llave Bre-B';
    case 'daviplata':
      return 'Daviplata';
    case 'nequi':
      return 'Nequi';
    case 'bancolombia':
      return 'Bancolombia';
    case 'otro':
      return 'Otro';
    default:
      return channel ?? 'Sin definir';
  }
}

String partnerCommissionDurationLabel(String? duration) {
  switch (duration) {
    case 'first_payment_only':
      return 'Solo el primer pago';
    case 'first_n_months':
      return 'Primeros meses';
    case 'recurring_lifetime':
      return 'Recurrente, mientras pague';
    default:
      return duration ?? 'Sin definir';
  }
}

String _formatCop(int cop) {
  final digits = cop.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final pos = digits.length - i;
    buffer.write(digits[i]);
    if (pos > 1 && pos % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$$buffer COP';
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class PlatformPartner {
  const PlatformPartner({
    required this.partnerId,
    required this.fullName,
    this.documentId,
    required this.referralCode,
    this.phone,
    this.whatsapp,
    this.email,
    required this.payoutChannel,
    required this.payoutAccount,
    required this.commissionType,
    required this.commissionValue,
    required this.commissionDuration,
    this.durationMonths,
    required this.active,
    this.notes,
    required this.createdAt,
    this.linkedTenantsCount = 0,
    this.pendingCommissionsCop = 0,
    this.paidCommissionsCop = 0,
  });

  final String partnerId;
  final String fullName;
  final String? documentId;
  final String referralCode;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String payoutChannel;
  final String payoutAccount;
  final String commissionType;
  final double commissionValue;
  final String commissionDuration;
  final int? durationMonths;
  final bool active;
  final String? notes;
  final DateTime? createdAt;
  final int linkedTenantsCount;
  final int pendingCommissionsCop;
  final int paidCommissionsCop;

  String get payoutChannelLabel => partnerPayoutChannelLabel(payoutChannel);

  String get commissionLabel {
    final esEntero = commissionValue == commissionValue.roundToDouble();
    final valor = commissionType == 'percentage'
        ? '${esEntero ? commissionValue.toStringAsFixed(0) : commissionValue.toStringAsFixed(1)}%'
        : _formatCop(commissionValue.round());
    final duracion =
        commissionDuration == 'first_n_months' && durationMonths != null
        ? 'primeros $durationMonths ${durationMonths == 1 ? "mes" : "meses"}'
        : partnerCommissionDurationLabel(commissionDuration).toLowerCase();
    return '$valor · $duracion';
  }

  String get formattedPending => _formatCop(pendingCommissionsCop);
  String get formattedPaid => _formatCop(paidCommissionsCop);

  /// `salonymas.com/?ref=CODIGO`, para compartir por WhatsApp.
  String referralLink(String origin) => '$origin/?ref=$referralCode';

  factory PlatformPartner.fromMap(Map<String, dynamic> map) {
    return PlatformPartner(
      partnerId: map['partner_id'].toString(),
      fullName: map['full_name']?.toString() ?? 'Sin nombre',
      documentId: map['document_id']?.toString(),
      referralCode: map['referral_code']?.toString() ?? '',
      phone: map['phone']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      email: map['email']?.toString(),
      payoutChannel: map['payout_channel']?.toString() ?? 'bre_b',
      payoutAccount: map['payout_account']?.toString() ?? '',
      commissionType: map['commission_type']?.toString() ?? 'percentage',
      commissionValue: _parseDouble(map['commission_value']) ?? 0,
      commissionDuration:
          map['commission_duration']?.toString() ?? 'first_payment_only',
      durationMonths: _parseInt(map['duration_months']),
      active: map['active'] == true,
      notes: map['notes']?.toString(),
      createdAt: _parseDate(map['created_at']),
      linkedTenantsCount: _parseInt(map['linked_tenants_count']) ?? 0,
      pendingCommissionsCop: _parseInt(map['pending_commissions_cop']) ?? 0,
      paidCommissionsCop: _parseInt(map['paid_commissions_cop']) ?? 0,
    );
  }
}

class PlatformPartnerLinkedTenant {
  const PlatformPartnerLinkedTenant({
    required this.tenantId,
    required this.tenantName,
    this.subscriptionStatus,
    this.linkedSince,
  });

  final String tenantId;
  final String tenantName;
  final String? subscriptionStatus;
  final DateTime? linkedSince;

  factory PlatformPartnerLinkedTenant.fromMap(Map<String, dynamic> map) {
    return PlatformPartnerLinkedTenant(
      tenantId: map['tenant_id'].toString(),
      tenantName: map['tenant_name']?.toString() ?? 'Sin nombre',
      subscriptionStatus: map['subscription_status']?.toString(),
      linkedSince: _parseDate(map['linked_since']),
    );
  }
}

class PlatformPartnerCommission {
  const PlatformPartnerCommission({
    required this.commissionId,
    required this.tenantId,
    required this.tenantName,
    required this.amountCop,
    required this.paymentEventAmountCop,
    required this.status,
    this.createdAt,
    this.paidAt,
    this.payoutMethod,
    this.payoutReference,
    this.payoutNotes,
  });

  final String commissionId;
  final String tenantId;
  final String tenantName;
  final int amountCop;
  final int paymentEventAmountCop;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? payoutMethod;
  final String? payoutReference;
  final String? payoutNotes;

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';

  String get formattedAmount => _formatCop(amountCop);

  factory PlatformPartnerCommission.fromMap(Map<String, dynamic> map) {
    return PlatformPartnerCommission(
      commissionId: map['commission_id'].toString(),
      tenantId: map['tenant_id'].toString(),
      tenantName: map['tenant_name']?.toString() ?? 'Sin nombre',
      amountCop: _parseInt(map['amount_cop']) ?? 0,
      paymentEventAmountCop: _parseInt(map['payment_event_amount_cop']) ?? 0,
      status: map['status']?.toString() ?? 'pending',
      createdAt: _parseDate(map['created_at']),
      paidAt: _parseDate(map['paid_at']),
      payoutMethod: map['payout_method']?.toString(),
      payoutReference: map['payout_reference']?.toString(),
      payoutNotes: map['payout_notes']?.toString(),
    );
  }
}

class PlatformPartnerDetail {
  const PlatformPartnerDetail({
    required this.partner,
    required this.linkedTenants,
    required this.commissions,
  });

  final PlatformPartner partner;
  final List<PlatformPartnerLinkedTenant> linkedTenants;
  final List<PlatformPartnerCommission> commissions;

  int get pendingCommissionsCop => commissions
      .where((c) => c.isPending)
      .fold(0, (sum, c) => sum + c.amountCop);

  factory PlatformPartnerDetail.fromMap(Map<String, dynamic> map) {
    final linked = (map['linked_tenants'] as List? ?? const [])
        .map(
          (e) => PlatformPartnerLinkedTenant.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    final commissions = (map['commissions'] as List? ?? const [])
        .map(
          (e) => PlatformPartnerCommission.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    return PlatformPartnerDetail(
      partner: PlatformPartner.fromMap(map),
      linkedTenants: linked,
      commissions: commissions,
    );
  }
}

class PlatformPartnersSummary {
  const PlatformPartnersSummary({
    required this.activePartnersCount,
    required this.linkedTenantsCount,
    required this.pendingCommissionsCop,
    required this.paidCommissionsCop,
  });

  final int activePartnersCount;
  final int linkedTenantsCount;
  final int pendingCommissionsCop;
  final int paidCommissionsCop;

  static const empty = PlatformPartnersSummary(
    activePartnersCount: 0,
    linkedTenantsCount: 0,
    pendingCommissionsCop: 0,
    paidCommissionsCop: 0,
  );

  String get formattedPending => _formatCop(pendingCommissionsCop);
  String get formattedPaid => _formatCop(paidCommissionsCop);

  factory PlatformPartnersSummary.fromMap(Map<String, dynamic> map) {
    return PlatformPartnersSummary(
      activePartnersCount: _parseInt(map['active_partners_count']) ?? 0,
      linkedTenantsCount: _parseInt(map['linked_tenants_count']) ?? 0,
      pendingCommissionsCop: _parseInt(map['pending_commissions_cop']) ?? 0,
      paidCommissionsCop: _parseInt(map['paid_commissions_cop']) ?? 0,
    );
  }
}

class PlatformPartnerSettlementResult {
  const PlatformPartnerSettlementResult({
    required this.settledCount,
    required this.settledAmountCop,
  });

  final int settledCount;
  final int settledAmountCop;

  String get formattedAmount => _formatCop(settledAmountCop);

  factory PlatformPartnerSettlementResult.fromMap(Map<String, dynamic> map) {
    return PlatformPartnerSettlementResult(
      settledCount: _parseInt(map['settled_count']) ?? 0,
      settledAmountCop: _parseInt(map['settled_amount_cop']) ?? 0,
    );
  }
}

class PublicPartnerRegistrationResult {
  const PublicPartnerRegistrationResult({
    required this.partnerId,
    required this.referralCode,
  });

  final String partnerId;
  final String referralCode;

  factory PublicPartnerRegistrationResult.fromMap(Map<String, dynamic> map) {
    return PublicPartnerRegistrationResult(
      partnerId: map['partner_id'].toString(),
      referralCode: map['referral_code']?.toString() ?? '',
    );
  }
}
