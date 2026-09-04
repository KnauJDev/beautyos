import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_context.dart';
import 'package:salonymas/models/periodo_dashboard.dart';
import 'package:salonymas/pages/dashboard_page.dart';
import 'package:salonymas/theme/app_theme.dart';

/// El Dashboard hace caso a la sede activa, y deja mirar el negocio entero
/// (D-205).
///
/// **Qué cambió.** Hasta este bloque el Dashboard arrancaba en consolidado y
/// **no hacía caso a la píldora de sede de la cabecera**: se cambiaba de sede
/// arriba y los números seguían siendo los de todo el negocio. Ahora la
/// píldora manda y un botón de dos posiciones —el mismo de Reportes (D-194)—
/// decide si se mira una sede o todas.
///
/// **Estas pruebas ejercitan el comportamiento**, siguiendo la lección de
/// D-203 y D-204: la función de ámbito se prueba con sus valores reales, y el
/// control se monta y se toca de verdad.
void main() {
  BranchContext sede(String id, String nombre) => BranchContext.fromMap({
    'tenant_id': 't1',
    'tenant_name': 'Salón Demo',
    'branch_id': id,
    'branch_name': nombre,
    'role': 'tenant_owner',
    'timezone': 'America/Bogota',
    'currency_code': 'COP',
    'is_primary': true,
    'option_count': 2,
  });

  group('D-205 — Qué sedes consulta el Dashboard', () {
    test('en "esta sede" consulta solo la sede activa', () {
      expect(
        sedesDelDashboard(consolidado: false, branchId: 'sede-1'),
        ['sede-1'],
        reason:
            'Es el cambio de fondo de D-205: el Dashboard tiene que hacer '
            'caso a la píldora de sede en vez de abrir siempre en global.',
      );
    });

    test('en "todas las sedes" manda la lista vacía, que el SQL lee como sin filtro', () {
      // DashboardService traduce la lista vacía a `p_branch_ids: null`, y el
      // SQL lo trata como "todas las que este usuario alcance"
      // (`p_branch_ids is null or cardinality(p_branch_ids) = 0`).
      expect(
        sedesDelDashboard(consolidado: true, branchId: 'sede-1'),
        isEmpty,
        reason:
            'Si aquí se colara la sede activa, "Todas las sedes" enseñaría '
            'los números de una sola y nadie lo notaría: el número sería '
            'plausible, solo que incompleto.',
      );
    });

    test('el ámbito manda sobre la sede, no al revés', () {
      // Con la misma sede activa, las dos respuestas tienen que ser distintas.
      final unaSede = sedesDelDashboard(consolidado: false, branchId: 'x');
      final todas = sedesDelDashboard(consolidado: true, branchId: 'x');
      expect(unaSede, isNot(equals(todas)));
    });
  });

  group('D-205 — El selector de ámbito en la cabecera', () {
    Widget montar({
      required List<BranchContext> branches,
      required bool consolidado,
      ValueChanged<bool>? onAmbito,
    }) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ControlesDelDashboard(
            periodo: PeriodoDashboard.esteMes,
            hoy: DateTime(2026, 9, 4),
            branches: branches,
            consolidado: consolidado,
            onPeriodo: (_) {},
            onAmbito: onAmbito ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('con una sola sede el botón no se dibuja', (tester) async {
      await tester.pumpWidget(
        montar(branches: [sede('sede-1', 'Principal')], consolidado: false),
      );

      expect(
        find.byType(SegmentedButton<bool>),
        findsNothing,
        reason:
            'Con una sede sería un botón que no hace nada. Mismo criterio que '
            'Reportes (D-194) y que la casita de la barra de celular (D-106).',
      );
    });

    testWidgets('con dos sedes aparece, y arranca en "Esta sede"', (
      tester,
    ) async {
      await tester.pumpWidget(
        montar(
          branches: [sede('sede-1', 'Principal'), sede('sede-2', 'Norte')],
          consolidado: false,
        ),
      );

      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('Esta sede'), findsOneWidget);
      expect(find.text('Todas las sedes'), findsOneWidget);

      final boton = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(
        boton.selected,
        {false},
        reason:
            'El Dashboard abre en la sede activa desde D-205. Si arranca en '
            'true, volvimos a ignorar la píldora de sede.',
      );
    });

    testWidgets('tocar "Todas las sedes" pide el consolidado', (tester) async {
      final recibido = <bool>[];

      await tester.pumpWidget(
        montar(
          branches: [sede('sede-1', 'Principal'), sede('sede-2', 'Norte')],
          consolidado: false,
          onAmbito: recibido.add,
        ),
      );

      await tester.tap(find.text('Todas las sedes'));
      await tester.pumpAndSettle();

      expect(recibido, [true]);
    });

    testWidgets('y desde el consolidado se puede volver a la sede', (
      tester,
    ) async {
      final recibido = <bool>[];

      await tester.pumpWidget(
        montar(
          branches: [sede('sede-1', 'Principal'), sede('sede-2', 'Norte')],
          consolidado: true,
          onAmbito: recibido.add,
        ),
      );

      final boton = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(boton.selected, {true});

      await tester.tap(find.text('Esta sede'));
      await tester.pumpAndSettle();

      expect(recibido, [false]);
    });
  });
}
