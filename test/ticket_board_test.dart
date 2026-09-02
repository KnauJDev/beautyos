import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_board.dart';
import 'package:salonymas/pages/agenda_page.dart';
import 'package:salonymas/services/agenda_board_service.dart';
import 'package:salonymas/widgets/ticket_status.dart';

class FakeAgendaBoardService extends AgendaBoardService {
  final List<TicketBoardCount> mockCounts;
  final List<TicketBoardItem> mockItems;

  FakeAgendaBoardService({
    this.mockCounts = const [],
    this.mockItems = const [],
  }) : super(branchId: '00000000-0000-0000-0000-000000000001');

  @override
  Future<List<TicketBoardCount>> getBoardCounts({
    required DateTime startDate,
    required DateTime endDate,
    String granularity = '15min',
  }) async {
    return mockCounts;
  }

  @override
  Future<List<TicketBoardItem>> getBoardList({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? statuses,
    String? bucket,
    String? granularity,
  }) async {
    return mockItems;
  }
}

void main() {
  group('TicketBoard Models & Formatters', () {
    test('formatCOP formatea números en pesos colombianos con separadores de miles', () {
      expect(formatCOP(0), '\$0');
      expect(formatCOP(500), '\$500');
      expect(formatCOP(1000), '\$1.000');
      expect(formatCOP(35000), '\$35.000');
      expect(formatCOP(1250000), '\$1.250.000');
    });

    test('formatCOP en millones y cifras grandes', () {
      expect(formatCOP(1000000), '\$1.000.000');
      expect(formatCOP(25000000), '\$25.000.000');
      expect(formatCOP(999999999), '\$999.999.999');
    });

    test('formatCOP redondea decimales a pesos enteros antes de agrupar', () {
      expect(formatCOP(1234.4), '\$1.234');
      expect(formatCOP(1234.5), '\$1.235');
      expect(formatCOP(999.9), '\$1.000');
      expect(formatCOP(0.4), '\$0');
    });

    test(
        'formatCOP con números negativos (TL-12, D-198): el signo "-" va '
        'antes del "\$" y nunca cuenta como un dígito más para el separador '
        'de miles -- el bug que compartían las 13 copias sueltas producía '
        '"\$-.100" en vez de "-\$100"',
        () {
      expect(formatCOP(-1), '-\$1');
      expect(formatCOP(-100), '-\$100');
      expect(formatCOP(-999), '-\$999');
      expect(formatCOP(-1000), '-\$1.000');
      expect(formatCOP(-50000), '-\$50.000');
      expect(formatCOP(-1250000), '-\$1.250.000');
    });

    test('formatCOP redondea decimales negativos antes de agrupar', () {
      expect(formatCOP(-1234.6), '-\$1.235');
      // -0.4 redondea a 0 (entero), y 0 no es negativo: no debe verse "-\$0".
      expect(formatCOP(-0.4), '\$0');
    });

    test('TicketBoardCount mapea correctamente desde JSON de RPC', () {
      final map = {
        'bucket': '08:15',
        'status': 'solicitado',
        'ticket_count': 3,
        'total_price': 105000.0,
        'total_pending_balance': 70000.0,
      };

      final count = TicketBoardCount.fromMap(map);
      expect(count.bucket, '08:15');
      expect(count.status, 'solicitado');
      expect(count.ticketCount, 3);
      expect(count.totalPrice, 105000.0);
      expect(count.totalPendingBalance, 70000.0);
      expect(count.ticketStatus, TicketStatus.solicitado);
    });

    test('TicketBoardItem mapea consecutivo #0000701 y finanzas', () {
      final map = {
        'id': 'a1b2c3d4-0000-0000-0000-000000000001',
        'ticket_number': 701,
        'ticket_code': '#0000701',
        'client_id': 'c1c2c3c4-0000-0000-0000-000000000001',
        'client_name': 'Ana María Pérez',
        'client_phone': '+573001234567',
        'scheduled_at': '2026-08-17T08:15:00Z',
        'status': 'finalizado',
        'channel': 'online',
        'service_names': 'Corte Dama, Cepillado',
        'stylist_names': 'Valentina Estilista',
        'total_price': 80000.0,
        'total_duration_minutes': 75,
        'paid_amount': 30000.0,
        'pending_balance': 50000.0,
        'payment_status': 'parcial',
      };

      final item = TicketBoardItem.fromMap(map);
      expect(item.id, 'a1b2c3d4-0000-0000-0000-000000000001');
      expect(item.ticketNumber, 701);
      expect(item.ticketCode, '#0000701');
      expect(item.clientName, 'Ana María Pérez');
      expect(item.clientPhone, '+573001234567');
      expect(item.ticketStatus, TicketStatus.finalizado);
      expect(item.totalPrice, 80000.0);
      expect(item.paidAmount, 30000.0);
      expect(item.pendingBalance, 50000.0);
      expect(item.paymentStatus, 'parcial');
    });

    test('DayBoardColumn agrupa los estados según D-101', () {
      expect(DayBoardColumn.porConfirmar.contiene('solicitado'), isTrue);
      expect(DayBoardColumn.porConfirmar.contiene('cotizado'), isTrue);
      expect(DayBoardColumn.porConfirmar.contiene('apartado'), isTrue);
      expect(DayBoardColumn.porConfirmar.contiene('confirmado'), isFalse);

      expect(DayBoardColumn.confirmado.contiene('confirmado'), isTrue);
      expect(DayBoardColumn.confirmado.contiene('en_espera'), isTrue);

      expect(DayBoardColumn.enProceso.contiene('en_proceso'), isTrue);
      expect(DayBoardColumn.porCobrar.contiene('finalizado'), isTrue);
      expect(DayBoardColumn.cerrado.contiene('cerrado'), isTrue);
    });

    test('WeekBoardColumn discrimina los estados según D-101', () {
      expect(WeekBoardColumn.solicitado.contiene('solicitado'), isTrue);
      expect(WeekBoardColumn.cotizado.contiene('cotizado'), isTrue);
      expect(WeekBoardColumn.apartado.contiene('apartado'), isTrue);
      expect(WeekBoardColumn.confirmado.contiene('confirmado'), isTrue);
      expect(WeekBoardColumn.porCobrar.contiene('finalizado'), isTrue);
      expect(WeekBoardColumn.cerrado.contiene('cerrado'), isTrue);
    });

    test('buildWhatsAppUri deja solo dígitos, sin el "+" del teléfono guardado',
        () {
      final uri = buildWhatsAppUri('+57 310 987 6543');
      expect(uri.toString(), 'https://wa.me/573109876543');
      expect(uri.toString(), isNot(contains('+')));
    });

    test(
        'buildAppointmentReminderMessage arma el texto pre-cargado con '
        'cliente, servicio, hora y negocio (bloque de velocidad de mostrador)',
        () {
      final mensaje = buildAppointmentReminderMessage(
        clientName: 'Camila Ospina',
        serviceNames: 'Manicure Ruso',
        scheduledAt: DateTime(2026, 8, 17, 8, 15),
        businessName: 'Salón Bella Vita',
      );
      expect(
        mensaje,
        'Hola Camila Ospina 👋, te recordamos tu cita de Manicure Ruso '
        'hoy a las 08:15 en Salón Bella Vita.',
      );
    });

    test(
        'buildAppointmentReminderMessage cae en textos genéricos si falta '
        'la hora o el nombre del negocio',
        () {
      final mensaje = buildAppointmentReminderMessage(
        clientName: 'Camila Ospina',
        serviceNames: 'Manicure Ruso',
      );
      expect(
        mensaje,
        'Hola Camila Ospina 👋, te recordamos tu cita de Manicure Ruso '
        'hoy a las la hora acordada en nuestro salón.',
      );
    });
  });

  group('AgendaPage Widget Tests', () {
    testWidgets('Renderiza encabezados de Día y columnas del tablero D-101',
        (tester) async {
      final mockCounts = [
        const TicketBoardCount(
          bucket: '08:15',
          status: 'solicitado',
          ticketCount: 2,
          totalPrice: 90000,
          totalPendingBalance: 90000,
        ),
        const TicketBoardCount(
          bucket: '09:00',
          status: 'cerrado',
          ticketCount: 1,
          totalPrice: 45000,
          totalPendingBalance: 0,
        ),
      ];

      final fakeService = FakeAgendaBoardService(mockCounts: mockCounts);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaPage(
              branchId: '00000000-0000-0000-0000-000000000001',
              agendaService: fakeService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Título y columnas
      expect(find.text('Tablero de Agenda'), findsOneWidget);
      expect(find.text('Por confirmar'), findsWidgets);
      expect(find.text('Confirmado'), findsWidgets);
      expect(find.text('En proceso'), findsWidgets);
      expect(find.text('Por cobrar'), findsWidgets);
      expect(find.text('Cerrado'), findsWidgets);

      // Celda con conteo 2 en 08:15
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('Tocar celda de día abre modal Nivel 2 con consecutivo y WhatsApp',
        (tester) async {
      final mockCounts = [
        const TicketBoardCount(
          bucket: '08:15',
          status: 'solicitado',
          ticketCount: 1,
          totalPrice: 80000,
          totalPendingBalance: 80000,
        ),
      ];

      final mockItems = [
        TicketBoardItem(
          id: 'test-id-1',
          ticketNumber: 701,
          ticketCode: '#0000701',
          clientName: 'Camila Ospina',
          clientPhone: '+573109876543',
          scheduledAt: DateTime(2026, 8, 17, 8, 15),
          status: 'solicitado',
          channel: 'online',
          serviceNames: 'Manicure Ruso',
          stylistNames: 'Camila Manicurista',
          totalPrice: 80000,
          totalDurationMinutes: 60,
          paidAmount: 0,
          pendingBalance: 80000,
          paymentStatus: 'sin_pago',
        ),
      ];

      final fakeService = FakeAgendaBoardService(
        mockCounts: mockCounts,
        mockItems: mockItems,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaPage(
              branchId: '00000000-0000-0000-0000-000000000001',
              agendaService: fakeService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tocar la celda con conteo 1
      final cellFinder = find.text('1');
      expect(cellFinder, findsOneWidget);
      await tester.tap(cellFinder);
      await tester.pumpAndSettle();

      // Verificar modal Nivel 2 abierto
      expect(find.text('#0000701'), findsOneWidget);
      expect(find.text('Camila Ospina'), findsOneWidget);
      expect(find.text('+573109876543'), findsOneWidget);
      expect(find.text('✂️ Manicure Ruso · 👤 Camila Manicurista'), findsOneWidget);
      expect(find.text('Total: \$80.000'), findsOneWidget);
      expect(find.text('Saldo: \$80.000'), findsOneWidget);
    });

    testWidgets(
        'Botón de cobro directo (bloque de velocidad de mostrador): '
        'aparece con saldo pendiente y avisa al shell con el id del ticket',
        (tester) async {
      final mockCounts = [
        const TicketBoardCount(
          bucket: '08:15',
          status: 'finalizado',
          ticketCount: 1,
          totalPrice: 80000,
          totalPendingBalance: 50000,
        ),
      ];

      final mockItems = [
        TicketBoardItem(
          id: 'test-id-2',
          ticketNumber: 702,
          ticketCode: '#0000702',
          clientName: 'Camila Ospina',
          clientPhone: '+573109876543',
          scheduledAt: DateTime(2026, 8, 17, 8, 15),
          status: 'finalizado',
          channel: 'online',
          serviceNames: 'Manicure Ruso',
          stylistNames: 'Camila Manicurista',
          totalPrice: 80000,
          totalDurationMinutes: 60,
          paidAmount: 30000,
          pendingBalance: 50000,
          paymentStatus: 'parcial',
        ),
      ];

      final fakeService = FakeAgendaBoardService(
        mockCounts: mockCounts,
        mockItems: mockItems,
      );

      String? collectedTicketId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaPage(
              branchId: '00000000-0000-0000-0000-000000000001',
              agendaService: fakeService,
              onCollectTicket: (ticketId) => collectedTicketId = ticketId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      final botonCobrar = find.text('Cobrar \$50.000');
      expect(botonCobrar, findsOneWidget);

      await tester.tap(botonCobrar);
      await tester.pumpAndSettle();

      expect(collectedTicketId, 'test-id-2');
    });

    testWidgets(
        'Sin saldo pendiente no aparece el botón de cobro directo',
        (tester) async {
      final mockCounts = [
        const TicketBoardCount(
          bucket: '08:15',
          status: 'cerrado',
          ticketCount: 1,
          totalPrice: 80000,
          totalPendingBalance: 0,
        ),
      ];

      final mockItems = [
        TicketBoardItem(
          id: 'test-id-3',
          ticketNumber: 703,
          ticketCode: '#0000703',
          clientName: 'Camila Ospina',
          clientPhone: '+573109876543',
          scheduledAt: DateTime(2026, 8, 17, 8, 15),
          status: 'cerrado',
          channel: 'online',
          serviceNames: 'Manicure Ruso',
          stylistNames: 'Camila Manicurista',
          totalPrice: 80000,
          totalDurationMinutes: 60,
          paidAmount: 80000,
          pendingBalance: 0,
          paymentStatus: 'pagado',
        ),
      ];

      final fakeService = FakeAgendaBoardService(
        mockCounts: mockCounts,
        mockItems: mockItems,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaPage(
              branchId: '00000000-0000-0000-0000-000000000001',
              agendaService: fakeService,
              onCollectTicket: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cobrar \$'), findsNothing);
    });

    testWidgets('Permite alternar a vista Semana y Mes', (tester) async {
      final fakeService = FakeAgendaBoardService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaPage(
              branchId: '00000000-0000-0000-0000-000000000001',
              agendaService: fakeService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cambiar a Semana
      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();
      expect(find.text('Lunes'), findsWidgets);
      expect(find.text('Domingo'), findsWidgets);

      // Cambiar a Mes
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      expect(find.text('LUN'), findsOneWidget);
      expect(find.text('DOM'), findsOneWidget);
    });

    testWidgets(
        'Atenúa los días pasados de la semana; hoy y los futuros quedan normales (D-101)',
        (tester) async {
      final fakeService = FakeAgendaBoardService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaPage(
              branchId: '00000000-0000-0000-0000-000000000001',
              agendaService: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();

      // La semana mostrada es la de hoy: de lunes (weekday 1) a domingo.
      // Días antes de hoy dentro de esa semana deben quedar atenuados
      // (opacity 0.55); hoy y los que faltan por venir, sin atenuar (1.0).
      final today = DateTime.now();
      final diasPasados = today.weekday - 1; // lunes..ayer
      final diasNoPasados = 7 - diasPasados; // hoy..domingo

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();

      expect(
        opacities.where((o) => o == 0.55).length,
        diasPasados,
        reason: 'Días pasados atenuados en la semana',
      );
      expect(
        opacities.where((o) => o == 1.0).length,
        diasNoPasados,
        reason: 'Hoy y los días futuros de la semana sin atenuar',
      );
    });
  });
}
