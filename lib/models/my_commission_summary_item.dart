import 'ticket_board.dart' show formatCOP;

class MyCommissionSummaryItem {
  const MyCommissionSummaryItem({
    required this.serviceId,
    required this.serviceName,
    required this.servicesCount,
    required this.commissionTotal,
  });

  final String serviceId;
  final String serviceName;
  final int servicesCount;
  final double commissionTotal;

  factory MyCommissionSummaryItem.fromMap(Map<String, dynamic> map) {
    return MyCommissionSummaryItem(
      serviceId: map['service_id']?.toString() ?? '',
      serviceName: map['service_name']?.toString() ?? 'Servicio sin nombre',
      servicesCount: _readInt(map['services_count']),
      commissionTotal: _readDouble(map['commission_total']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get formattedCommissionTotal => formatCOP(commissionTotal);
}
