import 'ticket_payment.dart' show formatMoney;

class BranchReportV3 {
  final DateTime startDate;
  final DateTime endDate;
  final double totalReceived;
  final int paymentsCount;
  final int paidTicketsCount;
  final double cashReceived;
  final double cardReceived;
  final double transferReceived;
  final double otherReceived;
  final double totalPurchases;
  final double cashPurchases;
  final double totalExpenses;
  final double cashExpenses;
  final double totalCommissions;
  final int commissionServicesCount;
  final double expectedCash;
  final double netResult;
  final double prevTotalReceived;
  final double prevNetResult;
  final int prevPaymentsCount;
  final List<ReportCommissionItem> commissionsByStylist;
  final List<ReportServiceSaleItem> salesByService;

  /// Cuantas sedes hay dentro de estas cifras (D-194). 1 = una sola sede.
  final int branchesCount;

  /// El desglose por sede del consolidado. Vacio cuando se mira una sola sede.
  final List<ReportBranchItem> byBranch;

  /// Si estas cifras son la suma de mas de una sede.
  bool get esConsolidado => branchesCount > 1;

  const BranchReportV3({
    this.branchesCount = 1,
    this.byBranch = const <ReportBranchItem>[],
    required this.startDate,
    required this.endDate,
    required this.totalReceived,
    required this.paymentsCount,
    required this.paidTicketsCount,
    required this.cashReceived,
    required this.cardReceived,
    required this.transferReceived,
    required this.otherReceived,
    required this.totalPurchases,
    required this.cashPurchases,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.totalCommissions,
    required this.commissionServicesCount,
    required this.expectedCash,
    required this.netResult,
    required this.prevTotalReceived,
    required this.prevNetResult,
    required this.prevPaymentsCount,
    required this.commissionsByStylist,
    required this.salesByService,
  });

  factory BranchReportV3.fromMap(Map<String, dynamic> map) {
    final sedes = map['branches_count'];
    final desglose = map['by_branch'];

    final commissionsRaw = map['commissions_by_stylist'];
    final salesRaw = map['sales_by_service'];

    final commissionsList = <ReportCommissionItem>[];
    if (commissionsRaw is List) {
      for (final item in commissionsRaw) {
        if (item is Map) {
          commissionsList.add(ReportCommissionItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final salesList = <ReportServiceSaleItem>[];
    if (salesRaw is List) {
      for (final item in salesRaw) {
        if (item is Map) {
          salesList.add(ReportServiceSaleItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return BranchReportV3(
      branchesCount: sedes is int
          ? sedes
          : int.tryParse(sedes?.toString() ?? '') ?? 1,
      byBranch: desglose is List
          ? desglose
                .whereType<Map>()
                .map(
                  (e) => ReportBranchItem.fromMap(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const <ReportBranchItem>[],
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['end_date']?.toString() ?? '') ?? DateTime.now(),
      totalReceived: double.tryParse(map['total_received']?.toString() ?? '') ?? 0,
      paymentsCount: int.tryParse(map['payments_count']?.toString() ?? '') ?? 0,
      paidTicketsCount: int.tryParse(map['paid_tickets_count']?.toString() ?? '') ?? 0,
      cashReceived: double.tryParse(map['cash_received']?.toString() ?? '') ?? 0,
      cardReceived: double.tryParse(map['card_received']?.toString() ?? '') ?? 0,
      transferReceived: double.tryParse(map['transfer_received']?.toString() ?? '') ?? 0,
      otherReceived: double.tryParse(map['other_received']?.toString() ?? '') ?? 0,
      totalPurchases: double.tryParse(map['total_purchases']?.toString() ?? '') ?? 0,
      cashPurchases: double.tryParse(map['cash_purchases']?.toString() ?? '') ?? 0,
      totalExpenses: double.tryParse(map['total_expenses']?.toString() ?? '') ?? 0,
      cashExpenses: double.tryParse(map['cash_expenses']?.toString() ?? '') ?? 0,
      totalCommissions: double.tryParse(map['total_commissions']?.toString() ?? '') ?? 0,
      commissionServicesCount: int.tryParse(map['commission_services_count']?.toString() ?? '') ?? 0,
      expectedCash: double.tryParse(map['expected_cash']?.toString() ?? '') ?? 0,
      netResult: double.tryParse(map['net_result']?.toString() ?? '') ?? 0,
      prevTotalReceived: double.tryParse(map['prev_total_received']?.toString() ?? '') ?? 0,
      prevNetResult: double.tryParse(map['prev_net_result']?.toString() ?? '') ?? 0,
      prevPaymentsCount: int.tryParse(map['prev_payments_count']?.toString() ?? '') ?? 0,
      commissionsByStylist: commissionsList,
      salesByService: salesList,
    );
  }

  String get formattedTotalReceived => formatMoney(totalReceived);
  String get formattedCashReceived => formatMoney(cashReceived);
  String get formattedCardReceived => formatMoney(cardReceived);
  String get formattedTransferReceived => formatMoney(transferReceived);
  String get formattedOtherReceived => formatMoney(otherReceived);

  String get formattedTotalPurchases => formatMoney(totalPurchases);
  String get formattedTotalExpenses => formatMoney(totalExpenses);
  String get formattedTotalCommissions => formatMoney(totalCommissions);
  String get formattedExpectedCash => formatMoney(expectedCash);
  String get formattedNetResult => formatMoney(netResult);

  String get formattedPrevTotalReceived => formatMoney(prevTotalReceived);
  String get formattedPrevNetResult => formatMoney(prevNetResult);

  /// Variación porcentual de ventas vs período anterior.
  double? get salesGrowthPercent {
    if (prevTotalReceived <= 0) return null;
    return ((totalReceived - prevTotalReceived) / prevTotalReceived) * 100.0;
  }

  /// Texto explicativo de tendencia vs período anterior.
  String get salesGrowthText {
    final growth = salesGrowthPercent;
    if (growth == null) {
      if (totalReceived > 0 && prevTotalReceived == 0) {
        return 'Primer período con ventas registradas';
      }
      return 'Sin historial en período anterior';
    }
    final prefix = growth >= 0 ? '+' : '';
    return '$prefix${growth.toStringAsFixed(1)}% vs período anterior';
  }

  /// Variación absoluta en dinero.
  double get salesGrowthDelta => totalReceived - prevTotalReceived;
  String get formattedSalesGrowthDelta => formatMoney(salesGrowthDelta.abs());
}

class ReportCommissionItem {
  final String stylistId;
  final String stylistName;
  final int servicesCount;
  final double serviceSales;
  final double commissionTotal;

  const ReportCommissionItem({
    required this.stylistId,
    required this.stylistName,
    required this.servicesCount,
    required this.serviceSales,
    required this.commissionTotal,
  });

  factory ReportCommissionItem.fromMap(Map<String, dynamic> map) {
    return ReportCommissionItem(
      stylistId: map['stylist_id']?.toString() ?? '',
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      servicesCount: int.tryParse(map['services_count']?.toString() ?? '') ?? 0,
      serviceSales: double.tryParse(map['service_sales']?.toString() ?? '') ?? 0,
      commissionTotal: double.tryParse(map['commission_total']?.toString() ?? '') ?? 0,
    );
  }

  String get formattedServiceSales => formatMoney(serviceSales);
  String get formattedCommissionTotal => formatMoney(commissionTotal);
}

class ReportServiceSaleItem {
  final String serviceName;
  final String stylistName;
  final int ticketsCount;
  final double totalSales;
  final int totalDurationMinutes;

  const ReportServiceSaleItem({
    required this.serviceName,
    required this.stylistName,
    required this.ticketsCount,
    required this.totalSales,
    required this.totalDurationMinutes,
  });

  factory ReportServiceSaleItem.fromMap(Map<String, dynamic> map) {
    return ReportServiceSaleItem(
      serviceName: map['service_name']?.toString() ?? 'Sin servicio',
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      ticketsCount: int.tryParse(map['tickets_count']?.toString() ?? '') ?? 0,
      totalSales: double.tryParse(map['total_sales']?.toString() ?? '') ?? 0,
      totalDurationMinutes: int.tryParse(map['total_duration_minutes']?.toString() ?? '') ?? 0,
    );
  }

  String get formattedTotalSales => formatMoney(totalSales);
}

/// Una sede dentro del reporte consolidado (D-194).
///
/// Sale gratis: el consolidado calcula cada sede por separado y las suma, asi
/// que el desglose ya estaba hecho.
class ReportBranchItem {
  const ReportBranchItem({
    required this.branchId,
    required this.branchName,
    required this.isPrimary,
    required this.totalReceived,
    required this.netResult,
    required this.totalExpenses,
    required this.totalPurchases,
    required this.totalCommissions,
    required this.expectedCash,
    required this.paymentsCount,
  });

  final String branchId;
  final String branchName;
  final bool isPrimary;
  final double totalReceived;
  final double netResult;
  final double totalExpenses;
  final double totalPurchases;
  final double totalCommissions;
  final double expectedCash;
  final int paymentsCount;

  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory ReportBranchItem.fromMap(Map<String, dynamic> map) {
    return ReportBranchItem(
      branchId: map['branch_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      isPrimary: map['is_primary'] == true,
      totalReceived: _num(map['total_received']),
      netResult: _num(map['net_result']),
      totalExpenses: _num(map['total_expenses']),
      totalPurchases: _num(map['total_purchases']),
      totalCommissions: _num(map['total_commissions']),
      expectedCash: _num(map['expected_cash']),
      paymentsCount: map['payments_count'] is int
          ? map['payments_count'] as int
          : int.tryParse(map['payments_count']?.toString() ?? '') ?? 0,
    );
  }
}
