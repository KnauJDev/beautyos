class WorkPhotoSummary {
  final String id;
  final String? ticketId;
  final String clientName;
  final String stylistName;
  final String photoUrl;
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
      photoUrl: map['photo_url'] as String,
      photoType: map['photo_type'] as String,
      caption: map['caption'] as String?,
      aiStatus: map['ai_status'] as String,
      visibleToCustomer: map['visible_to_customer'] as bool,
      approvedForPortfolio: map['approved_for_portfolio'] as bool,
      createdAt: map['created_at'] as String,
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
