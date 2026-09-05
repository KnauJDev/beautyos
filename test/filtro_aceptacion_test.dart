import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/platform_tenant_summary.dart';
import 'package:salonymas/models/tenant_subscription_status.dart';
import 'package:salonymas/services/tenant_registration_service.dart';

void main() {
  group('Paso 3.7 — Filtro de Aceptación (Modelos y Estado)', () {
    test('TenantSubscriptionStatus interpreta correctamente los estados del negocio', () {
      final pendingMap = {
        'tenant_id': '11111111-1111-1111-1111-111111111111',
        'tenant_name': 'Spa Uñas Glamour',
        'subscription_status': 'pending',
        'plan_code': 'profesional',
        'is_founder': false,
        'trial_ends_at': null,
      };

      final pendingStatus = TenantSubscriptionStatus.fromMap(pendingMap);
      expect(pendingStatus.isPending, isTrue);
      expect(pendingStatus.isTrialing, isFalse);
      expect(pendingStatus.isActive, isFalse);
      expect(pendingStatus.isRejected, isFalse);
      expect(pendingStatus.trialDaysRemaining, isNull);

      final trialingMap = {
        'tenant_id': '22222222-2222-2222-2222-222222222222',
        'tenant_name': 'Barbería Élite',
        'subscription_status': 'trialing',
        'plan_code': 'business',
        'is_founder': true,
        'trial_ends_at': DateTime.now().add(const Duration(days: 21)).toIso8601String(),
      };

      final trialingStatus = TenantSubscriptionStatus.fromMap(trialingMap);
      expect(trialingStatus.isPending, isFalse);
      expect(trialingStatus.isTrialing, isTrue);
      expect(trialingStatus.isFounder, isTrue);
      expect(trialingStatus.trialDaysRemaining, inInclusiveRange(20, 21));

      final rejectedMap = {
        'tenant_id': '33333333-3333-3333-3333-333333333333',
        'tenant_name': 'Centro Estética',
        'subscription_status': 'rejected',
        'rejection_reason': 'No cumple con requisitos del piloto.',
      };

      final rejectedStatus = TenantSubscriptionStatus.fromMap(rejectedMap);
      expect(rejectedStatus.isRejected, isTrue);
      expect(rejectedStatus.rejectionReason, equals('No cumple con requisitos del piloto.'));
    });

    test('PlatformTenantSummary mapea datos del cuestionario y estados', () {
      final summaryMap = {
        'tenant_id': '44444444-4444-4444-4444-444444444444',
        'tenant_name': 'Estética Canina Guau',
        'business_type': 'canina',
        'city': 'Medellín',
        'estimated_branches': 2,
        'estimated_team_size': 5,
        'referral_source': 'Instagram',
        'contact_email': 'contacto@guau.com',
        'whatsapp': '3101234567',
        'tenant_active': true,
        'is_demo': false,
        'plan_code': 'profesional',
        'subscription_status': 'pending',
        'is_founder': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final summary = PlatformTenantSummary.fromMap(summaryMap);
      expect(summary.isPending, isTrue);
      expect(summary.city, equals('Medellín'));
      expect(summary.businessType, equals('canina'));
      expect(summary.estimatedBranches, equals(2));
      expect(summary.estimatedTeamSize, equals(5));
      expect(summary.referralSource, equals('Instagram'));
    });

    test('TenantRegistrationResult interpreta status pending', () {
      final resultMap = {
        'tenant_id': '55555555-5555-5555-5555-555555555555',
        'branch_id': '66666666-6666-6666-6666-666666666666',
        'status': 'pending',
      };

      final result = TenantRegistrationResult.fromMap(resultMap);
      expect(result.status, equals('pending'));
    });

    test('TenantSubscriptionStatus y PlatformTenantSummary detectan pruebas vencidas (D-212)', () {
      final expiredDate = DateTime.now().subtract(const Duration(days: 5));
      final activeDate = DateTime.now().add(const Duration(days: 10));

      final subExpired = TenantSubscriptionStatus.fromMap({
        'tenant_id': '111',
        'tenant_name': 'Prueba Barberia Elite',
        'subscription_status': 'trialing',
        'trial_ends_at': expiredDate.toIso8601String(),
      });
      expect(subExpired.isTrialing, isTrue);
      expect(subExpired.isTrialExpired, isTrue);
      expect(subExpired.isTrialActive, isFalse);
      expect(subExpired.statusLabel, equals('Prueba Vencida'));

      final subActive = TenantSubscriptionStatus.fromMap({
        'tenant_id': '222',
        'tenant_name': 'Barberia Activa',
        'subscription_status': 'trialing',
        'trial_ends_at': activeDate.toIso8601String(),
      });
      expect(subActive.isTrialing, isTrue);
      expect(subActive.isTrialExpired, isFalse);
      expect(subActive.isTrialActive, isTrue);
      expect(subActive.statusLabel, equals('Prueba Gratis'));

      final platformSummaryExpired = PlatformTenantSummary.fromMap({
        'tenant_id': '111',
        'tenant_name': 'Prueba Barberia Elite',
        'contact_email': 'test@elite.com',
        'whatsapp': '3001234567',
        'tenant_active': true,
        'is_demo': false,
        'plan_code': 'pro',
        'subscription_status': 'trialing',
        'trial_ends_at': expiredDate.toIso8601String(),
      });
      expect(platformSummaryExpired.isTrialing, isTrue);
      expect(platformSummaryExpired.isTrialExpired, isTrue);
      expect(platformSummaryExpired.isTrialActive, isFalse);
      expect(platformSummaryExpired.planNameFormatted, equals('Todo Incluido'));
    });
  });
}
