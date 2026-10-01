class TenantSubscriptionHistoryEntry {
  const TenantSubscriptionHistoryEntry({
    required this.eventId,
    required this.createdAt,
    required this.eventType,
    this.planCode,
    this.planName,
    this.periodStart,
    this.periodEnd,
    this.amountCop,
    this.paymentDetail,
    this.description,
    this.branchId,
    this.branchName,
  });

  final String eventId;
  final DateTime? createdAt;
  final String eventType;
  final String? planCode;
  final String? planName;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int? amountCop;
  final String? paymentDetail;
  final String? description;

  /// De que sede es este renglon (9.40, D-303). Desde D-239 cada sede paga lo
  /// suyo. `null` en los eventos del negocio (aprobar, plan, contacto) y si el
  /// servidor todavia no manda la columna: la pantalla aguanta las dos cosas.
  final String? branchId;
  final String? branchName;

  factory TenantSubscriptionHistoryEntry.fromMap(Map<String, dynamic> map) {
    return TenantSubscriptionHistoryEntry(
      eventId: map['event_id'].toString(),
      createdAt: _parseDate(map['created_at']),
      eventType: map['event_type']?.toString() ?? '',
      planCode: map['plan_code']?.toString(),
      planName: map['plan_name']?.toString(),
      periodStart: _parseDate(map['period_start']),
      periodEnd: _parseDate(map['period_end']),
      amountCop: _parseInt(map['amount_cop']),
      paymentDetail: map['payment_detail']?.toString(),
      description: map['description']?.toString(),
      branchId: map['branch_id']?.toString(),
      branchName: map['branch_name']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
