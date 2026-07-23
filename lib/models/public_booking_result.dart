class PublicBookingResult {
  const PublicBookingResult({
    required this.ticketId,
    required this.scheduledAt,
    required this.serviceName,
    required this.stylistName,
    required this.status,
  });

  final String ticketId;
  final DateTime scheduledAt;
  final String serviceName;
  final String stylistName;
  final String status;

  factory PublicBookingResult.fromMap(Map<String, dynamic> map) {
    return PublicBookingResult(
      ticketId: map['ticket_id'].toString(),
      scheduledAt: DateTime.parse(map['scheduled_at'].toString()).toLocal(),
      serviceName: map['service_name']?.toString() ?? 'Servicio',
      stylistName: map['stylist_name']?.toString() ?? 'Estilista',
      status: map['status']?.toString() ?? 'solicitado',
    );
  }
}
