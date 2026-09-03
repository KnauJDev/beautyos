import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/acciones_de_ticket.dart';
import 'package:salonymas/models/ticket_summary.dart';
import 'package:salonymas/pages/tickets_page.dart';
import 'package:salonymas/theme/app_theme.dart';
import 'package:salonymas/widgets/ticket_status.dart';

void main() {
  group('TicketSummary Model (Paso 4.5 / D-152)', () {
    test('Parsea correctamente campos de venta, cliente y estados', () {
      final map = {
        'id': 'a1111111-1111-1111-1111-111111111111',
        'ticket_code': '0000701',
        'sale_number': 45,
        'sale_code': 'VTA-0000045',
        'closed_at': '2026-08-18T10:00:00Z',
        'client_id': 'c1111111-1111-1111-1111-111111111111',
        'client_name': 'Camila Restrepo',
        'client_phone': '+573001234567',
        'scheduled_at': '2026-08-18T09:30:00Z',
        'status': 'cerrado',
        'channel': 'manual',
        'service_names': 'Balayage, Manicure',
        'stylist_names': 'Valentina Gómez',
        'total_price': 180000,
        'total_duration_minutes': 120,
        'paid_amount': 180000,
        'balance_amount': 0,
        'payment_status': 'pagado_total',
      };

      final ticket = TicketSummary.fromMap(map);

      expect(ticket.id, 'a1111111-1111-1111-1111-111111111111');
      expect(ticket.ticketCode, '0000701');
      expect(ticket.saleNumber, 45);
      expect(ticket.saleCode, 'VTA-0000045');
      expect(ticket.isClosed, isTrue);
      expect(ticket.hasPendingBalance, isFalse);
      expect(ticket.clientName, 'Camila Restrepo');
      expect(ticket.clientPhone, '+573001234567');
      expect(ticket.ticketStatus, TicketStatus.cerrado);
      expect(ticket.statusLabel, 'Cerrado');
      expect(ticket.formattedPrice, '\$180.000');
      expect(ticket.formattedPaidAmount, '\$180.000');
      expect(ticket.formattedBalanceAmount, '\$0');
    });

    test('Identifica saldo pendiente y estado por cobrar', () {
      final map = {
        'id': 'b2222222-2222-2222-2222-222222222222',
        'ticket_code': '0000702',
        'client_name': 'Mariana Morales',
        'client_phone': '+573009876543',
        'scheduled_at': '2026-08-18T11:00:00Z',
        'status': 'finalizado',
        'channel': 'whatsapp',
        'service_names': 'Corte y Cepillado',
        'stylist_names': 'Carlos Pérez',
        'total_price': 80000,
        'total_duration_minutes': 60,
        'paid_amount': 30000,
        'balance_amount': 50000,
        'payment_status': 'abono_parcial',
      };

      final ticket = TicketSummary.fromMap(map);

      expect(ticket.isClosed, isFalse);
      expect(ticket.hasPendingBalance, isTrue);
      expect(ticket.ticketStatus, TicketStatus.finalizado);
      expect(ticket.statusLabel, 'Finalizado');
      expect(ticket.formattedPrice, '\$80.000');
      expect(ticket.formattedPaidAmount, '\$30.000');
      expect(ticket.formattedBalanceAmount, '\$50.000');
      expect(ticket.showsPaymentInfo, isTrue);
    });
  });

  group('TicketRow Widget Tests (Nivel 2 / StatusPill / D-152)', () {
    testWidgets('Renderiza #0000701, StatusPill y WhatsApp para ticket abierto', (tester) async {
      final ticket = TicketSummary.fromMap({
        'id': 't1',
        'ticket_code': '0000701',
        'client_name': 'Lucía Santos',
        'client_phone': '+573005551234',
        'scheduled_at': '2026-08-18T14:00:00Z',
        'status': 'confirmado',
        'channel': 'manual',
        'service_names': 'Corte Dama',
        'stylist_names': 'Sara Vega',
        'total_price': 50000,
        'total_duration_minutes': 45,
        'paid_amount': 0,
        'balance_amount': 50000,
        'payment_status': 'sin_pago',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TicketRow(
              ticket: ticket,
              onChangeStatus: () {},
              onManagePayments: () {},
            ),
          ),
        ),
      );

      // Consecutivo de cita
      expect(find.text('#0000701'), findsOneWidget);
      // Nombre de cliente
      expect(find.text('Lucía Santos'), findsOneWidget);
      // StatusPill de confirmado
      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.text('Confirmado'), findsOneWidget);
      // Icono de WhatsApp
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      // No debe mostrar VTA porque no está cerrado
      expect(find.textContaining('VTA-'), findsNothing);
    });

    testWidgets('Renderiza chip dual (#0000701 + VTA-0000045) en ticket cerrado', (tester) async {
      final ticket = TicketSummary.fromMap({
        'id': 't2',
        'ticket_code': '0000702',
        'sale_number': 45,
        'sale_code': 'VTA-0000045',
        'closed_at': '2026-08-18T16:00:00Z',
        'client_name': 'Andrea Mejía',
        'client_phone': '+573007778899',
        'scheduled_at': '2026-08-18T15:00:00Z',
        'status': 'cerrado',
        'channel': 'web',
        'service_names': 'Uñas Acrílicas',
        'stylist_names': 'Ana María',
        'total_price': 120000,
        'total_duration_minutes': 90,
        'paid_amount': 120000,
        'balance_amount': 0,
        'payment_status': 'pagado_total',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TicketRow(
              ticket: ticket,
              onChangeStatus: null,
              onManagePayments: () {},
            ),
          ),
        ),
      );

      // Chip Cita
      expect(find.text('#0000702'), findsOneWidget);
      // Chip Venta
      expect(find.text('VTA-0000045'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_outlined), findsOneWidget);
      // StatusPill cerrado
      expect(find.byType(StatusPill), findsOneWidget);
      expect(find.text('Cerrado'), findsOneWidget);
    });
  });

  group('C-02 — TicketRow solo pide lo que de verdad pinta (D-200)', () {
    TicketSummary ticketEn(String estado) {
      return TicketSummary.fromMap({
        'id': 't3',
        'ticket_code': '0000703',
        'client_name': 'Paula Rincón',
        'client_phone': '+573001234567',
        'scheduled_at': '2026-09-02T10:00:00Z',
        'status': estado,
        'channel': 'manual',
        'service_names': 'Manicure',
        'stylist_names': 'Sara Duque',
        'total_price': 60000,
        'total_duration_minutes': 45,
        'paid_amount': 0,
        'balance_amount': 60000,
        'payment_status': 'sin_pago',
      });
    }

    Widget montar(TicketSummary ticket, {
      VoidCallback? onChangeStatus,
      VoidCallback? onManagePayments,
    }) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TicketRow(
            ticket: ticket,
            onChangeStatus: onChangeStatus,
            onManagePayments: onManagePayments,
          ),
        ),
      );
    }

    test('agregar servicios implica poder cobrar', () {
      // **Esta es la prueba que sostiene el cambio.** La barra de acciones
      // se mostraba con `onManagePayments != null || onChangeStatus != null
      // || onAddService != null`, y el tercer término se retiró por ser
      // redundante: los estados que admiten agregar servicios son un
      // subconjunto de los que admiten cobrar. Si esa relación dejara de
      // cumplirse, la barra desaparecería en silencio para algún estado.
      const estados = [
        'solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera',
        'en_proceso', 'finalizado', 'cerrado', 'cancelado', 'no_asistio',
      ];

      for (final estado in estados) {
        if (!AccionesDeTicket.puedeAgregarServicios(estado)) continue;

        expect(
          AccionesDeTicket.puedeGestionarPagos(estado),
          isTrue,
          reason:
              'En "$estado" se pueden agregar servicios pero no cobrar. La '
              'barra de acciones de TicketRow dejaría de verse para ese '
              'estado: hay que devolverle su propia condición.',
        );
      }
    });

    testWidgets('con pagos y cambio de estado se ven los tres botones', (
      tester,
    ) async {
      await tester.pumpWidget(
        montar(
          ticketEn('confirmado'),
          onChangeStatus: () {},
          onManagePayments: () {},
        ),
      );

      expect(find.text('Ver ficha'), findsOneWidget);
      expect(find.text('Pagos y saldo'), findsOneWidget);
      expect(find.text('Estado'), findsOneWidget);
    });

    testWidgets('una cita cancelada no enseña barra de acciones', (
      tester,
    ) async {
      // `cancelado` no admite cobro ni cambio de estado, así que los dos
      // callbacks llegan nulos y la barra entera desaparece -- igual que
      // antes de retirar el término sobrante de la condición.
      await tester.pumpWidget(montar(ticketEn('cancelado')));

      expect(find.text('Ver ficha'), findsNothing);
      expect(find.text('Pagos y saldo'), findsNothing);
      expect(find.text('Estado'), findsNothing);
      // La tarjeta sigue ahí: lo que desaparece es la barra, no el ticket.
      expect(find.text('#0000703'), findsOneWidget);
    });

    testWidgets('un ticket cerrado cobra pero ya no cambia de estado', (
      tester,
    ) async {
      await tester.pumpWidget(
        montar(ticketEn('cerrado'), onManagePayments: () {}),
      );

      expect(find.text('Ver pagos'), findsOneWidget);
      expect(find.text('Estado'), findsNothing);
    });
  });
}
