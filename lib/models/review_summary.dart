class ReviewSummary {
  final String id;
  final String? ticketId;
  final String clientName;
  final String stylistName;
  final String serviceName;
  final int rating;
  final String? comment;
  final String moderationStatus;
  final bool visibleToPublic;

  /// Respuesta pública del salón a esta reseña (paso 6.3, D-170). `null` si
  /// todavía no ha respondido.
  final String? businessReply;
  final DateTime? businessReplyAt;
  final DateTime createdAt;

  /// Con qué nombre sale la reseña en la página pública (paso 9.48, D-282):
  /// "Clienta verificada", su nombre real o uno que escribió ella. Lo decide
  /// la clienta, no el salón -- y un nombre escrito por ella vuelve a
  /// moderación, así que el salón tiene que verlo antes de aprobar.
  final String publicName;

  const ReviewSummary({
    required this.id,
    required this.ticketId,
    required this.clientName,
    required this.stylistName,
    required this.serviceName,
    required this.rating,
    required this.comment,
    required this.moderationStatus,
    required this.visibleToPublic,
    this.businessReply,
    this.businessReplyAt,
    required this.createdAt,
    this.publicName = 'Clienta verificada',
  });

  factory ReviewSummary.fromMap(Map<String, dynamic> map) {
    return ReviewSummary(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String?,
      clientName: map['client_name'] as String? ?? 'Cliente no asociado',
      stylistName: map['stylist_name'] as String? ?? 'Estilista no asociado',
      serviceName: map['service_name'] as String? ?? 'Servicio no asociado',
      rating: _readInt(map['rating']),
      comment: map['comment'] as String?,
      moderationStatus: map['moderation_status'] as String? ?? 'pending',
      visibleToPublic: map['visible_to_public'] as bool? ?? false,
      businessReply: map['business_reply']?.toString(),
      businessReplyAt: map['business_reply_at'] == null
          ? null
          : DateTime.tryParse(map['business_reply_at'].toString())?.toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      publicName: map['public_name']?.toString() ?? 'Clienta verificada',
    );
  }

  bool get tieneRespuesta =>
      businessReply != null && businessReply!.trim().isNotEmpty;

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String get starsText {
    return '★' * rating;
  }

  String get commentText {
    final cleanComment = comment?.trim();

    if (cleanComment == null || cleanComment.isEmpty) {
      return 'Sin comentario';
    }

    return cleanComment;
  }

  String get moderationText {
    switch (moderationStatus) {
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      case 'pending':
      default:
        return 'Pendiente';
    }
  }

  String get visibilityText {
    return visibleToPublic ? 'Visible al público' : 'Privada';
  }

  String get createdDateText {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();

    return '$day/$month/$year';
  }
}
