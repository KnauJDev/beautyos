import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_summary.dart';
import 'package:salonymas/models/precios_desde.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/models/public_salon_review_item.dart';
import 'package:salonymas/models/public_salon_service_item.dart';
import 'package:salonymas/models/service_management_item.dart';
import 'package:salonymas/models/ticket_service_option.dart';
import 'package:salonymas/pages/public_salon_page.dart';
import 'package:salonymas/pages/services_page.dart';
import 'package:salonymas/pages/tickets_page.dart';
import 'package:salonymas/services/clients_service.dart';
import 'package:salonymas/services/precios_desde_service.dart';
import 'package:salonymas/services/tickets_service.dart';

/// D-326 (09-oct): precios "desde", por categoría. Pedido del propietario
/// para el Color de David.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('la lista', () {
    test('se compara sin mirar mayúsculas ni espacios', () {
      final desde = PreciosDesde.desdeLista(['color', ' Cortes ', '', null]);
      expect(desde.categorias, {'color', 'cortes'});
      expect(desde.aplica('Color'), isTrue);
      expect(desde.aplica(' COLOR '), isTrue);
      expect(desde.aplica('Colores'), isFalse);
      expect(desde.aplica(null), isFalse);
    });

    test('"Desde" solo en las categorías marcadas', () {
      const desde = PreciosDesde({'color'});
      expect(desde.precio('\$400.000', 'Color'), 'Desde \$400.000');
      expect(desde.precio('\$25.000', 'Cortes'), '\$25.000');
      expect(PreciosDesde.ninguno.precio('\$400.000', 'Color'), '\$400.000');
    });
  });

  group('la página pública', () {
    PublicSalonFullProfile perfil(PreciosDesde desde) => PublicSalonFullProfile(
      profile: PublicSalonProfile.fromMap({
        'tenant_id': 't1',
        'name': 'Inspirant Salon',
        'slug': 'inspirant-salon',
        'business_type': 'salon',
        'whatsapp': '3001234567',
        'primary_branch_id': 'b1',
      }),
      services: const [
        PublicSalonServiceItem(id: 's1', name: 'Balayage', description: 'Color', durationMinutes: 180, priceCop: 400000),
        PublicSalonServiceItem(id: 's2', name: 'Corte mujer', description: 'Cortes', durationMinutes: 30, priceCop: 25000),
      ],
      portfolio: const [],
      team: const [],
      reviews: const PublicSalonReviewsSummary(avgRating: 0, totalReviews: 0, reviews: []),
      blogPosts: const [],
      preciosDesde: desde,
    );

    Future<void> dibujar(WidgetTester tester, PreciosDesde desde) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContenidoDeLaPaginaPublica(
            perfil: perfil(desde),
            ahora: DateTime(2026, 10, 9, 10),
            onBook: () {},
            onReserve: (_) {},
            onAbrir: (_) async {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('Color dice "Desde"; Cortes, el precio de siempre', (tester) async {
      await dibujar(tester, const PreciosDesde({'color'}));
      expect(find.text('Desde \$400.000'), findsOneWidget);
      expect(find.text('\$25.000'), findsOneWidget);
    });

    testWidgets('sin categorías marcadas, como antes', (tester) async {
      await dibujar(tester, PreciosDesde.ninguno);
      expect(find.textContaining('Desde'), findsNothing);
      expect(find.text('\$400.000'), findsOneWidget);
    });
  });

  testWidgets('Servicios: la fila dice "Desde" si su categoría está marcada', (tester) async {
    const balayage = ServiceManagementItem(
      id: 's1',
      name: 'Balayage',
      category: 'Color',
      durationMinutes: 180,
      price: 400000,
      visibleToCustomer: true,
      active: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ServiceRow(service: balayage, onEdit: () {}, onToggleActive: () {}, desde: true),
            ServiceRow(service: balayage, onEdit: () {}, onToggleActive: () {}),
          ],
        ),
      ),
    ));
    expect(find.text('Desde \$400.000'), findsOneWidget);
    expect(find.text('\$400.000'), findsOneWidget);
  });

  testWidgets('Nueva cita: los cuadritos dicen "Desde"', (tester) async {
    preciosDesdeDelSalon.value = const PreciosDesde({'color'});
    addTearDown(() => preciosDesdeDelSalon.value = PreciosDesde.ninguno);
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const opciones = [
      TicketServiceOption(serviceId: 's1', serviceName: 'Balayage', category: 'Color', price: 400000, durationMinutes: 180, stylistId: 'e1', stylistName: 'Paola'),
      TicketServiceOption(serviceId: 's2', serviceName: 'Corte mujer', category: 'Cortes', price: 25000, durationMinutes: 30, stylistId: 'e1', stylistName: 'Paola'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => CreateAppointmentDialog(
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
    await tester.tap(find.text('1. Servicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Color'));
    await tester.pumpAndSettle();
    expect(find.text('Desde \$400.000'), findsOneWidget);
    await tester.tap(find.text('Balayage'));
    await tester.pumpAndSettle();
    // El campo, con el servicio elegido.
    expect(find.text('Color · 3 h · Desde \$400.000'), findsOneWidget);
  });

  test('sale donde se ofrece el servicio y en las líneas de la cita; no en el total', () {
    final reserva = leer('lib/pages/public_booking_page.dart');
    expect(reserva, contains('precio: preciosDesde.precio(s.formattedPrice, s.category),'));
    final tickets = leer('lib/pages/tickets_page.dart');
    expect(tickets, contains('precio: preciosDesdeDelSalon.value.precio(option.formattedPrice, option.category),'));
    expect(tickets, contains('preciosDesdeDelSalon.value.precio(item.formattedPrice, categorias[item.serviceId])'));
    expect('preciosDesdeDelSalon.value.precio(option.formattedPrice, option.category)'.allMatches(tickets).length, 3);
    // El total de la cita sigue exacto.
    expect(tickets, contains('ticket.formattedPrice,'));
    final servicios = leer('lib/pages/services_page.dart');
    expect(servicios, contains('\'Precios "desde" en \$_selectedCategory\','));
    final estilistas = leer('lib/pages/stylists_page.dart');
    expect('preciosDesdeDelSalon.value.precio('.allMatches(estilistas).length, 2);
    final pagina = leer('lib/services/public_salon_service.dart');
    expect(pagina, contains('PreciosDesdeService(branchId: profile.primaryBranchId!).leer()'));
  });
}
