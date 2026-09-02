import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_report_v3.dart';

void main() {
  Map<String, dynamic> base({
    Object? branchesCount,
    Object? byBranch,
  }) => {
    'start_date': '2026-09-01',
    'end_date': '2026-09-02',
    'total_received': 450000,
    'payments_count': 12,
    'paid_tickets_count': 9,
    'cash_received': 200000,
    'card_received': 100000,
    'transfer_received': 150000,
    'other_received': 0,
    'total_purchases': 50000,
    'cash_purchases': 50000,
    'total_expenses': 80000,
    'cash_expenses': 80000,
    'total_commissions': 90000,
    'commission_services_count': 9,
    'expected_cash': 70000,
    'net_result': 230000,
    'prev_total_received': 400000,
    'prev_net_result': 200000,
    'prev_payments_count': 10,
    'commissions_by_stylist': const [],
    'sales_by_service': const [],
    if (branchesCount != null) 'branches_count': branchesCount,
    if (byBranch != null) 'by_branch': byBranch,
  };

  group('D-194 — Reporte consolidado de varias sedes', () {
    test('un reporte de una sola sede no se cree consolidado', () {
      // La RPC de una sede no devuelve estos campos: el modelo tiene que
      // asumir una sola sede y no dibujar el desglose.
      final r = BranchReportV3.fromMap(base());

      expect(r.branchesCount, 1);
      expect(r.byBranch, isEmpty);
      expect(r.esConsolidado, false);
    });

    test('el consolidado trae el desglose por sede', () {
      final r = BranchReportV3.fromMap(
        base(
          branchesCount: 2,
          byBranch: const [
            {
              'branch_id': 'a',
              'branch_name': 'Chapinero',
              'is_primary': true,
              'total_received': 300000,
              'net_result': 160000,
              'total_expenses': 50000,
              'total_purchases': 30000,
              'total_commissions': 60000,
              'expected_cash': 45000,
              'payments_count': 8,
            },
            {
              'branch_id': 'b',
              'branch_name': 'Suba',
              'is_primary': false,
              'total_received': 150000,
              'net_result': 70000,
              'total_expenses': 30000,
              'total_purchases': 20000,
              'total_commissions': 30000,
              'expected_cash': 25000,
              'payments_count': 4,
            },
          ],
        ),
      );

      expect(r.esConsolidado, true);
      expect(r.branchesCount, 2);
      expect(r.byBranch, hasLength(2));
      expect(r.byBranch.first.branchName, 'Chapinero');
      expect(r.byBranch.first.isPrimary, true);
    });

    test('las sedes del desglose suman el total del consolidado', () {
      final r = BranchReportV3.fromMap(
        base(
          branchesCount: 2,
          byBranch: const [
            {'branch_name': 'Chapinero', 'total_received': 300000, 'net_result': 160000},
            {'branch_name': 'Suba', 'total_received': 150000, 'net_result': 70000},
          ],
        ),
      );

      // Si esto dejara de cuadrar, el dueño vería un total que no es la suma
      // de lo que tiene debajo, y dejaría de creerse el reporte entero.
      final sumaVentas = r.byBranch.fold<double>(
        0,
        (a, s) => a + s.totalReceived,
      );
      final sumaResultado = r.byBranch.fold<double>(
        0,
        (a, s) => a + s.netResult,
      );

      expect(sumaVentas, r.totalReceived);
      expect(sumaResultado, r.netResult);
    });

    test('un desglose con campos ausentes no rompe la pantalla', () {
      final r = BranchReportV3.fromMap(
        base(
          branchesCount: 2,
          byBranch: const [
            {'branch_name': 'Sin cifras'},
          ],
        ),
      );

      expect(r.byBranch.single.branchName, 'Sin cifras');
      expect(r.byBranch.single.totalReceived, 0);
      expect(r.byBranch.single.isPrimary, false);
    });

    test('branches_count como texto se lee igual', () {
      final r = BranchReportV3.fromMap(base(branchesCount: '3'));

      expect(r.branchesCount, 3);
      expect(r.esConsolidado, true);
    });
  });
}
