class FinancialSummary {
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double totalCommissions;
  final double netResult;

  const FinancialSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalCommissions,
    required this.netResult,
  });

  factory FinancialSummary.fromMap(Map<String, dynamic> map) {
    return FinancialSummary(
      totalSales: (map['total_sales'] as num).toDouble(),
      totalPurchases: (map['total_purchases'] as num).toDouble(),
      totalExpenses: (map['total_expenses'] as num).toDouble(),
      totalCommissions: (map['total_commissions'] as num).toDouble(),
      netResult: (map['net_result'] as num).toDouble(),
    );
  }

  String get formattedTotalSales {
    return '\$${totalSales.toStringAsFixed(0)}';
  }

  String get formattedTotalPurchases {
    return '\$${totalPurchases.toStringAsFixed(0)}';
  }

  String get formattedTotalExpenses {
    return '\$${totalExpenses.toStringAsFixed(0)}';
  }

  String get formattedTotalCommissions {
    return '\$${totalCommissions.toStringAsFixed(0)}';
  }

  String get formattedNetResult {
    return '\$${netResult.toStringAsFixed(0)}';
  }

  String get netResultText {
    if (netResult > 0) {
      return 'Ganancia';
    }

    if (netResult < 0) {
      return 'Perdida';
    }

    return 'Punto de equilibrio';
  }
}
