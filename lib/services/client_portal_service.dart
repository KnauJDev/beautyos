import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_portal_data.dart';

/// Llama a las RPC públicas (rol "anon", sin sesión) del portal de la
/// clienta (D-167). El PIN nunca lo crea esta pantalla -- solo el salón lo
/// asigna (ver `ClientsService.resetPortalPin`); aquí solo se verifica.
class ClientPortalService {
  const ClientPortalService();

  /// Verifica celular + PIN y devuelve el token de sesión. Lanza
  /// [PostgrestException] con un mensaje ya listo para mostrar.
  ///
  /// Ese mensaje es **el mismo para todos los casos de fallo** —celular que no
  /// es clienta, clienta sin PIN, PIN equivocado y clienta bloqueada— y así
  /// tiene que seguir: distinguirlos permitía enumerar qué celulares son
  /// clientas de un salón sin adivinar ningún PIN (TL-04, D-183, Ley 1581).
  Future<String> authenticate({
    required String tenantId,
    required String phone,
    required String pin,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'client_portal_authenticate',
      params: {'p_tenant_id': tenantId, 'p_phone': phone, 'p_pin': pin},
    );

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final error = map['error']?.toString();
      if (error != null && error.isNotEmpty) {
        throw PostgrestException(message: error);
      }
      final token = map['token']?.toString();
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }

    if (response is String) return response;

    throw const PostgrestException(message: 'Respuesta inválida del servidor.');
  }

  Future<ClientPortalData> getPortalData({
    required String tenantId,
    required String phone,
    required String portalToken,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'get_client_portal_data',
      params: {
        'p_tenant_id': tenantId,
        'p_phone': phone,
        'p_portal_token': portalToken,
      },
    );

    return ClientPortalData.fromMap(Map<String, dynamic>.from(response as Map));
  }
}
