import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_summary.dart';
import 'package:salonymas/services/tickets_service.dart';

/// La lista de Tickets vuelve a la RPC del Tablero (D-204).
///
/// **Estas pruebas ejercitan el comportamiento**, que es la lección que dejó
/// D-203: aquel día las guardianas leían el código fuente, seguían en verde, y
/// la pantalla estaba caída en producción.
///
/// Aquí se prueban las dos cosas que de verdad podían salir mal al cambiar de
/// RPC, y las dos son silenciosas:
///
/// 1. **El orden.** La RPC del Tablero devuelve de más antiguo a más nuevo
///    porque es una línea de tiempo. Esta pantalla es un historial. Con la
///    paginación de diez en diez de D-199, equivocarse aquí significa abrir
///    Tickets y ver los diez tickets más viejos del salón.
/// 2. **Las columnas.** La RPC nueva trae `pending_balance` donde la vieja
///    traía `balance_amount`. Leer mal esa clave habría enseñado **saldo cero
///    en todos los tickets** — o sea "está todo pagado" cuando no lo está.
void main() {
  group('D-204 — El historial se ordena de lo más reciente a lo más viejo', () {
    TicketSummary ticket({
      required String codigo,
      DateTime? programado,
    }) {
      return TicketSummary.fromMap({
        'id': 'id-$codigo',
        'ticket_code': codigo,
        'client_name': 'Camila',
        'scheduled_at': programado?.toIso8601String(),
        'status': 'confirmado',
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Valentina',
        'total_price': 50000,
        'total_duration_minutes': 60,
        'paid_amount': 0,
        'pending_balance': 50000,
        'payment_status': 'sin_pago',
      });
    }

    test('lo más reciente va primero', () {
      // Tal y como los devuelve la RPC del Tablero: ascendente.
      final comoLosDevuelveLaRpc = [
        ticket(codigo: '0000001', programado: DateTime.utc(2026, 1, 10)),
        ticket(codigo: '0000002', programado: DateTime.utc(2026, 6, 15)),
        ticket(codigo: '0000003', programado: DateTime.utc(2026, 9, 4)),
      ];

      final ordenados = ordenarTicketsParaLaLista(comoLosDevuelveLaRpc);

      expect(
        ordenados.map((t) => t.ticketCode).toList(),
        ['0000003', '0000002', '0000001'],
        reason:
            'El historial abre por lo más reciente. Si sale al revés, con la '
            'paginación de D-199 el salón ve sus diez tickets más antiguos al '
            'entrar, y parece que la pantalla se rompió.',
      );
    });

    test('los que no tienen fecha van al final, no al principio', () {
      // Hoy no hay ninguno (el propietario contó 0 el 04-sep), pero la columna
      // admite nulos. Si algún día aparece uno, que no encabece la lista.
      final tickets = [
        ticket(codigo: '0000001', programado: null),
        ticket(codigo: '0000002', programado: DateTime.utc(2026, 6, 15)),
        ticket(codigo: '0000003', programado: DateTime.utc(2026, 9, 4)),
      ];

      final ordenados = ordenarTicketsParaLaLista(tickets);

      expect(
        ordenados.map((t) => t.ticketCode).toList(),
        ['0000003', '0000002', '0000001'],
        reason: 'Reproduce el "nulls last" que tenía la consulta anterior.',
      );
    });

    test('a igual fecha, desempata por número de ticket descendente', () {
      final mismaHora = DateTime.utc(2026, 9, 4, 10);
      final tickets = [
        ticket(codigo: '0000007', programado: mismaHora),
        ticket(codigo: '0000009', programado: mismaHora),
        ticket(codigo: '0000008', programado: mismaHora),
      ];

      expect(
        ordenarTicketsParaLaLista(tickets).map((t) => t.ticketCode).toList(),
        ['0000009', '0000008', '0000007'],
      );
    });

    test('no altera la lista que recibe', () {
      // La lista de origen es la que devuelve la RPC; reordenarla en el sitio
      // sería un efecto colateral silencioso sobre quien la esté leyendo.
      final original = [
        ticket(codigo: '0000001', programado: DateTime.utc(2026, 1, 10)),
        ticket(codigo: '0000002', programado: DateTime.utc(2026, 9, 4)),
      ];
      final copiaDeControl = original.map((t) => t.ticketCode).toList();

      ordenarTicketsParaLaLista(original);

      expect(original.map((t) => t.ticketCode).toList(), copiaDeControl);
    });

    test('una lista vacía no rompe nada', () {
      expect(ordenarTicketsParaLaLista(const <TicketSummary>[]), isEmpty);
    });
  });

  group('D-204 — Lo que la RPC del Tablero devuelve y el respaldo no', () {
    /// Una fila tal y como la devuelve `get_ticket_board_list_v2`, con sus 19
    /// columnas. Los nombres salen del `returns table` de la migración
    /// `20260817210000_numero_de_venta_por_sede.sql`.
    Map<String, dynamic> filaDelTablero() => {
      'id': 'a1111111-1111-1111-1111-111111111111',
      'ticket_number': 701,
      'ticket_code': '0000701',
      'sale_number': 45,
      'sale_code': 'VTA-0000045',
      'closed_at': '2026-09-04T15:00:00Z',
      'client_id': 'c1111111-1111-1111-1111-111111111111',
      'client_name': 'Camila Restrepo',
      'client_phone': '3001234567',
      'scheduled_at': '2026-09-04T14:00:00Z',
      'status': 'cerrado',
      'channel': 'manual',
      'service_names': 'Balayage',
      'stylist_names': 'Valentina Gómez',
      'total_price': 180000,
      'total_duration_minutes': 120,
      'paid_amount': 100000,
      'pending_balance': 80000,
      'payment_status': 'pagado_parcial',
    };

    test('el saldo se lee de pending_balance, no de balance_amount', () {
      // **La prueba que más importa de este archivo.** La RPC nueva llama al
      // saldo `pending_balance`; la vieja lo llamaba `balance_amount`. Si el
      // modelo solo leyera la clave vieja, TODOS los tickets mostrarían saldo
      // cero: el salón vería "está todo pagado" cuando no lo está.
      final ticket = TicketSummary.fromMap(filaDelTablero());

      expect(
        ticket.balanceAmount,
        80000,
        reason:
            'El saldo llegó en 0 o vacío. TicketSummary.fromMap tiene que '
            'leer balance_amount ?? pending_balance, porque las dos RPC lo '
            'llaman distinto.',
      );
      expect(ticket.paidAmount, 100000);
    });

    test('vuelven el chip de venta, el teléfono y el cliente', () {
      // Las tres cosas que el respaldo no traía y que por eso llevaban dos
      // semanas y media sin verse en la lista (D-203).
      final ticket = TicketSummary.fromMap(filaDelTablero());

      expect(ticket.saleNumber, 45, reason: 'Sin esto no hay chip VTA.');
      expect(ticket.saleCode, 'VTA-0000045');
      expect(
        ticket.clientPhone,
        '3001234567',
        reason:
            'Sin teléfono no aparece el botón de WhatsApp con el mensaje '
            'pre-armado (D-195), ni se puede buscar por teléfono.',
      );
      expect(ticket.clientId, 'c1111111-1111-1111-1111-111111111111');
      expect(ticket.closedAt, isNotNull);
    });

    test('con las columnas del respaldo, esos campos venían vacíos', () {
      // Deja escrito en una prueba lo que estuvo pasando en producción entre
      // el 17-ago y el 04-sep, para que se entienda por qué se volvió a la
      // RPC del Tablero y qué se perdía mientras tanto.
      final filaDelRespaldo = Map<String, dynamic>.of(filaDelTablero())
        ..remove('sale_number')
        ..remove('sale_code')
        ..remove('closed_at')
        ..remove('client_id')
        ..remove('client_phone')
        ..remove('pending_balance')
        ..['balance_amount'] = 80000;

      final ticket = TicketSummary.fromMap(filaDelRespaldo);

      expect(ticket.saleNumber, isNull);
      expect(ticket.saleCode, isNull);
      expect(ticket.clientPhone, '');
      // El saldo sí era correcto: esa media la cubría la clave vieja.
      expect(ticket.balanceAmount, 80000);
    });
  });
}
