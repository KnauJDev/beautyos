import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_summary.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/models/public_salon_review_item.dart';
import 'package:salonymas/models/public_salon_service_item.dart';
import 'package:salonymas/models/ticket_service_option.dart';
import 'package:salonymas/pages/public_salon_page.dart';
import 'package:salonymas/pages/tickets_page.dart';
import 'package:salonymas/services/clients_service.dart';
import 'package:salonymas/services/tickets_service.dart';
import 'package:salonymas/widgets/elegir_servicio.dart';

/// D-322 (08-oct), pedidos de David: elegir el servicio por cuadritos y, en
/// la página pública, "Pregunta por WhatsApp" para los servicios que aún no
/// tienen estilista. Prototipo: https://claude.ai/artifact/2NAFZNYbz3fqxwAX6H7qaQ
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

ServicioParaElegir servicio(String id, String nombre, String categoria) =>
    ServicioParaElegir(
      id: id,
      nombre: nombre,
      categoria: categoria,
      duracionMinutos: 30,
      precio: '\$25.000',
    );

/// Como los de David: la misma categoría escrita de varias formas.
final deDavid = [
  servicio('1', 'corte mujer', 'peluquería'),
  servicio('2', 'Balayage', 'Peluquería'),
  servicio('3', 'termocut corte', 'peluqueria'),
  servicio('4', 'corte hombre', 'barbería'),
  servicio('5', 'Asesoría', 'solo David marin'),
  servicio('6', 'Retoque', ''),
  servicio('7', 'Limpieza', 'Sin categoria'),
];

Widget campo({
  required List<ServicioParaElegir> servicios,
  String? elegido,
  ValueChanged<String>? onElegido,
}) => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: CampoDeServicio(
        servicios: servicios,
        elegidoId: elegido,
        onElegido: onElegido ?? (_) {},
      ),
    ),
  ),
);

void main() {
  group('las categorías', () {
    test('se juntan sin mirar mayúsculas; una tilde distinta es otra', () {
      final g = agruparPorCategoria(deDavid);
      expect(g.map((x) => x.nombre), [
        'Barbería',
        'Peluqueria',
        'Peluquería',
        'Solo David marin',
        'Otros',
      ]);
      final peluqueria = g.firstWhere((x) => x.nombre == 'Peluquería');
      // Ordenados por nombre, sin mirar mayúsculas.
      expect(peluqueria.servicios.map((s) => s.nombre), ['Balayage', 'corte mujer']);
    });

    test('sin categoría y "Sin categoria" van a Otros, al final', () {
      final otros = agruparPorCategoria(deDavid).last;
      expect(otros.nombre, nombreDelGrupoSinCategoria);
      expect(otros.servicios.map((s) => s.id), ['7', '6']);
    });
  });

  group('el campo y la pantalla de los cuadritos', () {
    testWidgets('categoría → servicio → se cierra con el elegido', (tester) async {
      String? elegido;
      await tester.pumpWidget(campo(servicios: deDavid, onElegido: (id) => elegido = id));
      expect(find.text('Toca para elegir'), findsOneWidget);

      await tester.tap(find.text('Toca para elegir'));
      await tester.pumpAndSettle();
      expect(find.text('Elige un servicio'), findsOneWidget);
      expect(find.text('Barbería'), findsOneWidget);
      expect(find.text('2 servicios'), findsWidgets);

      await tester.tap(find.text('Peluquería'));
      await tester.pumpAndSettle();
      expect(find.text('Balayage'), findsOneWidget);
      expect(find.text('corte hombre'), findsNothing);

      // La flecha vuelve a los cuadritos.
      await tester.tap(find.byTooltip('Volver a las categorías'));
      await tester.pumpAndSettle();
      expect(find.text('Barbería'), findsOneWidget);

      await tester.tap(find.text('Barbería'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('corte hombre'));
      await tester.pumpAndSettle();
      expect(elegido, '4');
      expect(find.text('Elige un servicio'), findsNothing);
    });

    testWidgets('el campo dice qué va elegido', (tester) async {
      await tester.pumpWidget(campo(servicios: deDavid, elegido: '4'));
      expect(find.text('corte hombre'), findsOneWidget);
      expect(find.text('Barbería · 30 min · \$25.000'), findsOneWidget);
    });

    testWidgets('Cerrar sale sin elegir nada', (tester) async {
      String? elegido;
      await tester.pumpWidget(campo(servicios: deDavid, onElegido: (id) => elegido = id));
      await tester.tap(find.text('Toca para elegir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(elegido, isNull);
      expect(find.text('Toca para elegir'), findsOneWidget);
    });

    testWidgets('si el salón no usa categorías, sale directo la lista', (tester) async {
      await tester.pumpWidget(campo(servicios: [
        servicio('a', 'Corte', ''),
        servicio('b', 'Tinte', ''),
      ]));
      await tester.tap(find.text('Toca para elegir'));
      await tester.pumpAndSettle();
      expect(find.text('Corte'), findsOneWidget);
      expect(find.text('Tinte'), findsOneWidget);
      expect(find.text('Otros'), findsNothing);
    });

    testWidgets('en un celular, sin desbordes con un nombre largo', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(campo(servicios: [
        ...deDavid,
        servicio('8', 'Reconstrucción', 'tratamiento alizador y reconstructor'),
      ]));
      await tester.tap(find.text('Toca para elegir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tratamiento alizador y reconstructor'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reconstrucción'), findsOneWidget);
    });
  });

  group('Nueva cita', () {
    testWidgets('sin servicio avisa, y al elegirlo el aviso se quita', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const opciones = [
        TicketServiceOption(serviceId: 's1', serviceName: 'Corte dama', category: 'Peluquería', price: 35000, durationMinutes: 45, stylistId: 'e1', stylistName: 'Paola'),
        TicketServiceOption(serviceId: 's2', serviceName: 'Rubber', category: 'Uñas', price: 55000, durationMinutes: 75, stylistId: 'e1', stylistName: 'Paola'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (context) => CreateAppointmentDialog(
                  clients: const [ClientSummary(id: 'c1', name: 'Ana', phone: '3001234567', createdAt: null)],
                  clientsService: const ClientsService(),
                  ticketsService: TicketsService(branchId: '00000000-0000-0000-0000-000000000001'),
                  options: opciones,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      final crear = find.text('Crear reserva');
      await tester.ensureVisible(crear);
      await tester.tap(crear);
      await tester.pumpAndSettle();
      expect(find.text('Selecciona un servicio'), findsOneWidget);

      await tester.ensureVisible(find.text('1. Servicio'));
      await tester.tap(find.text('1. Servicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uñas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rubber'));
      await tester.pumpAndSettle();
      expect(find.text('Rubber'), findsOneWidget);
      expect(find.text('Selecciona un servicio'), findsNothing);
    });
  });

  group('la página pública', () {
    PublicSalonFullProfile perfil({Set<String>? conEstilista, String whatsapp = '3001234567'}) =>
        PublicSalonFullProfile(
          profile: PublicSalonProfile.fromMap({
            'tenant_id': 't1',
            'name': 'Salón Magnolia',
            'slug': 'salon-magnolia',
            'business_type': 'salon',
            'whatsapp': whatsapp,
            'primary_branch_id': 'b1',
          }),
          services: const [
            PublicSalonServiceItem(id: 's1', name: 'Corte dama', description: 'Cabello', durationMinutes: 45, priceCop: 35000),
            PublicSalonServiceItem(id: 's2', name: 'Balayage', description: 'Cabello', durationMinutes: 180, priceCop: 400000),
            PublicSalonServiceItem(id: 's3', name: 'Rubber', description: 'Uñas', durationMinutes: 75, priceCop: 55000),
          ],
          portfolio: const [],
          team: const [],
          reviews: const PublicSalonReviewsSummary(avgRating: 0, totalReviews: 0, reviews: []),
          blogPosts: const [],
          serviciosConEstilista: conEstilista,
        );

    Future<List<Uri>> dibujar(WidgetTester tester, PublicSalonFullProfile p) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final abiertos = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContenidoDeLaPaginaPublica(
            perfil: p,
            ahora: DateTime(2026, 10, 7, 10),
            onBook: () {},
            onReserve: (_) {},
            onAbrir: (uri) async => abiertos.add(uri),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return abiertos;
    }

    testWidgets('sin estilista: "Pregunta por WhatsApp" con el nombre del servicio', (tester) async {
      final abiertos = await dibujar(tester, perfil(conEstilista: {'s1'}));
      expect(find.text('Reservar'), findsOneWidget);
      expect(find.text('Pregunta por WhatsApp'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Pregunta por WhatsApp').first);
      await tester.tap(find.text('Pregunta por WhatsApp').first);
      expect(abiertos.single.host, 'wa.me');
      expect(abiertos.single.queryParameters['text'], contains('"Balayage"'));
    });

    testWidgets('sin WhatsApp del salón, el servicio sin estilista no lleva botón', (tester) async {
      await dibujar(tester, perfil(conEstilista: {'s1'}, whatsapp: ''));
      expect(find.text('Reservar'), findsOneWidget);
      expect(find.text('Pregunta por WhatsApp'), findsNothing);
    });

    testWidgets('si no se supo cuáles tienen estilista, todos dicen Reservar, como antes', (tester) async {
      await dibujar(tester, perfil());
      expect(find.text('Reservar'), findsNWidgets(3));
      expect(find.text('Pregunta por WhatsApp'), findsNothing);
    });
  });

  test('la reserva en línea y Nueva cita usan los cuadritos', () {
    expect(leer('lib/pages/public_booking_page.dart'), contains('CampoDeServicio('));
    expect(leer('lib/pages/tickets_page.dart'), contains('CampoDeServicio('));
    // La página pública pregunta qué servicios tienen estilista.
    expect(leer('lib/services/public_salon_service.dart'), contains('getServiciosConEstilista(profile.primaryBranchId)'));
  });
}
