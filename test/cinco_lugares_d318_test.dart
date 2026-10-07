import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/avisos_de_hoy.dart';
import 'package:salonymas/models/dashboard_de_atenciones.dart';
import 'package:salonymas/models/lugares_de_la_app.dart';
import 'package:salonymas/models/periodo_dashboard.dart';
import 'package:salonymas/models/tenant_entitlements.dart';
import 'package:salonymas/models/ticket_board.dart';
import 'package:salonymas/pages/agenda_page.dart';
import 'package:salonymas/pages/dashboard_de_atenciones_page.dart';
import 'package:salonymas/pages/settings_page.dart' show TuEnlaceCard;
import 'package:salonymas/services/dashboard_service.dart';
import 'package:salonymas/widgets/app_widgets.dart' show AppPage, MetricCard;
import 'package:salonymas/widgets/cinco_lugares.dart';

import 'dashboard_de_atenciones_d317_test.dart' show respuestaDeEjemplo;

/// D-318 (07-oct): los cinco lugares, aprobados por el propietario vista por
/// vista, detrás del interruptor `cinco_lugares` que nace apagado. El
/// servidor lo prueba el control 245.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

TicketBoardCount conteo(String status, int n) => TicketBoardCount(
  bucket: '2026-10-07',
  status: status,
  ticketCount: n,
  totalPrice: 0,
  totalPendingBalance: 0,
);

Widget enApp(Widget hijo, {double ancho = 390}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(ancho, 900)),
    child: Scaffold(body: SingleChildScrollView(child: hijo)),
  ),
);

void main() {
  group('el interruptor nace apagado', () {
    test('si no se pudo consultar, NO cuenta como encendido', () {
      const e = TenantEntitlements.desconocido();
      // `permite` da sí para no bloquear a nadie por un fallo...
      expect(e.permite(ClaveDeCapacidad.cincoLugares), isTrue);
      // ...pero esta capacidad se pregunta con `encendido`.
      expect(e.encendido(ClaveDeCapacidad.cincoLugares), isFalse);
    });

    test('apagada por el plan: no; encendida por el Panel: sí', () {
      final apagada = TenantEntitlements.fromList(<dynamic>[
        {'feature_key': 'cinco_lugares', 'entitled': false, 'limit_value': null, 'source': 'plan'},
      ]);
      expect(apagada.encendido(ClaveDeCapacidad.cincoLugares), isFalse);
      final encendida = TenantEntitlements.fromList(<dynamic>[
        {'feature_key': 'cinco_lugares', 'entitled': true, 'limit_value': null, 'source': 'override'},
      ]);
      expect(encendida.encendido(ClaveDeCapacidad.cincoLugares), isTrue);
      // Y la clave es la del servidor.
      expect(
        leer('supabase/migrations/20261007100000_cinco_lugares_interruptor_d318.sql'),
        contains("select p.id, f.id, false"),
      );
    });

    test('el menú nuevo solo sale con el interruptor encendido', () {
      final main = leer('lib/main.dart');
      expect(main, contains('entitlements.encendido(ClaveDeCapacidad.cincoLugares)'));
      expect(main, contains('if (isWide && cinco)'));
      expect(main, contains('else if (isWide)\n                          _CategorizedSideMenu('));
      expect(main, contains(': _MobileNavBar('));
    });
  });

  group('dónde vive cada módulo', () {
    test('cada módulo de hoy tiene su lugar, y la estilista no está', () {
      expect(lugarDe('Tickets & Caja'), LugarDeLaApp.agenda);
      expect(lugarDe('Reportes'), LugarDeLaApp.negocio);
      expect(lugarDe('Blog'), LugarDeLaApp.vitrina);
      expect(lugarDe('Configuración'), LugarDeLaApp.ajustes);
      expect(lugarDe('Mi agenda'), isNull);
      expect(esPuerta('Mi negocio'), isTrue);
      expect(esPuerta('Dashboard'), isFalse);
    });

    test('la recepción ve solo los lugares que tiene', () {
      expect(
        lugaresVisibles(['Agenda', 'Tickets & Caja', 'Clientes']),
        [LugarDeLaApp.agenda, LugarDeLaApp.clientes],
      );
      expect(
        lugaresVisibles(['Agenda', 'Clientes', 'Mi negocio', 'Mi vitrina', 'Ajustes']).map((l) => l.nombre),
        ['Agenda', 'Clientes', 'Mi negocio', 'Mi vitrina', 'Ajustes'],
      );
    });

    test('hallazgo CN: los saltos buscan en la lista que se ve', () {
      final main = leer('lib/main.dart');
      final i0 = main.indexOf('  List<BeautyModule> _modulesForProfile(');
      final i1 = main.indexOf('  void _mostrarAvisoDePagoSiHayUno(');
      final cuerpo = main.substring(i0, i1);
      expect(cuerpo, isNot(contains('_irAModulo(modules, ')));
      expect('_irAModulo(resultado, '.allMatches(cuerpo).length, greaterThanOrEqualTo(8));
    });
  });

  group('la Agenda: una sola tarjeta de citas', () {
    test('los cuatro números del ejemplo del propietario', () {
      final r = resumenDeCitas([
        conteo('cerrado', 2),
        conteo('finalizado', 1),
        conteo('confirmado', 3),
        conteo('en_proceso', 1),
        conteo('solicitado', 1),
        conteo('cancelado', 1),
      ]);
      expect((r.total, r.atendidas, r.pendientes, r.perdidas, r.porCobrar), (9, 3, 5, 1, 1));
    });

    test('el título dice lo que mira el tablero', () {
      final hoy = DateTime(2026, 10, 7, 11);
      expect(tituloDelResumen(vista: AgendaViewMode.dia, fecha: DateTime(2026, 10, 7), hoy: hoy), 'Citas de hoy');
      expect(tituloDelResumen(vista: AgendaViewMode.dia, fecha: DateTime(2026, 10, 8), hoy: hoy), 'Citas del día');
      expect(tituloDelResumen(vista: AgendaViewMode.semana, fecha: hoy, hoy: hoy), 'Citas de la semana');
      expect(tituloDelResumen(vista: AgendaViewMode.mes, fecha: hoy, hoy: hoy), 'Citas del mes');
    });

    testWidgets('se dibuja en el celular, con y sin caja', (tester) async {
      final r = resumenDeCitas([conteo('cerrado', 3), conteo('confirmado', 5), conteo('cancelado', 1)]);
      for (final caja in [false, true]) {
        await tester.pumpWidget(enApp(ResumenDeCitasCard(
          titulo: 'Citas de hoy',
          resumen: r,
          conCaja: caja,
          onAbrirCaja: () {},
        )));
        expect(tester.takeException(), isNull);
        expect(find.text('CITAS DE HOY'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('TICKETS & CAJA'), caja ? findsOneWidget : findsNothing);
      }
    });

    testWidgets('las pantallas del salón, sin título ni explicación; la estilista los conserva', (tester) async {
      // "Si estorba acá, estorba en todos" (el propietario, 07-oct).
      Widget pagina({bool? conEncabezado}) => MaterialApp(
        home: Scaffold(
          body: conEncabezado == null
              ? const AppPage(
                  title: 'Tablero de Agenda',
                  subtitle: 'Tus citas pasan de Confirmado a En proceso y a Cerrado.',
                  children: [Text('Nueva cita')],
                )
              : AppPage(
                  title: 'Tablero de Agenda',
                  subtitle: 'Tus citas pasan de Confirmado a En proceso y a Cerrado.',
                  conEncabezado: conEncabezado,
                  children: const [Text('Nueva cita')],
                ),
        ),
      );
      await tester.pumpWidget(pagina());
      expect(find.text('Tablero de Agenda'), findsNothing);
      expect(find.textContaining('Tus citas pasan'), findsNothing);
      expect(find.text('Nueva cita'), findsOneWidget);

      await tester.pumpWidget(pagina(conEncabezado: true));
      expect(find.text('Tablero de Agenda'), findsOneWidget);

      for (final ruta in [
        'lib/pages/my_stylist_agenda_page.dart',
        'lib/pages/my_stylist_work_photos_page.dart',
        'lib/pages/my_stylist_reviews_page.dart',
        'lib/pages/my_commission_summary_page.dart',
      ]) {
        expect(leer(ruta), contains('conEncabezado: true,'), reason: ruta);
      }
      expect(leer('lib/pages/agenda_page.dart'), isNot(contains('conEncabezado')));
    });

    test('Llegó sin cita es el diálogo de siempre con su "Atender ya"', () {
      final tickets = leer('lib/pages/tickets_page.dart');
      expect(tickets, contains("title: Text(widget.atenderYa ? 'Llegó sin cita' : 'Nueva cita'),"));
      expect(tickets, contains('if (widget.atenderYa && value != null) _atenderYa();'));
    });
  });

  group('la campana', () {
    test('lo básico, y cada aviso a su módulo', () {
      const a = AvisosDeHoy(
        sinConfirmar: 2,
        paraInvitar: 4,
        inventarioBajo: 1,
        sedes: [SedePorVencer(nombre: 'Cedritos', dias: 5, vencida: false)],
      );
      final l = a.lista;
      expect(l.map((x) => x.texto), [
        '2 citas de hoy sin confirmar',
        '4 clientes para invitar hoy: ya les toca volver',
        '1 producto por debajo del mínimo',
        'La sede Cedritos vence en 5 días',
      ]);
      expect(l.map((x) => x.destino), ['Agenda', 'Clientes', 'Inventario', 'Configuración']);
      expect(l[1].filtroDeClientes, 'para_invitar');
      expect(AvisosDeHoy.vacio.cuantos, 0);
    });

    test('el aviso abre Clientes ya filtrado (lo vio el propietario el 07-oct)', () {
      // Con `late`, el filtro se leía cuando ya habían cargado los clientes,
      // y para entonces la campana ya lo había borrado: salía "Todos".
      final clientes = leer('lib/pages/clients_page.dart');
      expect(clientes, isNot(contains('late String _selectedSegmentFilter')));
      expect(
        clientes,
        contains("super.initState();\n    _selectedSegmentFilter = widget.filtroInicial ?? 'todos';"),
      );
    });

    test('los números se cuentan otra vez al cambiar de lugar, y gana la última carga', () {
      final main = leer('lib/main.dart');
      expect('onElegir: (l) => _irAlLugar('.allMatches(main).length, 2);
      expect(main, isNot(contains('onElegir: (l) => _irAModulo(')));
      expect(main, contains('pedido == _avisosPedidos'));
    });

    test('los filtros de Clientes, sin emojis (se cortaban "⭐ VIP (" y "📨 Para invitar (")', () {
      final clientes = leer('lib/pages/clients_page.dart');
      final i0 = clientes.indexOf("_buildSegmentChip('todos'");
      final i1 = clientes.indexOf("_buildSegmentChip('inactivos'");
      final filtros = clientes.substring(i0, i1);
      for (final emoji in ['⭐', '⚠️', '🟢', '🆕', '📨', '↩️', '🔴']) {
        expect(filtros, isNot(contains(emoji)), reason: emoji);
      }
      expect(filtros, contains("'VIP (\$vipCount)'"));
    });

    test('una sede vencida es urgente', () {
      const a = AvisosDeHoy(sedes: [SedePorVencer(nombre: 'Norte', dias: 0, vencida: true)]);
      expect(a.lista.single.urgente, isTrue);
      expect(a.lista.single.texto, contains('está vencida'));
    });
  });

  group('las piezas de pantalla', () {
    testWidgets('la barra del celular: cinco lugares y el globo de Clientes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraDeLugares(
            lugares: LugarDeLaApp.values,
            actual: LugarDeLaApp.agenda,
            avisos: const AvisosDeHoy(paraInvitar: 4),
            onElegir: (_) {},
          ),
        ),
      ));
      for (final l in LugarDeLaApp.values) {
        expect(find.text(l.nombre), findsOneWidget);
      }
      expect(find.text('4'), findsWidgets);
      expect(find.text('Más'), findsNothing);
    });

    testWidgets('una puerta abre sus módulos', (tester) async {
      String? abierto;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PuertaDeLugarPage(
            titulo: 'Ajustes',
            subtitulo: 'Lo que se configura una vez.',
            renglones: [
              for (final t in modulosDentroDe[LugarDeLaApp.ajustes]!)
                RenglonDePuerta(
                  titulo: t,
                  descripcion: descripcionDeModulo[t]!,
                  icono: Icons.circle,
                  onTap: () => abierto = t,
                ),
            ],
          ),
        ),
      ));
      await tester.tap(find.text('Estilistas'));
      expect(abierto, 'Estilistas');
    });

    testWidgets('Mi negocio sin caja: el Dashboard resumido y el botón al completo', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var completo = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TableroDeAtenciones(
              resumen: ResumenDeAtenciones(
                datos: DashboardDeAtenciones.fromMap(respuestaDeEjemplo()),
                rango: RangoFechas(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
                rangoAnterior: RangoFechas(DateTime(2026, 9, 21), DateTime(2026, 9, 27)),
              ),
              periodo: PeriodoDashboard.estaSemana,
              compacto: true,
              onVerCompleto: () => completo = true,
              onPeriodo: (_) {},
              onAmbito: (_) {},
              onTocarEstilista: (_) {},
              onTocarServicio: (_) {},
              onQuitarEstilista: () {},
              onQuitarServicio: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('¿Qué piden?'), findsOneWidget);
      expect(find.text('¿Quién atiende?'), findsOneWidget);
      expect(find.text('¿Cuándo vienen?'), findsNothing);
      await tester.ensureVisible(find.text('Ver el Dashboard completo'));
      await tester.tap(find.text('Ver el Dashboard completo'));
      expect(completo, isTrue);
    });

    testWidgets('con un filtro puesto, se quita también abajo, junto al botón (07-oct)', (tester) async {
      tester.view.physicalSize = const Size(390, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var quitado = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TableroDeAtenciones(
              resumen: ResumenDeAtenciones(
                datos: DashboardDeAtenciones.fromMap(respuestaDeEjemplo()),
                rango: RangoFechas(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
                rangoAnterior: RangoFechas(DateTime(2026, 9, 21), DateTime(2026, 9, 27)),
              ),
              periodo: PeriodoDashboard.estaSemana,
              servicio: (id: 's-corte', nombre: 'Corte'),
              compacto: true,
              onVerCompleto: () {},
              onPeriodo: (_) {},
              onAmbito: (_) {},
              onTocarEstilista: (_) {},
              onTocarServicio: (_) {},
              onQuitarEstilista: () {},
              onQuitarServicio: () => quitado = true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Arriba (avisa que todo está filtrado) y abajo, junto al botón.
      expect(find.text('Solo Corte'), findsNWidgets(2));
      final abajo = find.text('Solo Corte').last;
      final boton = find.text('Ver el Dashboard completo');
      expect(
        (tester.getTopLeft(abajo).dy - tester.getTopLeft(boton).dy).abs(),
        lessThan(80),
        reason: 'el de abajo va junto al botón',
      );
      await tester.ensureVisible(abajo);
      await tester.tap(abajo);
      expect(quitado, isTrue);
      expect(find.textContaining('tócalo otra vez para quitarlo'), findsOneWidget);
    });

    testWidgets('las tarjetas de números: dos por fila en el celular, igual en el computador', (tester) async {
      Widget fila(double ancho) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: ancho,
              child: const Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  MetricCard(icon: Icons.photo, title: 'Fotos', value: '4', description: 'Registros cargados'),
                  MetricCard(icon: Icons.visibility, title: 'Visibles', value: '4', description: 'Fotos visibles al cliente'),
                  MetricCard(icon: Icons.payments, title: 'Total gastos', value: '\$1.280.000', description: 'Del periodo'),
                ],
              ),
            ),
          ),
        ),
      );

      // Un celular: 360 de ancho menos los 24 + 24 de la página.
      await tester.pumpWidget(fila(312));
      expect(tester.takeException(), isNull);
      final fotos = tester.getRect(find.byType(MetricCard).at(0));
      final visibles = tester.getRect(find.byType(MetricCard).at(1));
      expect(fotos.top, visibles.top, reason: 'las dos primeras, en la misma fila');
      expect(fotos.width, 148);
      // La cifra larga cabe en un renglón (se achica, no se parte).
      final cifra = tester.getRect(find.text('\$1.280.000'));
      expect(cifra.height, lessThan(40));

      // Un computador: como siempre, de 240.
      await tester.pumpWidget(fila(1000));
      expect(tester.getRect(find.byType(MetricCard).first).width, 240);
    });

    group('Tu enlace: una tarjeta donde había dos, sin "Modificar enlace" (07-oct)', () {
      Widget tarjeta({String? slug, bool principal = true}) => MaterialApp(
        home: Scaffold(
          body: TuEnlaceCard(
            branchId: 'sede-1',
            slugDelSalon: slug,
            nombreDelSalon: 'Peluquería Éxito Prueba',
            citasNacenConfirmadas: true,
            esSedePrincipal: principal,
            origen: 'https://salonymas.com',
          ),
        ),
      );

      testWidgets('en la sede principal: la página del salón y nada más', (tester) async {
        await tester.pumpWidget(tarjeta(slug: 'peluqueria-exito-prueba'));
        expect(find.text('https://salonymas.com/peluqueria-exito-prueba'), findsOneWidget);
        expect(find.text('Compartir en WhatsApp'), findsOneWidget);
        expect(find.text('Modificar enlace'), findsNothing);
        expect(find.text('Reservar directo en esta sede'), findsNothing);
        expect(find.textContaining('queda confirmada'), findsOneWidget);
      });

      testWidgets('en otra sede, además el directo de esa sede', (tester) async {
        await tester.pumpWidget(tarjeta(slug: 'peluqueria-exito-prueba', principal: false));
        expect(find.text('https://salonymas.com/peluqueria-exito-prueba'), findsOneWidget);
        expect(find.text('Reservar directo en esta sede'), findsOneWidget);
        expect(find.text('https://salonymas.com/?reservar=sede-1'), findsOneWidget);
      });

      testWidgets('sin la dirección del salón, el directo de la sede, una sola vez', (tester) async {
        await tester.pumpWidget(tarjeta(principal: false));
        expect(find.text('https://salonymas.com/?reservar=sede-1'), findsOneWidget);
        expect(find.text('Reservar directo en esta sede'), findsNothing);
      });

      test('Configuración y Mi vitrina usan la misma, y el diálogo de cambiar ya no existe', () {
        final ajustes = leer('lib/pages/settings_page.dart');
        expect(ajustes, contains("const SectionTitle('Tu enlace'),"));
        expect(ajustes, isNot(contains('_EditSlugDialog')));
        expect(ajustes, isNot(contains("Text('Modificar enlace')")));
        expect(ajustes, isNot(contains('class PublicSalonLinkCard')));
        expect(ajustes, isNot(contains('class PublicBookingLinkCard')));
        expect(leer('lib/widgets/cinco_lugares.dart'), contains(': TuEnlaceCard('));
      });
    });

    test('las barras crecen con una animación al filtrar (ronda 2)', () {
      expect(
        leer('lib/widgets/graficos_de_atenciones.dart'),
        contains('child: TweenAnimationBuilder<double>('),
      );
    });

    test('el Panel enciende la novedad salón por salón', () {
      final panel = leer('lib/pages/platform_panel_page.dart');
      expect(panel, contains("'cinco_lugares',\n      'Los cinco lugares',"));
      expect(panel, contains('enabled: true,'));
      expect(panel, contains('NovedadesDelNegocio(\n                          tenantId: tenant.tenantId,'));
    });
  });
}
