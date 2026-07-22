import 'package:supabase_flutter/supabase_flutter.dart';

class TenantRegistrationResult {
  const TenantRegistrationResult({
    required this.tenantId,
    required this.branchId,
    required this.trialEndsAt,
  });

  final String tenantId;
  final String branchId;
  final DateTime? trialEndsAt;

  factory TenantRegistrationResult.fromMap(Map<String, dynamic> map) {
    return TenantRegistrationResult(
      tenantId: map['tenant_id'].toString(),
      branchId: map['branch_id'].toString(),
      trialEndsAt: map['trial_ends_at'] == null
          ? null
          : DateTime.tryParse(map['trial_ends_at'].toString()),
    );
  }
}

class TenantRegistrationService {
  const TenantRegistrationService();

  Future<TenantRegistrationResult> registerTenant({
    required String businessName,
    required String ownerFullName,
    required String whatsapp,
    String? businessType,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'register_tenant',
      params: {
        'p_business_name': businessName,
        'p_owner_full_name': ownerFullName,
        'p_whatsapp': whatsapp,
        'p_business_type': businessType,
      },
    );

    final row = (response as List).first;
    return TenantRegistrationResult.fromMap(Map<String, dynamic>.from(row));
  }
}
