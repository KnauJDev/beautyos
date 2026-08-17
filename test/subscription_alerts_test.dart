import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/tenant_subscription_status.dart';

void main() {
  group('Lógica de Alertas y Días de Vencimiento / Gracia (Paso 3.11 / D-143)', () {
    test('Calcula correctamente días para avisos de prueba gratis (10, 5, 3 días)', () {
      final now = DateTime.now();

      // Prueba a 10 días
      final sub10 = TenantSubscriptionStatus(
        tenantId: 't-10',
        tenantName: 'Salón Diez',
        subscriptionStatus: 'trialing',
        trialEndsAt: now.add(const Duration(days: 10)),
      );
      expect(sub10.trialDaysRemaining, equals(10));

      // Prueba a 5 días
      final sub5 = TenantSubscriptionStatus(
        tenantId: 't-5',
        tenantName: 'Salón Cinco',
        subscriptionStatus: 'trialing',
        trialEndsAt: now.add(const Duration(days: 5)),
      );
      expect(sub5.trialDaysRemaining, equals(5));

      // Prueba a 3 días
      final sub3 = TenantSubscriptionStatus(
        tenantId: 't-3',
        tenantName: 'Salón Tres',
        subscriptionStatus: 'trialing',
        trialEndsAt: now.add(const Duration(days: 3)),
      );
      expect(sub3.trialDaysRemaining, equals(3));
    });

    test('Calcula correctamente cuenta regresiva de los 5 días de gracia', () {
      final now = DateTime.now();

      // Gracia Día 1 (5 días restantes)
      final subGrace5 = TenantSubscriptionStatus(
        tenantId: 't-g5',
        tenantName: 'Salón Gracia 5',
        subscriptionStatus: 'past_due',
        graceEndsAt: now.add(const Duration(days: 4, hours: 23)),
      );
      expect(subGrace5.isGrace, isTrue);
      expect(subGrace5.graceDaysRemaining, equals(5));

      // Gracia Día 3 (3 días restantes)
      final subGrace3 = TenantSubscriptionStatus(
        tenantId: 't-g3',
        tenantName: 'Salón Gracia 3',
        subscriptionStatus: 'past_due',
        graceEndsAt: now.add(const Duration(days: 2, hours: 23)),
      );
      expect(subGrace3.isGrace, isTrue);
      expect(subGrace3.graceDaysRemaining, equals(3));

      // Gracia agotada (0 días restantes / vencida)
      final subGrace0 = TenantSubscriptionStatus(
        tenantId: 't-g0',
        tenantName: 'Salón Gracia 0',
        subscriptionStatus: 'past_due',
        graceEndsAt: now.subtract(const Duration(hours: 2)),
      );
      expect(subGrace0.isGracePeriodActive, isFalse);
      expect(subGrace0.graceDaysRemaining, equals(0));
    });
  });
}
