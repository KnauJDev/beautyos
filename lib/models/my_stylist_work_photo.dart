class MyStylistWorkPhoto {
  const MyStylistWorkPhoto({
    required this.id,
    required this.ticketId,
    required this.clientName,
    required this.serviceName,
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

  final String id;
  final String? ticketId;
  final String clientName;
  final String serviceName;
  /// Direccion publica permanente. Solo mientras la foto esta publicada en
  /// el portafolio; nula mientras espera aprobacion (H-09).
  final String? photoUrl;
  final String storageBucket;
  final String? storagePath;

  /// Lo que se pinta: permanente si esta publicada, temporal firmada si no.
  final String? displayUrl;

  final String photoType;
  final String caption;
  final String aiStatus;
  final bool visibleToCustomer;
  final bool approvedForPortfolio;
  final DateTime? createdAt;

  MyStylistWorkPhoto conDisplayUrl(String? url) {
    return MyStylistWorkPhoto(
      id: id,
      ticketId: ticketId,
      clientName: clientName,
      serviceName: serviceName,
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

  factory MyStylistWorkPhoto.fromMap(Map<String, dynamic> map) {
    return MyStylistWorkPhoto(
      id: map['id']?.toString() ?? '',
      ticketId: map['ticket_id']?.toString(),
      clientName: map['client_name']?.toString() ?? 'Cliente sin nombre',
      serviceName: map['service_name']?.toString() ?? 'Servicio sin nombre',
      photoUrl: map['photo_url']?.toString(),
      storageBucket:
          map['storage_bucket']?.toString() ?? 'work-photos-private',
      storagePath: map['storage_path']?.toString(),
      displayUrl: map['photo_url']?.toString(),
      photoType: map['photo_type']?.toString() ?? '',
      caption: map['caption']?.toString() ?? 'Sin descripcion',
      aiStatus: map['ai_status']?.toString() ?? '',
      visibleToCustomer: map['visible_to_customer'] == true,
      approvedForPortfolio: map['approved_for_portfolio'] == true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }

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
        return photoType.isEmpty ? 'Sin tipo' : photoType;
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
        return aiStatus.isEmpty ? 'Sin estado IA' : aiStatus;
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

  String get createdDateText {
    final value = createdAt;

    if (value == null) {
      return 'Sin fecha';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day/$month/$year';
  }
}
