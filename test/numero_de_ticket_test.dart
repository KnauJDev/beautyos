import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_summary.dart';

/// Lo que estas pruebas SI cubren: que el consecutivo llegue entero desde la
/// base de datos hasta la pantalla, y que su ausencia se note en vez de
/// disfrazarse.
///
/// Lo que NO cubren, y hay que decirlo: la unicidad, el bloqueo de dos
/// recepcionistas creando a la vez y la imposibilidad de reescribir un numero
/// emitido viven en la base de datos (D-117), no en Dart. Eso se comprueba con
/// `supabase/sql/161_verify_numero_de_ticket.sql`.
void main() {
  group('el consecutivo del ticket viaja intacto (D-117)', () {
    test('se lee tal cual viene, con ceros y todo', () {
      final ticket = TicketSummary.fromMap(const {
        'id': '3f2b8c1a-9d4e-4f6a-8b2c-1d3e5f7a9b0c',
        'ticket_code': '0000042',
        'client_name': 'María Gómez',
        'status': 'finalizado',
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Ana',
        'total_price': 50000,
        'total_duration_minutes': 45,
        'paid_amount': 0,
        'balance_amount': 50000,
        'payment_status': 'sin_pago',
      });

      // Los ceros a la izquierda son parte del numero, no adorno: si alguien
      // lo convirtiera a entero por el camino, "0000042" llegaria como "42" y
      // dejaria de coincidir con lo que el negocio tiene escrito en papel.
      expect(ticket.ticketCode, '0000042');
    });

    test('admite el prefijo propio del negocio', () {
      final ticket = TicketSummary.fromMap(const {
        'id': 'a1',
        'ticket_code': 'FE-0000042',
        'client_name': 'Cliente',
        'status': 'cerrado',
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Ana',
        'total_price': 0,
        'total_duration_minutes': 0,
        'paid_amount': 0,
        'balance_amount': 0,
        'payment_status': 'sin_pago',
      });

      expect(ticket.ticketCode, 'FE-0000042');
    });

    test('si faltara, queda vacio y no se inventa un numero', () {
      final ticket = TicketSummary.fromMap(const {
        'id': 'a1',
        'client_name': 'Cliente',
        'status': 'solicitado',
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Ana',
        'total_price': 0,
        'total_duration_minutes': 0,
        'paid_amount': 0,
        'balance_amount': 0,
        'payment_status': 'sin_pago',
      });

      // Un "0000000" de relleno pareceria un ticket real y mandaria a alguien
      // a buscar algo que no existe. Vacio se ve, y se corrige.
      expect(ticket.ticketCode, '');
    });
  });
}
