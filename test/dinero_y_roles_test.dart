import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/acciones_de_ticket.dart';
import 'package:salonymas/models/ticket_summary.dart';

/// Accion A6 de la Etapa A, primera mitad de H-03.
///
/// **Por que existe.** Hasta hoy habia 73 pruebas y **ninguna tocaba dinero ni
/// roles**. Las tres regresiones del 06-ago las encontro el propietario
/// probando en produccion: el asistente sin pantallas (D-092 incompleta), el
/// propietario expulsado de su propio modulo de Clientes (D-094) y los botones
/// de anular pago visibles para quien el servidor rechazaba (D-095).
///
/// **Lo que estas pruebas SI cubren:** la parte de las reglas de dinero y de
/// permisos que vive en la aplicacion -- como se deriva el saldo y el estado
/// de pago de lo que devuelve el servidor, como se escribe una cifra, y que
/// acciones se le ofrecen a cada rol en cada estado.
///
/// **Lo que NO cubren, y hay que decirlo sin adornos:** el calculo del dinero
/// vive en la base de datos, no aqui. El saldo real, la resolucion de la
/// comision y el costo promedio ponderado se comprueban con
/// `supabase/sql/163_test_reglas_de_dinero.sql`, que hay que **ejecutar a
/// mano**. Que eso corra solo en cada cambio exige una base de pruebas, que es
/// la accion **A2** y todavia no existe.
void main() {
  group('el saldo y el estado de pago se leen sin inventar nada', () {
    TicketSummary conDinero({
      required num total,
      required num pagado,
      required num saldo,
      required String estadoPago,
      String estado = 'finalizado',
    }) {
      return TicketSummary.fromMap({
        'id': 'a1',
        'ticket_code': '0000001',
        'client_name': 'Cliente',
        'status': estado,
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Ana',
        'total_price': total,
        'total_duration_minutes': 45,
        'paid_amount': pagado,
        'balance_amount': saldo,
        'payment_status': estadoPago,
      });
    }

    test('un ticket sin pagos queda con el saldo completo', () {
      final ticket = conDinero(
        total: 50000,
        pagado: 0,
        saldo: 50000,
        estadoPago: 'sin_pago',
      );

      expect(ticket.paidAmount, 0);
      expect(ticket.balanceAmount, 50000);
      expect(ticket.paymentStatus, 'sin_pago');
    });

    test('un abono parcial deja saldo y se marca como parcial', () {
      final ticket = conDinero(
        total: 50000,
        pagado: 20000,
        saldo: 30000,
        estadoPago: 'parcial',
      );

      expect(ticket.balanceAmount, 30000);
      expect(ticket.paymentStatus, 'parcial');
    });

    test('pagado completo deja saldo en cero', () {
      final ticket = conDinero(
        total: 50000,
        pagado: 50000,
        saldo: 0,
        estadoPago: 'pagado',
      );

      expect(ticket.balanceAmount, 0);
      expect(ticket.paymentStatus, 'pagado');
    });

    test('los decimales que llegan como texto no se pierden', () {
      // PostgREST puede devolver `numeric` como cadena. Si esto se leyera con
      // `as num` en vez de convertirlo, reventaria en produccion con un ticket
      // real y no en ninguna prueba.
      final ticket = TicketSummary.fromMap({
        'id': 'a1',
        'ticket_code': '0000001',
        'client_name': 'Cliente',
        'status': 'finalizado',
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Ana',
        'total_price': '50000.00',
        'total_duration_minutes': '45',
        'paid_amount': '20000.00',
        'balance_amount': '30000.00',
        'payment_status': 'parcial',
      });

      expect(ticket.totalPrice, 50000);
      expect(ticket.balanceAmount, 30000);
      expect(ticket.totalDurationMinutes, 45);
    });

    test('la informacion de pago solo aparece cuando hay dinero de por medio', () {
      final agendado = conDinero(
        total: 50000,
        pagado: 0,
        saldo: 50000,
        estadoPago: 'sin_pago',
        estado: 'confirmado',
      );
      expect(agendado.showsPaymentInfo, isFalse);

      final finalizado = conDinero(
        total: 50000,
        pagado: 0,
        saldo: 50000,
        estadoPago: 'sin_pago',
      );
      expect(finalizado.showsPaymentInfo, isTrue);

      final conAbono = conDinero(
        total: 50000,
        pagado: 10000,
        saldo: 40000,
        estadoPago: 'parcial',
        estado: 'confirmado',
      );
      expect(conAbono.showsPaymentInfo, isTrue);
    });
  });

  group('el dinero se escribe como lo lee una persona en Colombia', () {
    String formatear(num valor) {
      return TicketSummary.fromMap({
        'id': 'a1',
        'ticket_code': '0000001',
        'client_name': 'Cliente',
        'status': 'finalizado',
        'channel': 'manual',
        'service_names': 'Corte',
        'stylist_names': 'Ana',
        'total_price': valor,
        'total_duration_minutes': 0,
        'paid_amount': 0,
        'balance_amount': 0,
        'payment_status': 'sin_pago',
      }).formattedPrice;
    }

    test('separa los miles con punto', () {
      expect(formatear(0), r'$0');
      expect(formatear(500), r'$500');
      expect(formatear(1000), r'$1.000');
      expect(formatear(20000), r'$20.000');
      expect(formatear(120000), r'$120.000');
      expect(formatear(1500000), r'$1.500.000');
    });

    test('no muestra decimales, porque en pesos no se cobran', () {
      expect(formatear(50000.4), r'$50.000');
    });
  });

  group('que se le ofrece a cada rol y en cada estado (D-095)', () {
    test('corregir una finalizacion es solo de dueno y administrador', () {
      // Toca comisiones ya calculadas. Es la accion que el asistente veia y
      // el servidor le negaba.
      expect(
        AccionesDeTicket.puedeCorregirFinalizacion(
          'finalizado',
          esDuenoOAdmin: true,
        ),
        isTrue,
      );
      expect(
        AccionesDeTicket.puedeCorregirFinalizacion(
          'finalizado',
          esDuenoOAdmin: false,
        ),
        isFalse,
      );
      expect(
        AccionesDeTicket.puedeCorregirFinalizacion(
          'en_proceso',
          esDuenoOAdmin: false,
        ),
        isFalse,
      );
    });

    test('cobrar es de recepcion tambien: no depende del rol', () {
      // El asistente cobra desde D-092; lo que no puede es deshacer.
      expect(AccionesDeTicket.puedeGestionarPagos('finalizado'), isTrue);
      expect(AccionesDeTicket.puedeGestionarPagos('cerrado'), isTrue);
      expect(AccionesDeTicket.puedeGestionarPagos('confirmado'), isFalse);
      expect(AccionesDeTicket.puedeGestionarPagos('solicitado'), isFalse);
    });

    test('un ticket ya atendido no admite cambios de servicios ni de hora', () {
      for (final estado in ['en_proceso', 'finalizado', 'cerrado']) {
        expect(
          AccionesDeTicket.puedeAgregarServicios(estado),
          isFalse,
          reason: 'no deberia poder agregar servicios en $estado',
        );
        expect(
          AccionesDeTicket.puedeReprogramar(estado, tieneFecha: true),
          isFalse,
          reason: 'no deberia poder reprogramar en $estado',
        );
      }
    });

    test('sin fecha no se puede reprogramar', () {
      expect(
        AccionesDeTicket.puedeReprogramar('confirmado', tieneFecha: false),
        isFalse,
      );
      expect(
        AccionesDeTicket.puedeReprogramar('confirmado', tieneFecha: true),
        isTrue,
      );
    });

    test('sin servicios no hay nada que gestionar', () {
      expect(AccionesDeTicket.puedeGestionarServicios('confirmado', 0), isFalse);
      expect(AccionesDeTicket.puedeGestionarServicios('confirmado', 45), isTrue);
    });

    test('a un ticket cancelado o no asistido no se le agregan fotos', () {
      expect(AccionesDeTicket.puedeAgregarFoto('cancelado'), isFalse);
      expect(AccionesDeTicket.puedeAgregarFoto('no_asistio'), isFalse);
      expect(AccionesDeTicket.puedeAgregarFoto('finalizado'), isTrue);
    });
  });

  group('el ticket no puede retroceder de estado', () {
    test('de los estados finales no se sale cambiando el estado a mano', () {
      for (final estado in [
        'finalizado',
        'cerrado',
        'cancelado',
        'no_asistio',
      ]) {
        expect(
          AccionesDeTicket.siguientesEstados(estado),
          isEmpty,
          reason: '$estado no deberia ofrecer ningun cambio de estado',
        );
        expect(AccionesDeTicket.puedeCambiarEstado(estado), isFalse);
      }
    });

    test('ningun estado puede volver a uno anterior', () {
      // El orden comercial del ticket. Si algun dia alguien agrega una
      // transicion hacia atras, esta prueba lo detiene: retroceder revive
      // trabajo ya cobrado y descuadra la caja.
      const orden = [
        'solicitado',
        'cotizado',
        'apartado',
        'confirmado',
        'en_espera',
        'en_proceso',
        'finalizado',
        'cerrado',
      ];

      for (var i = 0; i < orden.length; i++) {
        for (final siguiente in AccionesDeTicket.siguientesEstados(orden[i])) {
          // Cancelado y no asistio son salidas laterales, no retrocesos.
          if (siguiente == 'cancelado' || siguiente == 'no_asistio') continue;

          expect(
            orden.indexOf(siguiente),
            greaterThan(i),
            reason: '${orden[i]} no deberia poder volver a $siguiente',
          );
        }
      }
    });

    test('cancelar es posible mientras no se haya atendido', () {
      for (final estado in [
        'solicitado',
        'cotizado',
        'apartado',
        'confirmado',
        'en_espera',
      ]) {
        expect(
          AccionesDeTicket.siguientesEstados(estado),
          contains('cancelado'),
          reason: '$estado deberia poder cancelarse',
        );
      }
    });
  });
}
