class WorkPhotoSummary {
  final String id;
  final String? ticketId;
  final String clientName;
  final String stylistName;

  /// Direccion publica **permanente**. Tiene valor **solo mientras la foto
  /// esta aprobada para el portafolio** (H-09).
  ///
  /// Es permanente a proposito: el portafolio publico y la publicacion en
  /// redes sociales (tarea 4.3) necesitan una direccion que no caduque. Una
  /// direccion temporal dejaria la publicacion rota a los pocos dias.
  final String? photoUrl;

  /// En que almacen esta el archivo ahora mismo: `work-photos` si esta
  /// publicada, `work-photos-private` si espera aprobacion.
  final String storageBucket;

  /// Ruta del archivo dentro de su almacen. Es el dato verdadero.
  final String? storagePath;

  /// Lo que la pantalla debe pintar. Para una foto publicada es la direccion
  /// permanente; para una que espera aprobacion, una direccion temporal
  /// firmada que el servicio resuelve al cargar la lista.
  final String? displayUrl;

  final String photoType;
  final String? caption;
  final String aiStatus;
  final bool visibleToCustomer;
  final bool approvedForPortfolio;
  final String createdAt;

  const WorkPhotoSummary({
    required this.id,
    required this.ticketId,
    required this.clientName,
    required this.stylistName,
    required this.photoUrl,
    required this.storageBucket,
    required this.storagePath,
    required this.displayUrl,
    required this.photoType,
    required this.caption,
    required this.aiStatus,
    required this.visibleToCustomer,
    required this.approvedForPortfolio,
    required this.createdAt,
  });

  factory WorkPhotoSummary.fromMap(Map<String, dynamic> map) {
    return WorkPhotoSummary(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String?,
      clientName: map['client_name'] as String,
      stylistName: map['stylist_name'] as String,
      photoUrl: map['photo_url'] as String?,
      storageBucket:
          map['storage_bucket'] as String? ?? 'work-photos-private',
      storagePath: map['storage_path'] as String?,
      // La direccion temporal se resuelve despues, cuando hace falta: pedirla
      // exige una llamada al servidor y no todas las fotos la necesitan.
      displayUrl: map['photo_url'] as String?,
      photoType: map['photo_type'] as String,
      caption: map['caption'] as String?,
      aiStatus: map['ai_status'] as String,
      visibleToCustomer: map['visible_to_customer'] as bool,
      approvedForPortfolio: map['approved_for_portfolio'] as bool,
      createdAt: map['created_at'] as String,
    );
  }

  WorkPhotoSummary conDisplayUrl(String? url) {
    return WorkPhotoSummary(
      id: id,
      ticketId: ticketId,
      clientName: clientName,
      stylistName: stylistName,
      photoUrl: photoUrl,
      storageBucket: storageBucket,
      storagePath: storagePath,
      displayUrl: url,
      photoType: photoType,
      caption: caption,
      aiStatus: aiStatus,
      visibleToCustomer: visibleToCustomer,
      approvedForPortfolio: approvedForPortfolio,
      createdAt: createdAt,
    );
  }

  /// Si la foto es alcanzable desde internet por cualquiera. Es lo que hace
  /// verdadera la promesa de "aprobar publica, retirar despublica" (H-09).
  bool get estaPublicada => approvedForPortfolio && photoUrl != null;

  String get photoTypeText {
    switch (photoType) {
      case 'before':
        return 'Antes';
      case 'after':
        return 'Despues';
      case 'final':
        return 'Final';
      case 'portfolio':
        return 'Portafolio';
      default:
        return photoType;
    }
  }

  String get aiStatusText {
    switch (aiStatus) {
      case 'not_required':
        return 'IA no requerida';
      case 'pending':
        return 'IA pendiente';
      case 'processed':
        return 'IA procesada';
      case 'failed':
        return 'IA fallida';
      default:
        return aiStatus;
    }
  }

  String get visibilityText {
    return visibleToCustomer ? 'Visible al cliente' : 'No visible al cliente';
  }

  String get portfolioText {
    return approvedForPortfolio
        ? 'Aprobada para portafolio'
        : 'No aprobada para portafolio';
  }

  String get captionText {
    if (caption == null || caption!.trim().isEmpty) {
      return 'Sin descripcion';
    }

    return caption!;
  }

  String get createdDateText {
    final parsedDate = DateTime.tryParse(createdAt);

    if (parsedDate == null) {
      return createdAt;
    }

    final localDate = parsedDate.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    return '$day/$month/$year';
  }
}
