class DailyCloseSummary {
  final DateTime businessDate;
  final int paymentsCount;
  final int paidTicketsCount;
  final int commissionServicesCount;
  final double totalReceived;
  final double cashReceived;
  final double cardReceived;
  final double transferReceived;
  final double otherReceived;
  final double totalPurchases;
  final double totalExpenses;
  final double totalCommissions;
  final double expectedCash;
  final double estimatedResult;

  const DailyCloseSummary({
    required this.businessDate,
    required this.paymentsCount,
    required this.paidTicketsCount,
    required this.commissionServicesCount,
    required this.totalReceived,
    required this.cashReceived,
    required this.cardReceived,
    required this.transferReceived,
    required this.otherReceived,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalCommissions,
    required this.expectedCash,
    required this.estimatedResult,
  });

  factory DailyCloseSummary.fromMap(Map<String, dynamic> map) {
    return DailyCloseSummary(
      businessDate:
          DateTime.tryParse(map['business_date']?.toString() ?? '') ??
          DateTime.now(),
      paymentsCount: _readInt(map['payments_count']),
      paidTicketsCount: _readInt(map['paid_tickets_count']),
      commissionServicesCount: _readInt(map['commission_services_count']),
      totalReceived: _readDouble(map['total_received']),
      cashReceived: _readDouble(map['cash_received']),
      cardReceived: _readDouble(map['card_received']),
      transferReceived: _readDouble(map['transfer_received']),
      otherReceived: _readDouble(map['other_received']),
      totalPurchases: _readDouble(map['total_purchases']),
      totalExpenses: _readDouble(map['total_expenses']),
      totalCommissions: _readDouble(map['total_commissions']),
      expectedCash: _readDouble(map['expected_cash']),
      estimatedResult: _readDouble(map['estimated_result']),
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
