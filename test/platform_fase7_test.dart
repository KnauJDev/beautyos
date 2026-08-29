import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/platform_saas_metrics.dart';
import 'package:salonymas/models/platform_tenant_feature_override.dart';
import 'package:salonymas/models/platform_tenant_summary.dart';

Map<String, dynamic> _baseTenantMap() => {
  'tenant_id': 't1',
  'tenant_name': 'Salón de Prueba',
  'contact_email': 'a@b.com',
  'whatsapp': '3000000000',
  'tenant_active': true,
  'is_demo': false,
  'plan_code': 'profesional',
  'subscription_status': 'active',
  'trial_ends_at': null,
  'current_period_end': null,
  'grace_ends_at': null,
  'created_at': null,
};

void main() {
  group('PlatformSaasMetrics.fromMap (D-172)', () {
    test('mapea los siete campos de la cabecera ejecutiva', () {
      final metrics = PlatformSaasMetrics.fromMap({
        'mrr_cop': 720000,
        'total_collected_cop': 2160000,
        'active_count': 3,
        'trialing_count': 2,
        'past_due_count': 1,
        'cancelled_count': 0,
        'conversion_rate_percent': 33.3,
      });

      expect(metrics.mrrCop, 720000);
      expect(metrics.totalCollectedCop, 2160000);
      expect(metrics.activeCount, 3);
      expect(metrics.trialingCount, 2);
      expect(metrics.pastDueCount, 1);
      expect(metrics.cancelledCount, 0);
      expect(metrics.conversionRatePercent, 33.3);
    });

    test('formattedMrr y formattedTotalCollected separan miles con puntos', () {
      final metrics = PlatformSaasMetrics.fromMap({
        'mrr_cop': 1240000,
        'total_collected_cop': 3720000,
      });

      expect(metrics.formattedMrr, '1.240.000');
      expect(metrics.formattedTotalCollected, '3.720.000');
    });

    test('formattedConversionRate muestra un decimal con símbolo de porcentaje', () {
      final metrics = PlatformSaasMetrics.fromMap({
        'conversion_rate_percent': 50,
      });

      expect(metrics.formattedConversionRate, '50.0%');
    });

    test('PlatformSaasMetrics.empty no revienta con campos vacíos', () {
      expect(PlatformSaasMetrics.empty.mrrCop, 0);
      expect(PlatformSaasMetrics.empty.formattedConversionRate, '0.0%');
    });
  });

  group('PlatformTenantFeatureOverride.fromMap (D-172)', () {
    test('mapea una excepción activa de sedes', () {
      final override = PlatformTenantFeatureOverride.fromMap({
        'override_id': 'o1',
        'feature_key': 'branches',
        'feature_name': 'Sedes',
        'feature_description': 'Cuantas sedes puede tener el negocio.',
        'enabled': true,
        'limit_value': 3,
        'reason': 'Trato especial acordado en llamada',
        'starts_at': '2026-08-29T10:00:00Z',
        'ends_at': null,
        'created_at': '2026-08-29T10:00:00Z',
        'is_active': true,
      });

      expect(override.featureKey, 'branches');
      expect(override.limitValue, 3);
      expect(override.reason, 'Trato especial acordado en llamada');
      expect(override.isActive, isTrue);
      expect(override.endsAt, isNull);
    });

    test('una excepción revocada llega con is_active en falso', () {
      final override = PlatformTenantFeatureOverride.fromMap({
        'override_id': 'o2',
        'feature_key': 'team_members',
        'feature_name': 'Cuentas de equipo',
        'enabled': true,
        'limit_value': 10,
        'reason': 'Prueba',
        'starts_at': '2026-08-01T10:00:00Z',
        'ends_at': '2026-08-20T10:00:00Z',
        'created_at': '2026-08-01T10:00:00Z',
        'is_active': false,
      });

      expect(override.isActive, isFalse);
      expect(override.endsAt, isNotNull);
    });

    test('sin límite numérico, limit_value queda nulo (D-136: nulo = sin límite)', () {
      final override = PlatformTenantFeatureOverride.fromMap({
        'override_id': 'o3',
        'feature_key': 'branches',
        'feature_name': 'Sedes',
        'enabled': true,
        'limit_value': null,
        'reason': 'Sin tope',
        'starts_at': '2026-08-01T10:00:00Z',
        'created_at': '2026-08-01T10:00:00Z',
        'is_active': true,
      });

      expect(override.limitValue, isNull);
    });
  });

  group('PlatformTenantSummary -- nuevos campos financieros (D-172)', () {
    test('mapea períodos pagados, LTV, precio efectivo y mora', () {
      final map = _baseTenantMap();
      map['paid_periods_count'] = 3;
      map['total_paid_cop'] = 720000;
      map['effective_monthly_price'] = 240000;
      map['debt_status'] = 'al_dia';
      map['debt_amount_cop'] = 0;
      map['active_overrides_count'] = 1;

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.paidPeriodsCount, 3);
      expect(tenant.totalPaidCop, 720000);
      expect(tenant.effectiveMonthlyPrice, 240000);
      expect(tenant.debtStatus, 'al_dia');
      expect(tenant.debtAmountCop, 0);
      expect(tenant.activeOverridesCount, 1);
      expect(tenant.isInDebt, isFalse);
    });

    test('isInDebt es verdadero solo cuando debt_status es en_mora', () {
      final map = _baseTenantMap();
      map['debt_status'] = 'en_mora';
      map['debt_amount_cop'] = 150000;

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.isInDebt, isTrue);
      expect(tenant.formattedDebtAmount, '\$150.000 COP');
    });

    test('un tenant en prueba no está en mora', () {
      final map = _baseTenantMap();
      map['debt_status'] = 'en_prueba';

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.isInDebt, isFalse);
    });

    test('campos financieros ausentes en el mapa quedan en cero, no null', () {
      final tenant = PlatformTenantSummary.fromMap(_baseTenantMap());

      expect(tenant.paidPeriodsCount, 0);
      expect(tenant.totalPaidCop, 0);
      expect(tenant.effectiveMonthlyPrice, 0);
      expect(tenant.activeOverridesCount, 0);
      expect(tenant.debtStatus, isNull);
    });

    test('formattedTotalPaid separa miles con puntos', () {
      final map = _baseTenantMap();
      map['total_paid_cop'] = 2160000;

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.formattedTotalPaid, '\$2.160.000 COP');
    });

    test('ageLabel dice "Registrado hoy" para un tenant creado ahora mismo', () {
      final map = _baseTenantMap();
      map['created_at'] = DateTime.now().toIso8601String();

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.ageLabel, 'Registrado hoy');
    });

    test('ageLabel cuenta en días bajo un mes', () {
      final map = _baseTenantMap();
      map['created_at'] = DateTime.now()
          .subtract(const Duration(days: 18))
          .toIso8601String();

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.ageLabel, 'Registrado hace 18 días');
    });

    test('ageLabel pasa a meses después de 30 días', () {
      final map = _baseTenantMap();
      map['created_at'] = DateTime.now()
          .subtract(const Duration(days: 65))
          .toIso8601String();

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.ageLabel, 'Registrado hace 2 meses');
    });

    test('ageLabel sin fecha de registro no revienta', () {
      final tenant = PlatformTenantSummary.fromMap(_baseTenantMap());

      expect(tenant.ageLabel, 'Fecha de registro desconocida');
    });
  });
}
