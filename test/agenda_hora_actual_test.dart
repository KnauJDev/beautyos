import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_board.dart';
import 'package:salonymas/pages/agenda_page.dart';
import 'package:salonymas/services/agenda_board_service.dart';

/// I-18 + I-20 (decisiones del propietario, 29-sep): la vista Día abre
/// siempre en «Cada 1 hora»; el tablero se desplaza por dentro con los
/// encabezados fijos; y al abrir HOY, la fila de la hora actual queda la
/// primera visible. Nació de una captura del propietario: a las 12:43 el
/// tablero abría en las 08:00 y al bajar se perdían los títulos.
class _ServicioFalso extends AgendaBoardService {
  _ServicioFalso(this.conteos)
      : super(branchId: '00000000-0000-0000-0000-000000000001');

  final List<TicketBoardCount> conteos;
  final granularidades = <String>[];

  @override
  Future<List<TicketBoardCount>> getBoardCounts({
    required DateTime startDate,
    required DateTime endDate,
    String granularity = '15min',
  }) async {
    granularidades.add(granularity);
    return conteos;
  }

  @override
  Future<List<TicketBoardItem>> getBoardList({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? statuses,
    String? bucket,
    String? granularity,
  }) async =>
      const [];
}

DateTime _hoyA(int hora, int minuto) {
  final hoy = DateTime.now();
  return DateTime(hoy.year, hoy.month, hoy.day, hora, minuto);
}

Future<_ServicioFalso> _montar(
  WidgetTester tester, {
  required DateTime ahora,
  List<TicketBoardCount> conteos = const [],
}) async {
  final servicio = _ServicioFalso(conteos);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AgendaPage(
          branchId: '00000000-0000-0000-0000-000000000001',
          agendaService: servicio,
          reloj: () => ahora,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return servicio;
}

void main() {
  group('indiceDeLaHoraActual', () {
    const porHora = [
      '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00',
      '15:00', '16:00', '17:00', '18:00', '19:00', '20:00',
    ];

    test('a las 12:43 cae en la fila de las 12:00 (la captura del 27-sep)', () {
      expect(porHora[indiceDeLaHoraActual(porHora, _hoyA(12, 43))], '12:00');
    });

    test('en punto cae en su propia fila', () {
      expect(porHora[indiceDeLaHoraActual(porHora, _hoyA(15, 0))], '15:00');
    });

    test('antes de abrir, la primera; despues de cerrar, la ultima', () {
      expect(indiceDeLaHoraActual(porHora, _hoyA(6, 30)), 0);
      expect(indiceDeLaHoraActual(porHora, _hoyA(22, 10)), porHora.length - 1);
    });

    test('con intervalos de 15 min cae en el cuarto de hora que va', () {
      const cuartos = ['10:00', '10:15', '10:30', '10:45'];
      expect(cuartos[indiceDeLaHoraActual(cuartos, _hoyA(10, 20))], '10:15');
    });

    test('sin franjas no revienta', () {
      expect(indiceDeLaHoraActual(const [], _hoyA(10, 0)), 0);
    });
  });

  testWidgets('I-18: la vista Dia abre en «Cada 1 hora»', (tester) async {
    final servicio = await _montar(tester, ahora: _hoyA(8, 0));
    expect(find.text('Cada 1 hora'), findsOneWidget);
    expect(servicio.granularidades.first, 'hour');
  });

  testWidgets(
      'I-20: a las 18:30 de hoy abre en las 18:00, con los encabezados a la vista',
      (tester) async {
    await _montar(
      tester,
      ahora: _hoyA(18, 30),
      conteos: const [
        TicketBoardCount(
          bucket: '18:00',
          status: 'confirmado',
          ticketCount: 3,
          totalPrice: 150000,
          totalPendingBalance: 150000,
        ),
      ],
    );

    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // La fila de las 08:00 quedó arriba, fuera del tablero.
    expect(find.text('08:00'), findsNothing);
    // Y los encabezados siguen ahí.
    expect(find.text('HORA'), findsOneWidget);
    expect(find.text('Por confirmar'), findsWidgets);
  });

  testWidgets('I-20: otro dia no salta: abre en las 08:00', (tester) async {
    final servicio = _ServicioFalso(const []);
    final ahora = _hoyA(18, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgendaPage(
            branchId: '00000000-0000-0000-0000-000000000001',
            agendaService: servicio,
            reloj: () => ahora,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsNothing);

    // Día siguiente.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
  });
}
