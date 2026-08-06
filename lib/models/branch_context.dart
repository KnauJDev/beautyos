class BranchContext {
  const BranchContext({
    required this.tenantId,
    required this.tenantName,
    this.tenantLogoUrl,
    required this.branchId,
    required this.branchName,
    required this.branchSlug,
    required this.role,
    required this.stylistId,
    required this.timezone,
    required this.currencyCode,
    required this.isPrimary,
    required this.optionCount,
  });

  final String tenantId;
  final String tenantName;
  final String? tenantLogoUrl;
  final String branchId;
  final String branchName;
  final String? branchSlug;
  final String role;
  final String? stylistId;
  final String timezone;
  final String currencyCode;
  final bool isPrimary;
  final int optionCount;

  factory BranchContext.fromMap(Map<String, dynamic> map) {
    return BranchContext(
      tenantId: _requiredString(map, 'tenant_id'),
      tenantName: map['tenant_name']?.toString() ?? 'Negocio sin nombre',
      tenantLogoUrl: map['tenant_logo_url']?.toString(),
      branchId: _requiredString(map, 'branch_id'),
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

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString();
    if (value == null || value.isEmpty) {
      throw StateError('La sede autorizada no tiene $key.');
    }
    return value;
  }
}
