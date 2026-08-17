import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/public_plan.dart';
import 'package:salonymas/services/public_plans_service.dart';

void main() {
  group('PublicPlan & PublicPlanFeature Models', () {
    test('PublicPlan.fromRows agrupa correctamente las filas planas de la RPC', () {
      final sampleRows = [
        {
          'plan_code': 'basico',
          'plan_name': 'Básico',
          'billing_period': 'monthly',
          'price_cop': 160000,
          'currency_code': 'COP',
          'feature_key': 'branches',
          'feature_name': 'Sedes',
          'feature_enabled': true,
          'feature_limit': 1,
        },
        {
          'plan_code': 'basico',
          'plan_name': 'Básico',
          'billing_period': 'monthly',
          'price_cop': 160000,
          'currency_code': 'COP',
          'feature_key': 'team_members',
          'feature_name': 'Cuentas de equipo',
          'feature_enabled': true,
          'feature_limit': 5,
        },
        {
          'plan_code': 'business',
          'plan_name': 'Business',
          'billing_period': 'monthly',
          'price_cop': 200000,
          'currency_code': 'COP',
          'feature_key': 'branches',
          'feature_name': 'Sedes',
          'feature_enabled': true,
          'feature_limit': 3,
        },
        {
          'plan_code': 'business',
          'plan_name': 'Business',
          'billing_period': 'monthly',
          'price_cop': 200000,
          'currency_code': 'COP',
          'feature_key': 'inventory',
          'feature_name': 'Inventario, compras y gastos',
          'feature_enabled': true,
          'feature_limit': null,
        },
        {
          'plan_code': 'profesional',
          'plan_name': 'Profesional',
          'billing_period': 'monthly',
          'price_cop': 240000,
          'currency_code': 'COP',
          'feature_key': 'branches',
          'feature_name': 'Sedes',
          'feature_enabled': true,
          'feature_limit': null,
        },
        {
          'plan_code': 'profesional',
          'plan_name': 'Profesional',
          'billing_period': 'monthly',
          'price_cop': 240000,
          'currency_code': 'COP',
          'feature_key': 'portfolio',
          'feature_name': 'Fotos de trabajos',
          'feature_enabled': true,
          'feature_limit': null,
        },
      ];

      final plans = PublicPlan.fromRows(sampleRows);

      expect(plans.length, 3);

      // Básico
      final basico = plans[0];
      expect(basico.code, 'basico');
      expect(basico.name, 'Básico');
      expect(basico.priceCop, 160000);
      expect(basico.formattedPrice, '\$160.000');
      expect(basico.periodLabel, 'mes');
      expect(basico.branchesLabel, '1 Sede principal');
      expect(basico.teamMembersLabel, 'Hasta 5 cuentas de equipo');
      expect(basico.isPopular, false);
      expect(basico.isElite, false);
      expect(basico.hasFeature('branches'), true);
      expect(basico.hasFeature('inventory'), false);

      // Business
      final business = plans[1];
      expect(business.code, 'business');
      expect(business.name, 'Business');
      expect(business.priceCop, 200000);
      expect(business.formattedPrice, '\$200.000');
      expect(business.branchesLabel, 'Hasta 3 sedes');
      expect(business.isPopular, true);
      expect(business.isElite, false);
      expect(business.hasFeature('inventory'), true);

      // Profesional
      final profesional = plans[2];
      expect(profesional.code, 'profesional');
      expect(profesional.name, 'Profesional');
      expect(profesional.priceCop, 240000);
      expect(profesional.formattedPrice, '\$240.000');
      expect(profesional.branchesLabel, 'Sedes ilimitadas');
      expect(profesional.isPopular, false);
      expect(profesional.isElite, true);
      expect(profesional.hasFeature('portfolio'), true);
    });

    test('PublicPlansService.fallbackPlans contiene los 3 planes con límites exactos D-124 y D-136', () {
      final fallback = PublicPlansService.fallbackPlans;
      expect(fallback.length, 3);

      final basico = fallback.firstWhere((p) => p.code == 'basico');
      expect(basico.priceCop, 160000);
      expect(basico.branchesLabel, '1 Sede principal');
      expect(basico.teamMembersLabel, 'Hasta 5 cuentas de equipo');

      final business = fallback.firstWhere((p) => p.code == 'business');
      expect(business.priceCop, 200000);
      expect(business.branchesLabel, 'Hasta 3 sedes');
      expect(business.teamMembersLabel, 'Hasta 15 cuentas de equipo');

      final profesional = fallback.firstWhere((p) => p.code == 'profesional');
      expect(profesional.priceCop, 240000);
      expect(profesional.branchesLabel, 'Sedes ilimitadas');
      expect(profesional.teamMembersLabel, 'Equipo ilimitado');
    });
  });
}
