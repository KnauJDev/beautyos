import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_subscription.dart';
import 'package:salonymas/models/cerrar_sede.dart';
import 'package:salonymas/services/cerrar_sede_service.dart';
import 'package:salonymas/widgets/cerrar_sede_dialogos.dart';

/// Paso 9.65 (D-328, hallazgo CQ): cerrar una sede sin borrar nada.
/// Prototipo: https://claude.ai/artifact/FKNnRij9kGtaNWPknX6HZB
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

class FakeCerrar extends CerrarSedeService {
  FakeCerrar({bool plataforma = false, this.citas = const []})
    : super(desdeLaPlataforma: plataforma);

  final List<CitaProxima> citas;
  final cerradas = <String>[];
  final reabiertas = <String>[];

  @override
  Future<List<CitaProxima>> proximasCitas(String branchId) async => citas;

  @override
  Future<void> cerrar(String branchId) async => cerradas.add(branchId);

  @override
  Future<void> reabrir(String branchId) async => reabiertas.add(branchId);
}

CitaProxima cita(DateTime cuando, {String? clienta, String servicio = 'Tinte'}) =>
    CitaProxima(scheduledAt: cuando, clientName: clienta, serviceNames: servicio);

void main() {
  group('los estados y las citas', () {
    test('los estados de una sede, en español', () {
      expect(etiquetaDelEstadoDeSede('past_due'), 'Vencida');
      expect(etiquetaDelEstadoDeSede('suspended'), 'Suspendida');
      expect(etiquetaDelEstadoDeSede('active'), 'Activa · al día');
      expect(estadosDeSede.keys, ['pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled']);
    });

    test('una cita próxima, como se lee', () {
      final c = cita(DateTime(2026, 10, 10, 15), clienta: 'Ana Torres');
      expect(c.texto, 'Sáb 10 oct · 3:00 p. m. · Ana · Tinte');
      // La plataforma no ve a la clienta.
      expect(cita(DateTime(2026, 10, 13, 9, 30)).texto, 'Mar 13 oct · 9:30 a. m. · Tinte');
    });

    test('una sede cerrada dice "Cerrada" en Tus sedes', () {
      const sede = BranchSubscription(
        branchId: 'b2',
        branchName: 'Norte',
        isPrimary: false,
        branchActive: false,
        status: 'cancelled',
        alDia: false,
        precioCop: 150000,
        motivoPrecio: 'Precio de lista',
      );
      expect(sede.etiquetaEstado, 'Cerrada');
    });
  });

  group('cerrar con cuidado', () {
    Future<bool?> correr(WidgetTester tester, FakeCerrar falso, {bool reabrir = false}) async {
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = reabrir
                    ? await reabrirSede(context, servicio: falso, branchId: 'b2', nombre: 'Norte')
                    : await cerrarSedeConCuidado(context, servicio: falso, branchId: 'b2', nombre: 'Norte');
              },
              child: const Text('ir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('con citas próximas no deja, y dice cuáles', (tester) async {
      final falso = FakeCerrar(citas: [
        cita(DateTime(2026, 10, 10, 15), clienta: 'Ana Torres'),
        cita(DateTime(2026, 10, 11, 10), clienta: 'Luisa Gómez', servicio: 'Corte'),
      ]);
      await correr(tester, falso);
      expect(find.text('Norte tiene 2 citas próximas'), findsOneWidget);
      expect(find.text('• Sáb 10 oct · 3:00 p. m. · Ana · Tinte'), findsOneWidget);
      expect(find.textContaining('Así no se puede cerrar'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(falso.cerradas, isEmpty);
    });

    testWidgets('sin citas, pregunta y la cierra', (tester) async {
      final falso = FakeCerrar();
      await correr(tester, falso);
      expect(find.text('¿Cerrar Norte?'), findsOneWidget);
      expect(find.textContaining('se conservan y siguen en los reportes'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sede'));
      await tester.pumpAndSettle();
      expect(falso.cerradas, ['b2']);
      expect(find.text('Norte quedó cerrada. Su historial se conserva.'), findsOneWidget);
    });

    testWidgets('Cancelar no cierra nada', (tester) async {
      final falso = FakeCerrar();
      await correr(tester, falso);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(falso.cerradas, isEmpty);
    });

    testWidgets('el dueño la reabre pendiente de pago; la plataforma, activa', (tester) async {
      final salon = FakeCerrar();
      await correr(tester, salon, reabrir: true);
      expect(find.textContaining('pendiente de pago, como una sede nueva'), findsOneWidget);
      await tester.tap(find.text('Volver a abrir'));
      await tester.pumpAndSettle();
      expect(salon.reabiertas, ['b2']);

      final panel = FakeCerrar(plataforma: true);
      await correr(tester, panel, reabrir: true);
      expect(find.textContaining('queda activa'), findsOneWidget);
    });
  });

  test('el Panel, Tus sedes y la app', () {
    final panel = leer('lib/pages/platform_panel_page.dart');
    expect(panel, contains("label: Text(sede.branchActive ? 'Cerrar sede' : 'Volver a abrir'),"));
    expect(panel, contains('child: Text(etiquetaDelEstadoDeSede(e)),'));
    expect(panel, contains('Esto borra el negocio entero, con todas sus '));
    expect(panel, contains('const servicio = CerrarSedeService(desdeLaPlataforma: true);'));
    final tarjeta = leer('lib/widgets/sedes_suscripcion_card.dart');
    expect(tarjeta, contains("'Sedes cerradas',"));
    expect(tarjeta, contains('onCerrarOAbrir: widget.puedeCerrar && !s.isPrimary'));
    final ajustes = leer('lib/pages/settings_page.dart');
    expect(ajustes, contains('_SubscriptionSettingsCard(onSedesCambiaron: widget.onSedeCreada),'));
    // Si la sede elegida se cerró, la app vuelve a la principal.
    final app = leer('lib/main.dart');
    expect(app, contains('branches.any((b) => b.branchId == elegida.branchId)'));
  });
}
