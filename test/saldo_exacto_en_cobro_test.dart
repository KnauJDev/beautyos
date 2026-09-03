import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_board.dart' show formatCOP;
import 'package:salonymas/models/ticket_payment.dart';
import 'package:salonymas/models/ticket_summary.dart';
import 'package:salonymas/pages/tickets_page.dart';
import 'package:salonymas/theme/app_theme.dart';

/// El atajo de saldo exacto al cobrar (UX-07, D-200).
///
/// **Qué problema resuelve, exactamente.** No era que el campo empezara
/// vacío: `initState` ya lo rellenaba con el saldo. Lo que faltaba era la
/// **vuelta atrás**. En el mostrador pasa todo el rato: la clienta dice "te
/// abono 50", se teclea 50, y luego cambia de idea y paga todo — y ahí había
/// que borrar y volver a teclear la cifra completa a mano, con el riesgo de
/// equivocarse en un dígito y dejar el ticket con un saldo suelto que nadie
/// vuelve a mirar.
TicketSummary _ticket(String estado) {
  return TicketSummary.fromMap({
    'id': 't-cobro',
    'ticket_code': '0000900',
    'client_name': 'Marcela Ruiz',
    'client_phone': '+573001112233',
    'scheduled_at': '2026-09-02T14:00:00Z',
    'status': estado,
    'channel': 'manual',
    'service_names': 'Corte y peinado',
    'stylist_names': 'Sara Duque',
    'total_price': 180000,
    'total_duration_minutes': 60,
    'paid_amount': 30000,
    'balance_amount': 150000,
    'payment_status': 'pago_parcial',
  });
}

Widget _montar({
  required num saldo,
  String estado = 'finalizado',
  num pagado = 30000,
  num total = 180000,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: PaymentsDialog(
        ticket: _ticket(estado),
        summary: TicketPaymentSummary(
          totalAmount: total,
          paidAmount: pagado,
          balanceAmount: saldo,
          paymentStatus: saldo > 0 ? 'pago_parcial' : 'pagado_total',
        ),
        payments: const [],
        canVoid: false,
      ),
    ),
  );
}

Finder get _campoMonto => find.ancestor(
  of: find.text('Valor del pago'),
  matching: find.byType(TextFormField),
);

void main() {
  group('UX-07 — Atajo de saldo exacto', () {
    testWidgets('el chip enseña el saldo con el formato de moneda canónico', (
      tester,
    ) async {
      await tester.pumpWidget(_montar(saldo: 150000));

      // formatCOP es el único formateador de pesos del proyecto (D-198): el
      // chip no puede escribir la cifra a su manera.
      expect(
        find.text('Pagar saldo exacto (${formatCOP(150000)})'),
        findsOneWidget,
      );
      expect(find.text('Pagar saldo exacto (\$150.000)'), findsOneWidget);
    });

    testWidgets('devuelve el monto exacto después de teclear un abono parcial', (
      tester,
    ) async {
      await tester.pumpWidget(_montar(saldo: 150000));

      // El campo arranca con el saldo (eso ya existía antes de D-200)...
      expect(find.text('150000'), findsOneWidget);

      // ...la recepcionista teclea un abono parcial...
      await tester.enterText(_campoMonto, '50000');
      await tester.pump();
      expect(find.text('50000'), findsOneWidget);

      // ...y la clienta cambia de idea. Un toque y vuelve la cifra completa.
      await tester.tap(find.text('Pagar saldo exacto (\$150.000)'));
      await tester.pump();

      expect(find.text('150000'), findsOneWidget);
      expect(find.text('50000'), findsNothing);
    });

    testWidgets('deja el foco en "Registrar pago", listo para confirmar', (
      tester,
    ) async {
      await tester.pumpWidget(_montar(saldo: 150000));

      await tester.enterText(_campoMonto, '20000');
      await tester.pump();

      await tester.tap(find.text('Pagar saldo exacto (\$150.000)'));
      await tester.pump();

      final enfocado = FocusManager.instance.primaryFocus;
      expect(enfocado?.context, isNotNull);

      // El elemento que tiene el foco es el botón de confirmar: su subárbol
      // contiene la etiqueta. Quien cobra rellena y confirma sin volver a
      // tocar la pantalla.
      expect(
        find.descendant(
          of: find.byElementPredicate((e) => e == enfocado!.context),
          matching: find.text('Registrar pago'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el monto que rellena es entero: nada de centavos ni comas', (
      tester,
    ) async {
      // El saldo llega como `num` desde la base; los candados de D-175
      // obligan a pesos enteros, y el campo no debe recibir "150000.0", que
      // el validador aceptaría pero ensucia lo que se manda a cobrar.
      await tester.pumpWidget(_montar(saldo: 150000.0));

      await tester.enterText(_campoMonto, '1');
      await tester.pump();
      await tester.tap(find.text('Pagar saldo exacto (\$150.000)'));
      await tester.pump();

      expect(find.text('150000'), findsOneWidget);
      expect(find.text('150000.0'), findsNothing);
    });

    testWidgets('sin saldo pendiente no hay formulario ni atajo', (
      tester,
    ) async {
      // Un ticket ya pagado del todo no ofrece cobrar nada: el atajo no puede
      // aparecer para rellenar un cero.
      await tester.pumpWidget(
        _montar(saldo: 0, pagado: 180000, estado: 'cerrado'),
      );

      expect(find.textContaining('Pagar saldo exacto'), findsNothing);
      expect(find.text('Valor del pago'), findsNothing);
      expect(find.text('Registrar pago'), findsNothing);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('una cita cancelada tampoco ofrece cobrar', (tester) async {
      // Misma regla que `AccionesDeTicket.puedeGestionarPagos` y que el
      // servidor en `register_ticket_payment` (D-163).
      await tester.pumpWidget(_montar(saldo: 150000, estado: 'cancelado'));

      expect(find.textContaining('Pagar saldo exacto'), findsNothing);
      expect(find.text('Registrar pago'), findsNothing);
    });
  });
}
