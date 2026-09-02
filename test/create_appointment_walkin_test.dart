import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/available_appointment_slot.dart';
import 'package:salonymas/models/client_summary.dart';
import 'package:salonymas/models/ticket_service_option.dart';
import 'package:salonymas/pages/tickets_page.dart';
import 'package:salonymas/services/clients_service.dart';
import 'package:salonymas/services/tickets_service.dart';

/// Dos estilistas ofrecen el mismo servicio: uno con un horario pasado (para
/// probar que se descarta) y otro dos con horarios futuros a distinta
/// distancia de "ahora", calculados en el momento de la llamada para no
/// depender de la hora real en que corra la prueba.
class FakeTicketsService extends TicketsService {
  FakeTicketsService({required super.branchId});

  final List<Map<String, Object?>> createdCalls = [];

  @override
  Future<List<AvailableAppointmentSlot>> getAvailableAppointmentSlots({
    required String serviceId,
    required String stylistId,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    if (stylistId == 'stylist-1') {
      return [
        AvailableAppointmentSlot(
          startsAt: now.subtract(const Duration(minutes: 30)),
          endsAt: now.subtract(const Duration(minutes: 15)),
        ),
        AvailableAppointmentSlot(
          startsAt: now.add(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 1, minutes: 15)),
        ),
      ];
    }
    return [
      AvailableAppointmentSlot(
        startsAt: now.add(const Duration(minutes: 20)),
        endsAt: now.add(const Duration(minutes: 35)),
      ),
    ];
  }

  @override
  Future<bool> createScheduledTicketWithService({
    required String clientId,
    required String serviceId,
    required String stylistId,
    required DateTime scheduledAt,
    String channel = 'manual',
    String? notes,
  }) async {
    createdCalls.add({
      'clientId': clientId,
      'serviceId': serviceId,
      'stylistId': stylistId,
      'scheduledAt': scheduledAt,
    });
    return true;
  }
}

void main() {
  testWidgets(
      'Atender ya (walk-in): reutiliza "Cualquiera disponible" y elige el '
      'horario más próximo entre todos los estilistas, sin saltarse el '
      'cálculo de disponibilidad (bloque de velocidad de mostrador)',
      (tester) async {
    final fakeTicketsService = FakeTicketsService(
      branchId: '00000000-0000-0000-0000-000000000001',
    );

    const options = [
      TicketServiceOption(
        serviceId: 'service-1',
        serviceName: 'Corte',
        category: 'Cabello',
        price: 40000,
        durationMinutes: 30,
        stylistId: 'stylist-1',
        stylistName: 'Valentina',
      ),
      TicketServiceOption(
        serviceId: 'service-1',
        serviceName: 'Corte',
        category: 'Cabello',
        price: 40000,
        durationMinutes: 30,
        stylistId: 'stylist-2',
        stylistName: 'Carlos',
      ),
    ];

    const clients = [
      ClientSummary(
        id: 'client-1',
        name: 'Camila Ospina',
        phone: '+573109876543',
        createdAt: null,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (context) => CreateAppointmentDialog(
                  clients: clients,
                  clientsService: const ClientsService(),
                  ticketsService: fakeTicketsService,
                  options: options,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // 1. Servicio
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corte · \$40.000').last);
    await tester.pumpAndSettle();

    // Atender ya (walk-in): sin elegir estilista ni fecha a mano.
    expect(find.text('Atender ya (walk-in)'), findsOneWidget);
    await tester.tap(find.text('Atender ya (walk-in)'));
    await tester.pumpAndSettle();

    // El horario elegido es el de Carlos (20 min), el más próximo entre los
    // futuros -- el de Valentina a -30 min queda descartado por pasado, y el
    // de Valentina a +1h queda descartado por ser más lejano.
    expect(find.textContaining('Corte con Carlos'), findsOneWidget);

    // 4. Cliente
    final clienteDropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(clienteDropdown);
    await tester.pumpAndSettle();
    await tester.tap(clienteDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camila Ospina · +573109876543').last);
    await tester.pumpAndSettle();

    final crearReserva = find.text('Crear reserva');
    await tester.ensureVisible(crearReserva);
    await tester.pumpAndSettle();
    await tester.tap(crearReserva);
    await tester.pumpAndSettle();

    expect(fakeTicketsService.createdCalls, hasLength(1));
    expect(fakeTicketsService.createdCalls.single['stylistId'], 'stylist-2');
    expect(fakeTicketsService.createdCalls.single['clientId'], 'client-1');
  });
}
