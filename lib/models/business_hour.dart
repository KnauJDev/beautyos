class BusinessHour {
  final String id;
  final int dayOfWeek;
  final String? opensAt;
  final String? closesAt;
  final bool isOpen;

  const BusinessHour({
    required this.id,
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    required this.isOpen,
  });

  factory BusinessHour.fromMap(Map<String, dynamic> map) {
    return BusinessHour(
      id: map['id']?.toString() ?? '',
      dayOfWeek: _readInt(map['day_of_week']),
      opensAt: map['opens_at']?.toString(),
      closesAt: map['closes_at']?.toString(),
      isOpen: map['is_open'] == true,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Día desconocido';
    }
  }

  String get scheduleText {
    if (!isOpen) {
      return 'Cerrado';
    }

    return '${_formatTime(opensAt)} - ${_formatTime(closesAt)}';
  }

  static String _formatTime(String? value) {
    if (value == null || value.isEmpty) {
      return '--:--';
    }

    if (value.length >= 5) {
      return value.substring(0, 5);
    }

    return value;
  }
}
