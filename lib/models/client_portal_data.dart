/// Una cita próxima de la clienta en su portal (D-167).
class ClientPortalUpcomingAppointment {
  const ClientPortalUpcomingAppointment({
    required this.ticketId,
    this.ticketCode,
    this.scheduledAt,
    required this.status,
    required this.serviceNames,
    required this.stylistNames,
  });

  final String ticketId;
  final String? ticketCode;
  final DateTime? scheduledAt;
  final String status;
  final String serviceNames;
  final String stylistNames;

  factory ClientPortalUpcomingAppointment.fromMap(Map<String, dynamic> map) {
    return ClientPortalUpcomingAppointment(
      ticketId: map['ticket_id'].toString(),
      ticketCode: map['ticket_code']?.toString(),
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString())?.toLocal(),
      status: map['status']?.toString() ?? '',
      serviceNames: map['service_names']?.toString() ?? 'Sin servicios',
      stylistNames: map['stylist_names']?.toString() ?? 'Sin estilista',
    );
  }

  String get scheduledAtText {
    final date = scheduledAt;
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Una cita pasada (finalizada/cerrada) de la clienta, con si ya la calificó
/// o no (D-167).
class ClientPortalPastAppointment {
  const ClientPortalPastAppointment({
    required this.ticketId,
    this.ticketCode,
    this.scheduledAt,
    required this.status,
    required this.serviceNames,
    required this.alreadyReviewed,
  });

  final String ticketId;
  final String? ticketCode;
  final DateTime? scheduledAt;
  final String status;
  final String serviceNames;
  final bool alreadyReviewed;

  factory ClientPortalPastAppointment.fromMap(Map<String, dynamic> map) {
    return ClientPortalPastAppointment(
      ticketId: map['ticket_id'].toString(),
      ticketCode: map['ticket_code']?.toString(),
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString())?.toLocal(),
      status: map['status']?.toString() ?? '',
      serviceNames: map['service_names']?.toString() ?? 'Sin servicios',
      alreadyReviewed: map['already_reviewed'] == true,
    );
  }

  String get scheduledAtText {
    final date = scheduledAt;
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// Una foto de trabajo de la clienta, visible para ella en su portal
/// (D-167). Solo llegan aquí fotos ya con URL pública permanente -- ver
/// nota en `get_client_portal_data`.
class ClientPortalPhoto {
  const ClientPortalPhoto({
    required this.id,
    required this.photoUrl,
    this.photoType,
    this.caption,
    this.createdAt,
  });

  final String id;
  final String photoUrl;
  final String? photoType;
  final String? caption;
  final DateTime? createdAt;

  factory ClientPortalPhoto.fromMap(Map<String, dynamic> map) {
    return ClientPortalPhoto(
      id: map['id'].toString(),
      photoUrl: map['photo_url']?.toString() ?? '',
      photoType: map['photo_type']?.toString(),
      caption: map['caption']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}

/// Todo lo que ve la clienta en su portal: su nombre, citas próximas y
/// pasadas, y sus fotos (D-167).
class ClientPortalData {
  const ClientPortalData({
    required this.clientName,
    required this.upcomingAppointments,
    required this.pastAppointments,
    required this.photos,
  });

  final String clientName;
  final List<ClientPortalUpcomingAppointment> upcomingAppointments;
  final List<ClientPortalPastAppointment> pastAppointments;
  final List<ClientPortalPhoto> photos;

  factory ClientPortalData.fromMap(Map<String, dynamic> map) {
    return ClientPortalData(
      clientName: map['client_name']?.toString() ?? 'Clienta',
      upcomingAppointments: (map['upcoming_appointments'] as List<dynamic>? ?? [])
          .map(
            (item) => ClientPortalUpcomingAppointment.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      pastAppointments: (map['past_appointments'] as List<dynamic>? ?? [])
          .map(
            (item) => ClientPortalPastAppointment.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      photos: (map['photos'] as List<dynamic>? ?? [])
          .map(
            (item) => ClientPortalPhoto.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
