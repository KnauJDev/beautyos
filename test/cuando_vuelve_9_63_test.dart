import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/cuando_vuelve.dart';
import 'package:salonymas/services/cuando_vuelve_service.dart';
import 'package:salonymas/widgets/cuando_vuelve_en_la_ficha.dart';
import 'package:salonymas/widgets/hoja_cuando_vuelve.dart';

/// Paso 9.63 (D-323), pedido de David el 08-oct: cuándo vuelve cada clienta.
/// Prototipo: https://claude.ai/artifact/N48aApd2qmN17Fxc5kHTne
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

VueltaAlCerrar vuelta(
  String id,
  String nombre, {
  int? suyo,
  int? servicio,
  int salon = 45,
  String estado = 'finalizado',
}) => VueltaAlCerrar(
  ticketServiceId: 'ts-$id',
  serviceId: 's-$id',
  serviceName: nombre,
  serviceStatus: estado,
  clientDays: suyo,
  serviceDays: servicio,
  defaultDays: salon,
);

/// Ana: el tinte con su número (30) y el corte con el del servicio (45).
final deAna = [
  vuelta('tinte', 'Tinte completo', suyo: 30, servicio: 45),
  vuelta('corte', 'Corte dama', servicio: 45),
];

class FakeCuandoVuelve extends CuandoVuelveService {
  FakeCuandoVuelve({this.alCerrar = const [], this.ficha = const []})
    : super(branchId: 'b1');

  final List<VueltaAlCerrar> alCerrar;
  List<VueltaDeLaClienta> ficha;
  final guardados = <({String ts, int? dias, bool invitar})>[];
  final fijados = <({String servicio, int? dias})>[];

  @override
  Future<List<VueltaAlCerrar>> paraCerrar(String ticketId) async => alCerrar;

  @override
  Future<void> guardarAlCerrar({
    required String ticketServiceId,
    required int? dias,
    required bool invitar,
  }) async => guardados.add((ts: ticketServiceId, dias: dias, invitar: invitar));

  @override
  Future<List<VueltaDeLaClienta>> deLaClienta(String clientId) async => ficha;

  @override
  Future<void> fijarDeLaClienta({
    required String clientId,
    required String serviceId,
    required int? dias,
  }) async => fijados.add((servicio: serviceId, dias: dias));
}

void main() {
  group('el número que viene lleno', () {
    test('el suyo; si no, el del servicio; si no, el del salón', () {
      expect((deAna[0].dias, deAna[0].origen), (30, OrigenDelNumero.suyo));
      expect((deAna[1].dias, deAna[1].origen), (45, OrigenDelNumero.delServicio));
      final sinNada = vuelta('x', 'Uñas');
      expect((sinNada.dias, sinNada.origen), (45, OrigenDelNumero.delSalon));
    });

    test('dejar el que venía, sin número propio, guarda vacío: sigue al del servicio', () {
      expect(deAna[1].diasParaGuardar(45), isNull);
      expect(deAna[1].diasParaGuardar(60), 60);
      // Si ya tenía el suyo, se guarda lo elegido.
      expect(deAna[0].diasParaGuardar(45), 45);
    });

    test('la fecha y el aviso de Listo', () {
      final hoy = DateTime(2026, 10, 8);
      expect(fechaDeVolver(hoy, 30), '7 de noviembre');
      expect(primerNombre('Ana Torres'), 'Ana');
      expect(
        resumenDeLaVuelta(
          nombre: 'Ana',
          respuestas: [
            (servicio: 'Tinte completo', dias: 30, invitar: true),
            (servicio: 'Corte dama', dias: 45, invitar: false),
          ],
          hoy: hoy,
        ),
        'Listo. Invitaremos a Ana a volver: Tinte completo en 30 días (7 de noviembre). Por Corte dama, esta vez no.',
      );
      expect(
        resumenDeLaVuelta(
          nombre: 'Ana',
          respuestas: [(servicio: 'Corte dama', dias: 45, invitar: false)],
          hoy: hoy,
        ),
        'Esta vez no invitaremos a Ana. Cuando vuelva, te preguntamos otra vez.',
      );
    });

    test('la ficha dice cada cuánto, de dónde sale y cuándo le toca', () {
      final hoy = DateTime(2026, 10, 8, 15);
      VueltaDeLaClienta f({int? suyo, bool salto = false}) => VueltaDeLaClienta(
        serviceId: 's',
        serviceName: 'Tinte',
        clientDays: suyo,
        serviceDays: 45,
        defaultDays: 45,
        lastDoneAt: DateTime(2026, 9, 13, 10),
        skipped: salto,
      );
      expect(f(suyo: 30).cadaCuanto, 'Cada 30 días · suyo');
      expect(f().cadaCuanto, 'Cada 45 días · el del servicio');
      expect(f(suyo: 30).cuando(hoy), 'Última vez hace 25 días · le toca en 5 días');
      expect(f(suyo: 20).cuando(hoy), 'Última vez hace 25 días · ya le toca volver');
      expect(f(salto: true).cuando(hoy), 'Última vez hace 25 días · esta vez no se invita');
    });
  });

  group('la hoja al cerrar', () {
    Future<List<RespuestaDeVuelta>?> abrir(WidgetTester tester, List<VueltaAlCerrar> vueltas, {double ancho = 800}) async {
      tester.view.physicalSize = Size(ancho, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<RespuestaDeVuelta>? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await showModalBottomSheet<List<RespuestaDeVuelta>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => HojaCuandoVuelve(
                    vueltas: vueltas,
                    nombre: 'Ana',
                    hoy: DateTime(2026, 10, 8),
                    citaCerrada: true,
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('sale ya llena, con de dónde sale cada número', (tester) async {
      await abrir(tester, deAna);
      expect(find.text('Cita cerrada. ¿Cuándo invitamos a Ana a volver?'), findsOneWidget);
      expect(find.text('El de Ana'), findsOneWidget);
      expect(find.text('El del servicio'), findsOneWidget);
      expect(find.text('30 días'), findsNWidgets(3)); // dos atajos y el número
      expect(find.text('Le toca volver el 7 de noviembre'), findsOneWidget);
      expect(find.text('Invitar a volver'), findsNWidgets(2));
    });

    testWidgets('el interruptor apagado: "esta vez no", y Listo lo devuelve', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<RespuestaDeVuelta>? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await showModalBottomSheet<List<RespuestaDeVuelta>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => HojaCuandoVuelve(vueltas: deAna, nombre: 'Ana', hoy: DateTime(2026, 10, 8)),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // El corte: se apaga. El tinte: 60 días.
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(
        find.text('Esta vez no invitaremos a Ana por Corte dama. Cuando vuelva a hacérselo, te preguntamos otra vez.'),
        findsOneWidget,
      );
      await tester.tap(find.text('60 días'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Más días'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!.map((r) => (r.vuelta.serviceName, r.dias, r.invitar)), [
        ('Tinte completo', 61, true),
        ('Corte dama', 45, false),
      ]);
    });

    testWidgets('en un celular, sin desbordes', (tester) async {
      await abrir(tester, [
        ...deAna,
        vuelta('k', 'Keratina y tratamiento alisador y reconstructor', servicio: 90),
      ], ancho: 360);
      expect(tester.takeException(), isNull);
    });
  });

  group('preguntar y guardar', () {
    Future<FakeCuandoVuelve> correr(WidgetTester tester, FakeCuandoVuelve falso, {Set<String>? solo}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => preguntarCuandoVuelve(
                context,
                servicio: falso,
                ticketId: 't1',
                nombreDeLaClienta: 'Ana Torres',
                soloEstos: solo,
              ),
              child: const Text('cerrar'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('cerrar'));
      await tester.pumpAndSettle();
      return falso;
    }

    testWidgets('solo los servicios terminados; Listo guarda cada uno', (tester) async {
      final falso = await correr(tester, FakeCuandoVuelve(alCerrar: [
        ...deAna,
        vuelta('u', 'Uñas', estado: 'cancelado'),
      ]));
      expect(find.text('Uñas'), findsNothing);
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      // El tinte guarda su 30; el corte, vacío (sigue al del servicio).
      expect(falso.guardados, [
        (ts: 'ts-tinte', dias: 30, invitar: true),
        (ts: 'ts-corte', dias: null, invitar: true),
      ]);
      expect(find.textContaining('Listo. Invitaremos a Ana a volver'), findsOneWidget);
    });

    testWidgets('la estilista contesta solo el servicio que terminó', (tester) async {
      final falso = await correr(tester, FakeCuandoVuelve(alCerrar: deAna), solo: {'ts-corte'});
      expect(find.text('Tinte completo'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(falso.guardados, [(ts: 'ts-corte', dias: null, invitar: false)]);
    });

    testWidgets('sin servicios terminados no sale nada', (tester) async {
      final falso = await correr(tester, FakeCuandoVuelve(alCerrar: [vuelta('x', 'Uñas', estado: 'en_proceso')]));
      expect(find.text('Listo'), findsNothing);
      expect(falso.guardados, isEmpty);
    });
  });

  group('la ficha de la clienta', () {
    VueltaDeLaClienta fila(String id, String nombre, {int? suyo}) => VueltaDeLaClienta(
      serviceId: id,
      serviceName: nombre,
      clientDays: suyo,
      serviceDays: 45,
      defaultDays: 45,
      lastDoneAt: DateTime(2026, 9, 13),
      skipped: false,
    );

    Future<FakeCuandoVuelve> ficha(WidgetTester tester, List<VueltaDeLaClienta> filas) async {
      final falso = FakeCuandoVuelve(ficha: filas);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CuandoVuelveEnLaFicha(
              servicio: falso,
              clientId: 'c1',
              nombre: 'Ana',
              ahora: DateTime(2026, 10, 8),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return falso;
    }

    testWidgets('Cambiar y Guardar le pone su número', (tester) async {
      final falso = await ficha(tester, [fila('tinte', 'Tinte completo')]);
      expect(find.text('Cada 45 días · el del servicio'), findsOneWidget);
      expect(find.text('Última vez hace 25 días · le toca en 20 días'), findsOneWidget);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Usar el del servicio'), findsNothing);
      await tester.tap(find.text('30 días'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(falso.fijados, [(servicio: 'tinte', dias: 30)]);
    });

    testWidgets('con número propio, "Usar el del servicio" se lo quita', (tester) async {
      final falso = await ficha(tester, [fila('tinte', 'Tinte completo', suyo: 30)]);
      expect(find.text('Cada 30 días · suyo'), findsOneWidget);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar el del servicio (45 días)'));
      await tester.pumpAndSettle();
      expect(falso.fijados, [(servicio: 'tinte', dias: null)]);
    });

    testWidgets('sin servicios hechos, lo dice', (tester) async {
      await ficha(tester, const []);
      expect(find.textContaining('Todavía no se ha hecho ningún servicio'), findsOneWidget);
    });
  });

  test('sale en los tres cierres y en la ficha', () {
    final agenda = leer('lib/pages/agenda_page.dart');
    expect(agenda, contains('if (propio == null && accion == AccionDeTresEstados.cerrar && mounted) {'));
    expect(agenda, contains('citaCerrada: true,'));
    final estilista = leer('lib/pages/my_stylist_agenda_page.dart');
    expect(estilista, contains("if (newStatus == 'finalizado') {"));
    expect(estilista, contains('soloEstos: {item.ticketServiceId},'));
    // Con caja, al Finalizar en Tickets y Caja (decidido el 08-oct).
    final caja = leer('lib/pages/tickets_page.dart');
    expect(caja, contains('// 9.63 (D-323): también con caja'));
    expect(caja, contains('soloEstos: {servicio.ticketServiceId},'));
    final clientes = leer('lib/pages/clients_page.dart');
    expect(clientes, contains("title: 'Cuándo vuelve, por servicio',"));
  });
}
