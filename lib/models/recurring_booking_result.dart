class RecurringBookingResult {
  const RecurringBookingResult({
    required this.scheduledAt,
    required this.success,
    this.ticketId,
    this.errorMessage,
  });

  final DateTime scheduledAt;
  final bool success;
  final String? ticketId;
  final String? errorMessage;

  factory RecurringBookingResult.fromMap(Map<String, dynamic> map) {
    return RecurringBookingResult(
      scheduledAt: DateTime.parse(map['scheduled_at'].toString()).toLocal(),
      success: map['success'] == true,
      ticketId: map['ticket_id']?.toString(),
      errorMessage: map['error_message']?.toString(),
    );
  }
}
