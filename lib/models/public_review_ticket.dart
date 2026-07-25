class PublicReviewServiceOption {
  const PublicReviewServiceOption({
    required this.serviceId,
    required this.serviceName,
    required this.stylistId,
    required this.stylistName,
  });

  final String serviceId;
  final String serviceName;
  final String? stylistId;
  final String? stylistName;

  factory PublicReviewServiceOption.fromMap(Map<String, dynamic> map) {
    return PublicReviewServiceOption(
      serviceId: map['service_id'] as String,
      serviceName: map['service_name'] as String? ?? 'Servicio',
      stylistId: map['stylist_id'] as String?,
      stylistName: map['stylist_name'] as String?,
    );
  }

  String get label {
    if (stylistName == null) {
      return serviceName;
    }
    return '$serviceName con $stylistName';
  }
}

class PublicReviewTicket {
  const PublicReviewTicket({
    required this.ticketId,
    required this.branchName,
    required this.clientName,
    required this.ticketStatus,
    required this.reviewable,
    required this.alreadyReviewed,
    required this.services,
  });

  final String ticketId;
  final String branchName;
  final String clientName;
  final String ticketStatus;
  final bool reviewable;
  final bool alreadyReviewed;
  final List<PublicReviewServiceOption> services;

  factory PublicReviewTicket.fromMap(Map<String, dynamic> map) {
    final rawServices = map['services'] as List<dynamic>? ?? [];

    return PublicReviewTicket(
      ticketId: map['ticket_id'] as String,
      branchName: map['branch_name'] as String? ?? 'Negocio',
      clientName: map['client_name'] as String? ?? 'Cliente',
      ticketStatus: map['ticket_status'] as String? ?? '',
      reviewable: map['reviewable'] as bool? ?? false,
      alreadyReviewed: map['already_reviewed'] as bool? ?? false,
      services: rawServices
          .map(
            (item) => PublicReviewServiceOption.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
