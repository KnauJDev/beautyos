class SalesReportSummary {
  final String serviceName;
  final String stylistName;
  final int ticketsCount;
  final num totalSales;
  final int totalDurationMinutes;

  const SalesReportSummary({
    required this.serviceName,
    required this.stylistName,
    required this.ticketsCount,
    required this.totalSales,
    required this.totalDurationMinutes,
  });

  factory SalesReportSummary.fromMap(Map<String, dynamic> map) {
    return SalesReportSummary(
      serviceName: map['service_name']?.toString() ?? 'Sin servicio',
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      ticketsCount: _readInt(map['tickets_count']),
      totalSales: _readNumber(map['total_sales']),
      totalDurationMinutes: _readInt(map['total_duration_minutes']),
    );
  }

  static num _readNumber(dynamic value) {
    if (value is num) {
      return value;
    }

    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get formattedTotalSales {
    final value = totalSales.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final positionFromEnd = value.length - i;

      buffer.write(value[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }
}
