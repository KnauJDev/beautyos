class StylistTimeOff {
  const StylistTimeOff({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? reason;

  factory StylistTimeOff.fromMap(Map<String, dynamic> map) {
    return StylistTimeOff(
      id: map['id']?.toString() ?? '',
      startsAt: DateTime.parse(map['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(map['ends_at'].toString()).toLocal(),
      reason: map['reason']?.toString(),
    );
  }

  String get reasonText {
    final value = reason;
    if (value == null || value.trim().isEmpty) {
      return 'Sin motivo indicado';
    }
    return value;
  }

  String get rangeText {
    String formatDateTime(DateTime value) {
      final day = value.day.toString().padLeft(2, '0');
      final month = value.month.toString().padLeft(2, '0');
      final year = value.year.toString();
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }

    return '${formatDateTime(startsAt)} - ${formatDateTime(endsAt)}';
  }
}
