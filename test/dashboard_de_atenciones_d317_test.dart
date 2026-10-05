import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/dashboard_de_atenciones.dart';
import 'package:salonymas/models/periodo_dashboard.dart';
import 'package:salonymas/models/tenant_entitlements.dart';
import 'package:salonymas/pages/dashboard_de_atenciones_page.dart';
import 'package:salonymas/services/dashboard_service.dart';
import 'package:salonymas/widgets/graficos_de_atenciones.dart';

/// D-317 (04-oct): el Dashboard de atenciones de los negocios sin caja, y su
/// propio interruptor en el Panel. El propietario aprobó el prototipo
/// (https://claude.ai/artifact/Ptnrpy3N23NbSATn2n3BP3); el servidor lo prueba
/// el control 244. Aquí: leer la respuesta, la historia en palabras, el
/// tablero dibujado en un celular y en un computador, y el cableado.

/// Lo que devuelve `get_dashboard_atenciones` para la semana del control 244
/// (3 atendidas, 1 nueva, 1 cancelada, 1 que no llegó, 1 en línea).
Map<String, dynamic> respuestaDeEjemplo() => {
  'hoy_en_la_sede': '2026-10-04',
  'granularidad': 'day',
  'sedes': 1,
  'hoy': {'citas': 2, 'cerradas': 0, 'en_proceso': 1, 'por_atender': 1},
  'actual': {
    'atendidas': 3, 'clientas': 2, 'nuevas': 1, 'canceladas': 1,
    'no_llegaron': 1, 'en_linea': 1, 'minutos': 165,
  },
  'anterior': {
    'atendidas': 1, 'clientas': 1, 'nuevas': 1, 'canceladas': 0,
    'no_llegaron': 0, 'en_linea': 0, 'minutos': 45,
  },
  'serie': [
    for (var d = 28; d <= 30; d++) {'bucket': '2026-09-$d', 'atendidas': d == 30 ? 1 : 0},
    {'bucket': '2026-10-01', 'atendidas': 1},
    {'bucket': '2026-10-02', 'atendidas': 0},
    {'bucket': '2026-10-03', 'atendidas': 1},
    {'bucket': '2026-10-04', 'atendidas': 0},
  ],
  'serie_anterior': [
    for (var d = 21; d <= 27; d++) {'bucket': '2026-09-$d', 'atendidas': d == 24 ? 1 : 0},
  ],
  'calor': [
    {'dia_semana': 3, 'hora': 10, 'atendidas': 1},
    {'dia_semana': 5, 'hora': 10, 'atendidas': 1},
    {'dia_semana': 6, 'hora': 15, 'atendidas': 1},
  ],
  'servicios': [
    {'service_id': 's-unas', 'nombre': 'Uñas', 'categoria': 'Uñas', 'duracion': 60, 'atenciones': 2, 'minutos': 120},
    {'service_id': 's-corte', 'nombre': 'Corte', 'categoria': 'Cabello', 'duracion': 45, 'atenciones': 1, 'minutos': 45},
  ],
  'equipo': [
    {'stylist_id': 'e-juliana', 'nombre': 'Juliana', 'citas': 2, 'minutos': 120, 'nuevas': 1, 'en_linea': 0, 'calificacion': null, 'resenas': 0},
    {'stylist_id': 'e-paola', 'nombre': 'Paola', 'citas': 1, 'minutos': 45, 'nuevas': 0, 'en_linea': 1, 'calificacion': 5.00, 'resenas': 1},
  ],
  'semanas': [
    {'semana': '2026-09-28', 'nuevas': 1, 'vuelven': 1},
  ],
  'invitaciones': {'enviadas': 2, 'agendaron': 1},
  'perdidas_por_dia': [
    {'dia_semana': 2, 'n': 1},
    {'dia_semana': 3, 'n': 1},
  ],
  'perdidas_en_linea': 1,
  'motivos': [
    {'estado': 'cancelado', 'motivo': 'Avisó que no podía venir', 'dia': '2026-09-30', 'servicios': 'Corte', 'estilistas': 'Paola'},
    {'estado': 'no_asistio', 'motivo': 'No llegó', 'dia': '2026-09-29', 'servicios': 'Uñas', 'estilistas': 'Juliana'},
  ],
};

String texto(List<TrozoDeHistoria> t) => t.map((x) => x.texto).join();

void main() {
  group('la respuesta del servidor', () {
    final d = DashboardDeAtenciones.fromMap(respuestaDeEjemplo());

    test('se lee completa', () {
      expect(d.hoyEnLaSede, DateTime(2026, 10, 4));
      expect(d.actual.atendidas, 3);
      expect(d.actual.vuelven, 1);
      expect(d.actual.perdidas, 2);
      expect(d.actual.horas, closeTo(2.75, 0.001));
      expect(d.anterior.minutos, 45);
      expect(d.serie, hasLength(7));
      expect(d.serie.last.desde, DateTime(2026, 10, 4));
      expect(d.servicios.first.nombre, 'Uñas');
      expect(d.equipo.last.calificacion, 5.0);
      expect(d.equipo.first.calificacion, isNull);
      expect(d.invitacionesAgendaron, 1);
      expect(d.perdidasPorDia[2], 1);
      expect(d.motivos.first.cancelada, isTrue);
      expect(d.motivos.last.cancelada, isFalse);
      expect(d.hoy.enProceso, 1);
    });

    test('la asistencia cuenta solo las citas ya decididas', () {
      // 3 atendidas de 5 decididas (3 + 1 cancelada + 1 que no llegó).
      expect(d.actual.asistencia, 60);
      expect(TramoDeAtenciones.vacio.asistencia, isNull);
    });

    test('la hora pico y el promedio por día de la semana', () {
      expect(d.horaPico, isNotNull);
      final prom = d.promedioPorDiaDeLaSemana(DateTime(2026, 9, 28), DateTime(2026, 10, 4));
      expect(prom.length, 7);
      expect(prom[DateTime.saturday], 1);
    });

    test('un objeto vacío no revienta', () {
      final vacio = DashboardDeAtenciones.fromMap({'hoy_en_la_sede': '2026-10-04'});
      expect(vacio.actual.atendidas, 0);
      expect(vacio.serie, isEmpty);
      expect(vacio.horaPico, isNull);
    });
  });

  group('las palabras', () {
    test('miles con punto, la hora como se dice, y el por ciento', () {
      expect(miles(1234567), '1.234.567');
      expect(miles(999), '999');
      expect(miles(2.75), '3');
      expect(horaHablada(10), '10 a. m.');
      expect(horaHablada(12), '12 m.');
      expect(horaHablada(15), '3 p. m.');
      expect(porcentaje(1, 3), 33);
      expect(porcentaje(1, 0), 0);
    });

    test('sin nada antes, no se inventa un porcentaje', () {
      expect(variacion(5, 0), isNull);
      expect(variacion(3, 1), 200);
      expect(variacion(1, 2), -50);
    });

    test('la historia dice lo que los números sostienen', () {
      final d = DashboardDeAtenciones.fromMap(respuestaDeEjemplo());
      final h = texto(historiaDelPeriodo(
        d,
        periodo: 'esta semana',
        desde: DateTime(2026, 9, 28),
        hasta: DateTime(2026, 10, 4),
      ));
      expect(h, startsWith('En esta semana, tu salón atendió 3 citas, 200 % más'));
      expect(h, contains('Lo más pedido: Uñas (2).'));
      expect(h, contains('Juliana atendió más que nadie (2).'));
      expect(h, contains('33 % llegó por tu enlace en línea.'));
      expect(h, contains('1 clienta nueva, y 1 agendó otra vez después de invitarla.'));
      expect(h, contains('Se perdieron 2: 1 cancelada y 1 que no llegó.'));
      expect(h, isNot(contains('\$')));
    });

    test('con un filtro no habla del salón ni de las invitaciones', () {
      final d = DashboardDeAtenciones.fromMap(respuestaDeEjemplo());
      final h = texto(historiaDelPeriodo(
        d,
        periodo: 'esta semana',
        desde: DateTime(2026, 9, 28),
        hasta: DateTime(2026, 10, 4),
        estilista: 'Paola',
      ));
      expect(h, startsWith('En esta semana, Paola atendió'));
      expect(h, isNot(contains('atendió más que nadie')));
      expect(h, isNot(contains('invitarla')));
    });

    test('sin citas atendidas se calla después de la primera frase', () {
      final d = DashboardDeAtenciones.fromMap({'hoy_en_la_sede': '2026-10-04'});
      final t = historiaDelPeriodo(
        d,
        periodo: 'este mes',
        desde: DateTime(2026, 10, 1),
        hasta: DateTime(2026, 10, 4),
      );
      expect(texto(t), 'En este mes, tu salón atendió 0 citas. ');
      expect(titularDelPeriodo(d.actual), 'Todavía no hay citas atendidas en este periodo');
    });
  });

  group('el tablero dibujado', () {
    Widget tablero({
      ({String id, String nombre})? estilista,
      ValueChanged<ServicioAtendido>? onServicio,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TableroDeAtenciones(
              resumen: ResumenDeAtenciones(
                datos: DashboardDeAtenciones.fromMap(respuestaDeEjemplo()),
                rango: RangoFechas(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
                rangoAnterior: RangoFechas(DateTime(2026, 9, 21), DateTime(2026, 9, 27)),
              ),
              periodo: PeriodoDashboard.estaSemana,
              estilista: estilista,
              onPeriodo: (_) {},
              onAmbito: (_) {},
              onTocarEstilista: (_) {},
              onTocarServicio: onServicio ?? (_) {},
              onQuitarEstilista: () {},
              onQuitarServicio: () {},
            ),
          ),
        ),
      );
    }

    for (final (nombre, ancho) in [('celular', 390.0), ('computador', 1280.0)]) {
      testWidgets('se dibuja sin desbordes en un $nombre', (tester) async {
        tester.view.physicalSize = Size(ancho, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(tablero());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('¿Cuándo vienen?'), findsOneWidget);
        expect(find.text('¿Qué se perdió?'), findsOneWidget);
        expect(find.text('LA HISTORIA DE ESTA SEMANA'), findsOneWidget);
        expect(find.textContaining('\$'), findsNothing);
      });
    }

    testWidgets('tocar un servicio filtra el tablero', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ServicioAtendido? tocado;
      await tester.pumpWidget(tablero(onServicio: (s) => tocado = s));
      await tester.pumpAndSettle();

      // El renglón del servicio, no la palabra "Corte" de la lista de motivos.
      final renglon = find.byWidgetPredicate(
        (w) => w is RenglonDeRanking && w.titulo == 'Corte',
      );
      await tester.ensureVisible(renglon);
      await tester.tap(renglon);
      expect(tocado?.id, 's-corte');
    });

    testWidgets('con un filtro puesto se ve su ficha para quitarlo', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(tablero(estilista: (id: 'e-paola', nombre: 'Paola')));
      await tester.pumpAndSettle();
      expect(find.text('Solo Paola'), findsOneWidget);
    });
  });

  group('el interruptor propio y quién ve qué', () {
    final main = File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');

    test('la clave coincide con la del servidor', () {
      expect(ClaveDeCapacidad.dashboard, 'dashboard');
      final migracion = File(
        'supabase/migrations/20261004100000_dashboard_de_atenciones_paso5.sql',
      ).readAsStringSync();
      expect(migracion, contains("('dashboard', 'Dashboard',"));
    });

    test('el Dashboard se esconde con su interruptor, no con el de Finanzas', () {
      expect(main, contains('ocultableCon: ClaveDeCapacidad.dashboard,'));
      // Reportes sigue con Finanzas.
      expect(main, contains('requiredFeature: ClaveDeCapacidad.reportesFinancieros,'));
    });

    test('sin caja, el de atenciones; con caja, el de siempre', () {
      expect(main, contains('page: cajaOculta\n            ? DashboardDeAtencionesPage('));
      expect(main, contains(': DashboardPage('));
    });

    test('el Panel muestra el interruptor del Dashboard', () {
      final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();
      expect(panel, contains("('dashboard', 'Dashboard',"));
      expect(panel, contains("('financial_reports', 'Finanzas', 'Reportes'),"));
    });
  });
}
