/// Una excepción de límite/funcionalidad concedida a un salón (D-172, paso
/// 7.2). Mapea `public.platform_get_tenant_feature_overrides`.
class PlatformTenantFeatureOverride {
  const PlatformTenantFeatureOverride({
    required this.overrideId,
    required this.featureKey,
    required this.featureName,
    this.featureDescription,
    required this.enabled,
    this.limitValue,
    required this.reason,
    required this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.isActive,
  });

  final String overrideId;
  final String featureKey;
  final String featureName;
  final String? featureDescription;
  final bool enabled;

  /// Nulo = sin límite (D-136).
  final int? limitValue;
  final String reason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final bool isActive;

  factory PlatformTenantFeatureOverride.fromMap(Map<String, dynamic> map) {
    return PlatformTenantFeatureOverride(
      overrideId: map['override_id'].toString(),
      featureKey: map['feature_key']?.toString() ?? '',
      featureName: map['feature_name']?.toString() ?? '',
      featureDescription: map['feature_description']?.toString(),
      enabled: map['enabled'] == true,
      limitValue: _parseInt(map['limit_value']),
      reason: map['reason']?.toString() ?? '',
      startsAt: _parseDate(map['starts_at']),
      endsAt: _parseDate(map['ends_at']),
      createdAt: _parseDate(map['created_at']),
      isActive: map['is_active'] == true,
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
}
