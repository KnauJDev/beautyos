import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/sale_numbering.dart';
import 'package:salonymas/models/ticket_board.dart';
import 'package:salonymas/pages/agenda_page.dart';
import 'package:salonymas/services/agenda_board_service.dart';

class _FakeSaleAgendaBoardService extends AgendaBoardService {
  final List<TicketBoardCount> mockCounts;
  final List<TicketBoardItem> mockItems;

  _FakeSaleAgendaBoardService({
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
  group('BranchSaleNumbering Model & DIAN Rules (D-150 / Hallazgo P)', () {
    test('Mapea correctamente configuración por defecto', () {
      final json = {
        'tenant_id': '00000000-0000-0000-0000-000000000001',
        'branch_id': '00000000-0000-0000-0000-000000000002',
        'prefix': 'VTA-',
        'next_number': 1,
        'padding': 7,
        'last_emitted_number': 0,
        'updated_at': '2026-08-17T10:00:00Z',
      };

      final config = BranchSaleNumbering.fromJson(json);

      expect(config.prefix, 'VTA-');
      expect(config.nextNumber, 1);
      expect(config.padding, 7);
      expect(config.previewNextCode, 'VTA-0000001');
      expect(config.hasResolution, isFalse);
    });

    test('Mapea y valida reglas de Resolución DIAN', () {
      final json = {
        'tenant_id': '00000000-0000-0000-0000-000000000001',
        'branch_id': '00000000-0000-0000-0000-000000000002',
        'prefix': 'FJ-',
        'next_number': 20050,
        'padding': 6,
        'resolution_number': '18764000001234',
        'resolution_date': '2026-08-01',
        'range_from': 20000,
        'range_to': 29999,
        'valid_until': '2028-08-01',
        'last_emitted_number': 20049,
      };

      final config = BranchSaleNumbering.fromJson(json);

      expect(config.prefix, 'FJ-');
      expect(config.nextNumber, 20050);
      expect(config.previewNextCode, 'FJ-020050');
      expect(config.hasResolution, isTrue);
      expect(config.resolutionNumber, '18764000001234');
      expect(config.isNearLimit, isFalse);
      expect(config.isExpiringSoon, isFalse);
    });

    test('Detecta límite próximo de resolución DIAN', () {
      final config = BranchSaleNumbering(
        tenantId: 't1',
        branchId: 'b1',
        prefix: 'FJ-',
        nextNumber: 29950,
        rangeFrom: 20000,
        rangeTo: 29999,
        updatedAt: DateTime.now(),
      );

      expect(config.isNearLimit, isTrue);
    });
  });

  group('TicketBoardItem & UI Chips Duales (D-150 / Hallazgo P)', () {
    test('TicketBoardItem mapea campos de venta contable', () {
      final map = {
        'id': 't1',
        'ticket_number': 701,
        'ticket_code': '#0000701',
        'sale_number': 45,
        'sale_code': 'VTA-0000045',
        'closed_at': '2026-08-17T18:30:00Z',
        'client_name': 'Camila',
        'client_phone': '3001234567',
        'status': 'cerrado',
        'total_price': 80000,
        'paid_amount': 80000,
        'pending_balance': 0,
      };

      final item = TicketBoardItem.fromMap(map);

      expect(item.ticketCode, '#0000701');
      expect(item.saleNumber, 45);
      expect(item.saleCode, 'VTA-0000045');
      expect(item.closedAt, isNotNull);
    });

    testWidgets(
        'Modal Nivel 2 renderiza Chip Cita #0000701 y Chip Venta VTA-0000045',
        (tester) async {
      final fakeService = _FakeSaleAgendaBoardService(
        mockCounts: [
          const TicketBoardCount(
            bucket: '08:00',
            status: 'cerrado',
            ticketCount: 1,
            totalPrice: 180000,
            totalPendingBalance: 0,
          ),
        ],
        mockItems: [
          TicketBoardItem(
            id: '00000000-0000-0000-0000-000000000101',
            ticketNumber: 701,
            ticketCode: '#0000701',
            saleNumber: 45,
            saleCode: 'VTA-0000045',
            closedAt: DateTime(2026, 8, 17, 18, 30),
            clientName: 'Laura Ospina',
            clientPhone: '+57 312 999 8888',
            scheduledAt: DateTime(2026, 8, 17, 8, 0),
            status: 'cerrado',
            channel: 'manual',
            serviceNames: 'Balayage Premium',
            stylistNames: 'Diana Gómez',
            totalPrice: 180000,
            totalDurationMinutes: 120,
            paidAmount: 180000,
            pendingBalance: 0,
            paymentStatus: 'pagado',
          ),
        ],
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

      // Abrir modal Nivel 2 tocando celda cerrada ('1')
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();

      // Verificar que ambos chips coexisten en pantalla
      expect(find.text('#0000701'), findsOneWidget);
      expect(find.text('VTA-0000045'), findsOneWidget);
      expect(find.text('Laura Ospina'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });
  });
}
