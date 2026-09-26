import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_consent.dart';

/// Lo que la clienta decide sobre sus fotos y sus reseñas (paso 9.48, D-281
/// y D-282). Sin sesión de Supabase Auth: la identifica su token, del portal
/// o del enlace directo. Toda la autorización la hace la base; aquí solo se
/// llama.
class ClientConsentService {
  const ClientConsentService();

  SupabaseClient get _cliente => Supabase.instance.client;

  Future<ClientConsentOverview> getOverview(
    ClientConsentCredential credencial,
  ) async {
    final respuesta = await _cliente.rpc(
      'client_consent_get_pending',
      params: credencial.rpcParams,
    );
    return ClientConsentOverview.fromMap(
      Map<String, dynamic>.from(respuesta as Map),
    );
  }

  /// La dirección para VER una foto: la pública si ya está publicada, y si
  /// no, una temporal que firma `client-consent-photo-url` (D-281). `null`
  /// si no se pudo: la pantalla lo dice con palabras en vez de pintar un
  /// cuadro roto.
  Future<String?> photoViewUrl(
    ConsentPhoto foto,
    ClientConsentCredential credencial,
  ) async {
    if (foto.photoUrl != null) return foto.photoUrl;
    try {
      final respuesta = await _cliente.functions.invoke(
        'client-consent-photo-url',
        body: {'photoId': foto.id, ...credencial.edgeParams},
      );
      final datos = respuesta.data;
      if (datos is Map) return datos['url']?.toString();
    } catch (_) {
      // Sin foto no se bloquea la decisión: la pantalla avisa que no se pudo
      // mostrar y ofrece recargar.
    }
    return null;
  }

  Future<void> setPhoto(
    String photoId,
    bool autoriza,
    ClientConsentCredential credencial,
  ) async {
    await _cliente.rpc(
      'client_consent_set_photo',
      params: {
        'p_photo_id': photoId,
        'p_authorized': autoriza,
        ...credencial.rpcParams,
      },
    );
  }

  /// Retira una foto YA PUBLICADA: la saca de internet y después lo anota
  /// (`client-consent-revoke-photo`, D-282). La base no deja hacerlo con
  /// [setPhoto], precisamente para que el archivo no se quede en internet.
  Future<void> revokePublishedPhoto(
    String photoId,
    ClientConsentCredential credencial,
  ) async {
    await _cliente.functions.invoke(
      'client-consent-revoke-photo',
      body: {'photoId': photoId, ...credencial.edgeParams},
    );
  }

  /// "Clienta verificada" (`nombreReal = false`) o su nombre real (`true`).
  Future<void> setReviewName(
    String reviewId,
    bool nombreReal,
    ClientConsentCredential credencial,
  ) async {
    await _cliente.rpc(
      'client_consent_set_review_name',
      params: {
        'p_review_id': reviewId,
        'p_authorized': nombreReal,
        ...credencial.rpcParams,
      },
    );
  }

  /// Un nombre escrito por ella. Si la reseña ya estaba publicada, vuelve a
  /// revisión del salón (D-282).
  Future<void> setReviewAlias(
    String reviewId,
    String alias,
    ClientConsentCredential credencial,
  ) async {
    await _cliente.rpc(
      'client_consent_set_review_alias',
      params: {
        'p_review_id': reviewId,
        'p_alias': alias,
        ...credencial.rpcParams,
      },
    );
  }
}
