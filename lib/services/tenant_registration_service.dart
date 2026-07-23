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

    // register_tenant() es "returns table" de una sola fila; se acepta
    // tanto una lista (forma habitual de un RPC de conjunto) como un mapa
    // suelto, para no depender de una unica forma de respuesta sin
    // evidencia directa de cual entrega el cliente en este caso.
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
