class TicketServiceCorrectionOption {
  const TicketServiceCorrectionOption({
    required this.ticketServiceId,
    required this.serviceName,
    required this.stylistName,
    required this.serviceStatus,
    required this.finalizedAt,
  });

  final String ticketServiceId;
  final String serviceName;
  final String stylistName;
  final String serviceStatus;
  final DateTime? finalizedAt;

  factory TicketServiceCorrectionOption.fromMap(Map<String, dynamic> map) {
    return TicketServiceCorrectionOption(
      ticketServiceId: map['ticket_service_id']?.toString() ?? '',
      serviceName: map['service_name']?.toString() ?? 'Servicio sin nombre',
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      serviceStatus: map['service_status']?.toString() ?? '',
      finalizedAt: map['finalized_at'] == null
          ? null
          : DateTime.tryParse(map['finalized_at'].toString())?.toLocal(),
    );
  }

  String get label => '$serviceName · $stylistName';
}
