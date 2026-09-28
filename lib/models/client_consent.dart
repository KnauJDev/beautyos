/// Cómo identifica la base a la clienta cuando decide sobre sus fotos y sus
/// reseñas (paso 9.48, D-281): por la sesión de su portal (D-167) o por su
/// enlace directo, permanente. Uno de los dos, nunca los dos.
class ClientConsentCredential {
  const ClientConsentCredential.portal(String token)
      : portalToken = token,
        consentToken = null;

  const ClientConsentCredential.enlace(String token)
      : portalToken = null,
        consentToken = token;

  final String? portalToken;
  final String? consentToken;

  /// Los dos parámetros que esperan todas las funciones `client_consent_*`.
  Map<String, dynamic> get rpcParams => {
        'p_portal_token': portalToken,
        'p_consent_token': consentToken,
      };

  /// Los mismos, con los nombres que esperan las Edge Functions.
  Map<String, dynamic> get edgeParams => {
        if (portalToken != null) 'portalToken': portalToken,
        if (consentToken != null) 'consentToken': consentToken,
      };
}

/// Una foto suya sobre la que decide: pendiente (sin [authorized]) o ya
/// respondida.
class ConsentPhoto {
  const ConsentPhoto({
    required this.id,
    this.caption,
    this.photoType,
    this.createdAt,
    this.authorized,
    required this.isPublished,
    this.photoUrl,
  });

  final String id;
  final String? caption;
  final String? photoType;
  final DateTime? createdAt;

  /// `null` si todavía no respondió.
  final bool? authorized;

  /// Ya está en el portafolio público. Retirarla la saca de internet, y eso
  /// va por otro camino que cambiar la respuesta (D-282).
  final bool isPublished;

  /// Dirección pública, solo si ya está publicada. Si no, la foto vive en el
  /// almacén privado y hay que pedir una dirección temporal para verla.
  final String? photoUrl;

  factory ConsentPhoto.fromMap(Map<String, dynamic> map) {
    final url = map['photo_url']?.toString();
    return ConsentPhoto(
      id: map['id'].toString(),
      caption: map['caption']?.toString(),
      photoType: map['photo_type']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
      authorized: map['authorized'] is bool ? map['authorized'] as bool : null,
      isPublished: map['is_published'] == true,
      photoUrl: url == null || url.isEmpty ? null : url,
    );
  }
}

/// Las tres formas en que puede aparecer su nombre en una reseña (D-282).
enum ReviewNameChoice { verificada, nombreReal, nombrePropio }

/// Una reseña suya: pendiente de decidir su nombre, o ya decidida.
class ConsentReview {
  const ConsentReview({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    this.choice,
    this.displayName,
    this.moderationStatus,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  /// `null` si todavía no eligió.
  final ReviewNameChoice? choice;

  /// El nombre que escribió ella, si eligió uno propio.
  final String? displayName;
  final String? moderationStatus;

  /// Eligió un nombre propio y el salón todavía no lo aprueba: su reseña no
  /// se ve en la página mientras tanto (D-282).
  bool get esperaRevision =>
      choice == ReviewNameChoice.nombrePropio && moderationStatus == 'pending';

  factory ConsentReview.fromMap(Map<String, dynamic> map) {
    final alias = map['display_name']?.toString();
    final tieneAlias = alias != null && alias.trim().isNotEmpty;
    ReviewNameChoice? choice;
    if (map.containsKey('name_consent')) {
      if (map['name_consent'] != true) {
        choice = ReviewNameChoice.verificada;
      } else {
        choice = tieneAlias
            ? ReviewNameChoice.nombrePropio
            : ReviewNameChoice.nombreReal;
      }
    }
    return ConsentReview(
      id: map['id'].toString(),
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
      choice: choice,
      displayName: tieneAlias ? alias : null,
      moderationStatus: map['moderation_status']?.toString(),
    );
  }
}

/// Todo lo que la clienta tiene por decidir y lo que ya decidió
/// (`client_consent_get_pending`, D-282).
class ClientConsentOverview {
  const ClientConsentOverview({
    required this.clientName,
    this.businessName,
    this.businessWhatsapp,
    this.businessSlug,
    required this.pendingPhotos,
    required this.answeredPhotos,
    required this.pendingReviews,
    required this.answeredReviews,
  });

  final String clientName;
  final String? businessName;
  final String? businessWhatsapp;

  /// La dirección pública del salón (D-287). La usa la página del enlace
  /// directo, que no sabe de qué salón viene, para pintar sus colores y
  /// ofrecer ir a su página.
  final String? businessSlug;
  final List<ConsentPhoto> pendingPhotos;
  final List<ConsentPhoto> answeredPhotos;
  final List<ConsentReview> pendingReviews;
  final List<ConsentReview> answeredReviews;

  int get pendientes => pendingPhotos.length + pendingReviews.length;

  bool get vacio =>
      pendientes == 0 && answeredPhotos.isEmpty && answeredReviews.isEmpty;

  factory ClientConsentOverview.fromMap(Map<String, dynamic> map) {
    List<T> lista<T>(String clave, T Function(Map<String, dynamic>) crear) {
      return (map[clave] as List<dynamic>? ?? [])
          .map((item) => crear(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    String? texto(String clave) {
      final valor = map[clave]?.toString().trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    return ClientConsentOverview(
      clientName: texto('client_name') ?? 'Clienta',
      businessName: texto('business_name'),
      businessWhatsapp: texto('business_whatsapp'),
      businessSlug: texto('business_slug'),
      pendingPhotos: lista('pending_photos', ConsentPhoto.fromMap),
      answeredPhotos: lista('answered_photos', ConsentPhoto.fromMap),
      pendingReviews: lista('pending_reviews', ConsentReview.fromMap),
      answeredReviews: lista('answered_reviews', ConsentReview.fromMap),
    );
  }
}

/// Lo que el salón necesita para pedirle la autorización a una clienta por
/// WhatsApp (paso 9.48, Bloque 4, D-288): su enlace, su nombre, su celular
/// y el nombre del salón. Lo entrega `client_consent_whatsapp_data`, solo a
/// dueño, administrador o asistente.
class ClientConsentWhatsapp {
  const ClientConsentWhatsapp({
    required this.token,
    required this.clientName,
    this.clientPhone,
    required this.businessName,
  });

  final String token;
  final String clientName;
  final String? clientPhone;
  final String businessName;

  factory ClientConsentWhatsapp.fromMap(Map<String, dynamic> map) {
    String? texto(String clave) {
      final valor = map[clave]?.toString().trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    return ClientConsentWhatsapp(
      token: texto('token') ?? '',
      clientName: texto('client_name') ?? '',
      clientPhone: texto('client_phone'),
      businessName: texto('business_name') ?? '',
    );
  }
}
