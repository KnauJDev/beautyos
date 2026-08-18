import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_summary.dart';
import 'package:salonymas/pages/clients_page.dart';
import 'package:salonymas/theme/app_theme.dart';

void main() {
  group('ClientSummary Model - Métricas RFM y Cadencia (Paso 4.6 / D-153)', () {
    test('Parsea métricas completas de cliente VIP recurrente', () {
      final map = {
        'id': 'c1111111-1111-1111-1111-111111111111',
        'name': 'Camila Restrepo Gómez',
        'phone': '+573001234567',
        'email': 'camila@gmail.com',
        'notes': 'Prefiere tinte sin amoniaco',
        'active': true,
        'created_at': '2026-06-01T10:00:00Z',
        'balance_amount': 0,
        'total_visits': 4,
        'total_spent': 320000,
        'average_ticket': 80000,
        'first_visit_at': '2026-06-10T10:00:00Z',
        'last_visit_at': '2026-08-10T10:00:00Z',
        'days_since_last_visit': 8,
        'avg_days_between_visits': 20,
        'segment': 'vip',
      };

      final client = ClientSummary.fromMap(map);

      expect(client.id, 'c1111111-1111-1111-1111-111111111111');
      expect(client.name, 'Camila Restrepo Gómez');
      expect(client.firstName, 'Camila');
      expect(client.phone, '+573001234567');
      expect(client.email, 'camila@gmail.com');
      expect(client.totalVisits, 4);
      expect(client.totalSpent, 320000);
      expect(client.averageTicket, 80000);
      expect(client.formattedTotalSpent, '\$320.000');
      expect(client.formattedAverageTicket, '\$80.000');
      expect(client.hasPendingBalance, isFalse);
      expect(client.daysSinceLastVisit, 8);
      expect(client.avgDaysBetweenVisits, 20);
      expect(client.cadenceText, 'Cada ~20 días');
      expect(client.lastVisitText, 'Hace 8 días');
      expect(client.segment, 'vip');
      expect(client.segmentLabel, '⭐ VIP');
    });

    test('Helper firstName extrae solo el primer término o maneja nombres compuestos', () {
      final c1 = ClientSummary.fromMap({'name': 'Andrea'});
      final c2 = ClientSummary.fromMap({'name': 'Dra. Patricia Salazar'});
      final c3 = ClientSummary.fromMap({'name': '   '});

      expect(c1.firstName, 'Andrea');
      expect(c2.firstName, 'Dra.');
      expect(c3.firstName, 'Cliente');
    });

    test('Identifica cliente en riesgo de abandono y con saldo pendiente', () {
      final map = {
        'id': 'c2222222-2222-2222-2222-222222222222',
        'name': 'Marcela Torres',
        'phone': '+573009998877',
        'active': true,
        'created_at': '2026-05-01T10:00:00Z',
        'balance_amount': 45000,
        'total_visits': 2,
        'total_spent': 150000,
        'average_ticket': 75000,
        'first_visit_at': '2026-05-10T10:00:00Z',
        'last_visit_at': '2026-06-15T10:00:00Z',
        'days_since_last_visit': 64,
        'avg_days_between_visits': 36,
        'segment': 'en_riesgo',
      };

      final client = ClientSummary.fromMap(map);

      expect(client.firstName, 'Marcela');
      expect(client.hasPendingBalance, isTrue);
      expect(client.formattedBalanceAmount, '\$45.000');
      expect(client.segment, 'en_riesgo');
      expect(client.segmentLabel, '⚠️ En riesgo');
      expect(client.cadenceText, 'Cada ~36 días');
      expect(client.lastVisitText, 'Hace 64 días');
    });

    test('Maneja correctamente cliente nuevo de primera visita', () {
      final map = {
        'id': 'c3333333-3333-3333-3333-333333333333',
        'name': 'Laura Díaz',
        'phone': '+573005554433',
        'active': true,
        'created_at': '2026-08-17T10:00:00Z',
        'balance_amount': 0,
        'total_visits': 1,
        'total_spent': 60000,
        'average_ticket': 60000,
        'first_visit_at': '2026-08-17T10:00:00Z',
        'last_visit_at': '2026-08-17T10:00:00Z',
        'days_since_last_visit': 1,
        'avg_days_between_visits': null,
        'segment': 'nuevo',
      };

      final client = ClientSummary.fromMap(map);

      expect(client.totalVisits, 1);
      expect(client.cadenceText, '1ª visita');
      expect(client.lastVisitText, 'Ayer');
      expect(client.segmentLabel, '🆕 Nuevo');
    });
  });

  group('ClientRow Widget Tests (Nivel 2 / RFM)', () {
    testWidgets('Renderiza iniciales, nombre, badge VIP, cadencia y WhatsApp', (tester) async {
      final client = ClientSummary.fromMap({
        'id': 'c1',
        'name': 'Valentina Gómez',
        'phone': '+573001112233',
        'email': 'vale@gmail.com',
        'active': true,
        'total_visits': 5,
        'total_spent': 400000,
        'average_ticket': 80000,
        'days_since_last_visit': 3,
        'avg_days_between_visits': 15,
        'segment': 'vip',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ClientRow(
              client: client,
              onEdit: () {},
            ),
          ),
        ),
      );

      // Nombre e iniciales
      expect(find.text('Valentina Gómez'), findsOneWidget);
      expect(find.text('VG'), findsOneWidget);
      // Badge VIP
      expect(find.text('⭐ VIP'), findsOneWidget);
      // Cadencia y visitas
      expect(find.text('5 visitas'), findsOneWidget);
      expect(find.text('Gasto: \$400.000'), findsOneWidget);
      expect(find.text('Cada ~15 días'), findsOneWidget);
      // WhatsApp
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('Renderiza cliente en riesgo con saldo en mora', (tester) async {
      final client = ClientSummary.fromMap({
        'id': 'c2',
        'name': 'Sara Castro',
        'phone': '+573004445566',
        'active': true,
        'balance_amount': 50000,
        'total_visits': 2,
        'total_spent': 120000,
        'average_ticket': 60000,
        'days_since_last_visit': 50,
        'avg_days_between_visits': 25,
        'segment': 'en_riesgo',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ClientRow(
              client: client,
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sara Castro'), findsOneWidget);
      expect(find.text('SC'), findsOneWidget);
      expect(find.text('⚠️ En riesgo'), findsOneWidget);
      expect(find.text('Debe: \$50.000'), findsOneWidget);
    });
  });
}
