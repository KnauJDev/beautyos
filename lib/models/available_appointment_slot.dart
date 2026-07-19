class AvailableAppointmentSlot {
  const AvailableAppointmentSlot({
    required this.startsAt,
    required this.endsAt,
  });

  final DateTime startsAt;
  final DateTime endsAt;

  factory AvailableAppointmentSlot.fromMap(Map<String, dynamic> map) {
    return AvailableAppointmentSlot(
      startsAt: DateTime.parse(map['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(map['ends_at'].toString()).toLocal(),
    );
  }

  String get label {
    final hour = startsAt.hour.toString().padLeft(2, '0');
    final minute = startsAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
