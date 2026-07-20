class BranchContext {
  const BranchContext({
    required this.tenantId,
    required this.tenantName,
    required this.branchId,
    required this.branchName,
    required this.branchSlug,
    required this.role,
    required this.stylistId,
    required this.timezone,
    required this.currencyCode,
    required this.isPrimary,
    required this.optionCount,
    this.isLegacyFallback = false,
  });

  final String? tenantId;
  final String tenantName;
  final String? branchId;
  final String branchName;
  final String? branchSlug;
  final String role;
  final String? stylistId;
  final String timezone;
  final String currencyCode;
  final bool isPrimary;
  final int optionCount;
  final bool isLegacyFallback;

  factory BranchContext.fromMap(Map<String, dynamic> map) {
    return BranchContext(
      tenantId: map['tenant_id']?.toString(),
      tenantName: map['tenant_name']?.toString() ?? 'Negocio BeautyOS',
      branchId: map['branch_id']?.toString(),
      branchName: map['branch_name']?.toString() ?? 'Sede',
      branchSlug: map['branch_slug']?.toString(),
      role: map['role']?.toString() ?? '',
      stylistId: map['stylist_id']?.toString(),
      timezone: map['timezone']?.toString() ?? 'America/Bogota',
      currencyCode: map['currency_code']?.toString() ?? 'COP',
      isPrimary: map['is_primary'] == true,
      optionCount: _readInt(map['option_count']),
    );
  }

  factory BranchContext.legacy({
    required String? tenantId,
    required String tenantName,
    required String role,
  }) {
    return BranchContext(
      tenantId: tenantId,
      tenantName: tenantName,
      branchId: null,
      branchName: 'Sede principal',
      branchSlug: null,
      role: role,
      stylistId: null,
      timezone: 'America/Bogota',
      currencyCode: 'COP',
      isPrimary: true,
      optionCount: 1,
      isLegacyFallback: true,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
