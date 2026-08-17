import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/tenant_subscription_status.dart';
import 'package:salonymas/services/epayco_checkout_service.dart';

void main() {
  group('TenantSubscriptionStatus - Modelo y Periodo de Gracia (D-141)', () {
    test('Mapea correctamente estados de gracia y cálculo de días restantes', () {
      final now = DateTime.now();
      final in3Days = now.add(const Duration(days: 3, hours: 2));

      final sub = TenantSubscriptionStatus.fromMap({
        'tenant_id': '550e8400-e29b-41d4-a716-446655440000',
        'tenant_name': 'Barbería Élite',
        'subscription_status': 'past_due',
        'plan_code': 'profesional',
        'plan_name': 'Profesional',
        'price_cop': 240000,
        'grace_ends_at': in3Days.toIso8601String(),
        'is_founder': false,
      });

      expect(sub.isPastDue, isTrue);
      expect(sub.isGrace, isTrue);
      expect(sub.isGracePeriodActive, isTrue);
      expect(sub.graceDaysRemaining, equals(4)); // 3 días y 2 horas redondea hacia arriba a 4
      expect(sub.statusLabel, equals('Periodo de Gracia'));
      expect(sub.formattedPrice, equals('\$240.000 COP / mes'));
    });

    test('Mapea descuento de Pionero 50% y estado activo con fechas de periodo', () {
      final now = DateTime.now();
      final periodEnd = now.add(const Duration(days: 20));

      final sub = TenantSubscriptionStatus.fromMap({
        'tenant_id': '660e8400-e29b-41d4-a716-446655440001',
        'tenant_name': 'Spa Divas',
        'subscription_status': 'active',
        'plan_code': 'profesional',
        'plan_name': 'Profesional',
        'price_cop': 120000,
        'discount_percent': 50,
        'is_founder': true,
        'current_period_start': now.toIso8601String(),
        'current_period_end': periodEnd.toIso8601String(),
      });

      expect(sub.isActive, isTrue);
      expect(sub.isFounder, isTrue);
      expect(sub.formattedPrice, equals('\$120.000 COP / mes'));
      expect(sub.periodDaysRemaining, equals(20));
      expect(sub.statusLabel, equals('Suscripción Activa'));
    });
  });

  group('EpaycoCheckoutService - Construcción de Checkout Seguro', () {
    const service = EpaycoCheckoutService();

    test('buildCheckoutUri construye la URL parametrizada para ePayco con tenant_id y sin secretos', () {
      final sub = TenantSubscriptionStatus(
        tenantId: 'tenant-uuid-1234',
        tenantName: 'Peluquería Glamour',
        subscriptionStatus: 'trialing',
        planCode: 'business',
        planName: 'Business',
        priceCop: 200000,
        isFounder: false,
      );

      final uri = service.buildCheckoutUri(sub, isTest: true);

      expect(uri.host, equals('checkout.epayco.co'));
      expect(uri.path, equals('/checkout.php'));
      expect(uri.queryParameters['x_amount'], equals('200000'));
      expect(uri.queryParameters['x_currency_code'], equals('COP'));
      expect(uri.queryParameters['x_extra1'], equals('tenant-uuid-1234'));
      expect(uri.queryParameters['x_extra2'], equals('business'));
      expect(uri.queryParameters['x_confirmation_url'], contains('epayco-webhook'));
      expect(uri.queryParameters.containsKey('p_key'), isTrue);
      // Nunca debe contener firma o llave privada en la URL del cliente
      expect(uri.queryParameters.containsKey('x_signature'), isFalse);
      expect(uri.queryParameters.containsKey('private_key'), isFalse);
    });
  });
}
