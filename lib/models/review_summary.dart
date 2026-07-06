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
  final DateTime createdAt;

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
    required this.createdAt,
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
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

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
