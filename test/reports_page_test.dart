import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_report_v3.dart';

void main() {
  group('BranchReportV3 Model - Métricas Financieras y Comparación (Paso 4.7 / D-154)', () {
    test('Parsea reporte completo con métodos de pago, comisiones y servicios', () {
      final map = {
        'start_date': '2026-08-18',
        'end_date': '2026-08-18',
        'total_received': 350000,
        'payments_count': 5,
        'paid_tickets_count': 4,
        'cash_received': 100000,
        'card_received': 100000,
        'transfer_received': 150000,
        'other_received': 0,
        'total_purchases': 50000,
        'cash_purchases': 50000,
        'total_expenses': 20000,
        'cash_expenses': 0,
        'total_commissions': 80000,
        'commission_services_count': 6,
        'expected_cash': 50000,
        'net_result': 200000,
        'prev_total_received': 300000,
        'prev_net_result': 180000,
        'prev_payments_count': 4,
        'commissions_by_stylist': [
          {
            'stylist_id': 's1',
            'stylist_name': 'Estilista Uno',
            'services_count': 4,
            'service_sales': 200000,
            'commission_total': 80000,
          }
        ],
        'sales_by_service': [
          {
            'service_name': 'Balayage',
            'stylist_name': 'Estilista Uno',
            'tickets_count': 2,
            'total_sales': 200000,
            'total_duration_minutes': 240,
          }
        ],
      };

      final report = BranchReportV3.fromMap(map);

      expect(report.totalReceived, 350000);
      expect(report.cashReceived, 100000);
      expect(report.cardReceived, 100000);
      expect(report.transferReceived, 150000);
      expect(report.totalPurchases, 50000);
      expect(report.totalExpenses, 20000);
      expect(report.totalCommissions, 80000);
      expect(report.expectedCash, 50000);
      expect(report.netResult, 200000);
      expect(report.formattedTotalReceived, '\$350.000');
      expect(report.formattedCashReceived, '\$100.000');
      expect(report.formattedExpectedCash, '\$50.000');
      expect(report.formattedNetResult, '\$200.000');

      // Comparación temporal
      expect(report.prevTotalReceived, 300000);
      expect(report.salesGrowthPercent, closeTo(16.66, 0.1));
      expect(report.salesGrowthText, '+16.7% vs período anterior');
      expect(report.salesGrowthDelta, 50000);
      expect(report.formattedSalesGrowthDelta, '\$50.000');

      // Desglose de comisiones y ventas
      expect(report.commissionsByStylist.length, 1);
      expect(report.commissionsByStylist.first.stylistName, 'Estilista Uno');
      expect(report.commissionsByStylist.first.formattedCommissionTotal, '\$80.000');

      expect(report.salesByService.length, 1);
      expect(report.salesByService.first.serviceName, 'Balayage');
      expect(report.salesByService.first.formattedTotalSales, '\$200.000');
    });

    test('Maneja correctamente comparación con período previo en baja (-20%)', () {
      final map = {
        'start_date': '2026-08-18',
        'end_date': '2026-08-18',
        'total_received': 80000,
        'prev_total_received': 100000,
      };

      final report = BranchReportV3.fromMap(map);

      expect(report.salesGrowthPercent, -20.0);
      expect(report.salesGrowthText, '-20.0% vs período anterior');
      expect(report.salesGrowthDelta, -20000);
      expect(report.formattedSalesGrowthDelta, '\$20.000');
    });

    test('Maneja con elegancia primer período sin historial previo', () {
      final map = {
        'start_date': '2026-08-18',
        'end_date': '2026-08-18',
        'total_received': 120000,
        'prev_total_received': 0,
      };

      final report = BranchReportV3.fromMap(map);

      expect(report.salesGrowthPercent, isNull);
      expect(report.salesGrowthText, 'Primer período con ventas registradas');
    });
  });
}
