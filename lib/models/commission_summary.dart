class CommissionSummary {
  final String stylistId;
  final String stylistName;
  final int servicesCount;
  final double serviceSales;
  final double commissionTotal;

  const CommissionSummary({
    required this.stylistId,
    required this.stylistName,
    required this.servicesCount,
    required this.serviceSales,
    required this.commissionTotal,
  });

  factory CommissionSummary.fromMap(Map<String, dynamic> map) {
    return CommissionSummary(
      stylistId: map['stylist_id']?.toString() ?? '',
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      servicesCount: _readInt(map['services_count']),
      serviceSales: _readDouble(map['service_sales']),
      commissionTotal: _readDouble(map['commission_total']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
