class StylistCommissionOverride {
  const StylistCommissionOverride({
    required this.serviceId,
    required this.serviceName,
    this.overrideId,
    this.commissionType,
    this.commissionPercentage,
    this.fixedCommissionAmount,
  });

  final String serviceId;
  final String serviceName;
  final String? overrideId;
  final String? commissionType;
  final num? commissionPercentage;
  final num? fixedCommissionAmount;

  bool get hasOverride => overrideId != null;

  factory StylistCommissionOverride.fromMap(Map<String, dynamic> map) {
    return StylistCommissionOverride(
      serviceId: map['service_id'].toString(),
      serviceName: map['service_name']?.toString() ?? 'Servicio',
      overrideId: map['override_id']?.toString(),
      commissionType: map['commission_type']?.toString(),
      commissionPercentage: map['commission_percentage'] as num?,
      fixedCommissionAmount: map['fixed_commission_amount'] as num?,
    );
  }
}
