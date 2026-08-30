import 'package:supabase_flutter/supabase_flutter.dart';

class TenantRegistrationResult {
  const TenantRegistrationResult({
    required this.tenantId,
    required this.branchId,
    required this.status,
  });

  final String tenantId;
  final String branchId;
  final String status;

  factory TenantRegistrationResult.fromMap(Map<String, dynamic> map) {
    return TenantRegistrationResult(
      tenantId: map['tenant_id'].toString(),
      branchId: map['branch_id'].toString(),
      status: map['status']?.toString() ?? 'pending',
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
    String? city,
    int estimatedBranches = 1,
    int estimatedTeamSize = 1,
    String? referralSource,
    String? referralCodeUsed,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'register_tenant',
      params: {
        'p_business_name': businessName,
        'p_owner_full_name': ownerFullName,
        'p_whatsapp': whatsapp,
        'p_business_type': businessType,
        'p_city': city,
        'p_estimated_branches': estimatedBranches,
        'p_estimated_team_size': estimatedTeamSize,
        'p_referral_source': referralSource,
        'p_referral_code_used': referralCodeUsed,
      },
    );

    final Map<String, dynamic> row;
    if (response is List) {
      if (response.isEmpty) {
        throw StateError(
          'register_tenant no devolvió ninguna fila (el negocio pudo '
          'haberse creado igual; revisa tu perfil antes de reintentar).',
        );
      }
      row = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      row = Map<String, dynamic>.from(response);
    } else {
      throw StateError('Respuesta inesperada de register_tenant: $response');
    }

    return TenantRegistrationResult.fromMap(row);
  }
}
