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

    test('El catálogo de respaldo es UN SOLO plan Todo Incluido (D-188)', () {
      final fallback = PublicPlansService.fallbackPlans;

      // D-188 retiró la escalera de tres (D-124, D-136): el eje de cobro dejó
      // de ser qué módulos te dejo usar y pasó a ser cuántas sedes tienes.
      expect(fallback.length, 1);

      final pro = fallback.single;
      expect(pro.code, 'pro');
      expect(pro.name, 'Todo Incluido');
      expect(pro.priceCop, 150000);
      expect(pro.branchesLabel, 'Sedes ilimitadas');
      expect(pro.teamMembersLabel, isNotEmpty);
    });

    test('El respaldo trae todo incluido, salvo lo que no existe', () {
      final pro = PublicPlansService.fallbackPlans.single;

      bool incluye(String clave) =>
          pro.features.firstWhere((f) => f.key == clave).enabled;

      for (final clave in const [
        'inventory',
        'financial_reports',
        'portfolio',
        'reviews',
      ]) {
        expect(incluye(clave), true, reason: '$clave debería venir incluida');
      }

      // Fase 6, sin construir. El Plan Maestro prohíbe expresamente venderla
      // antes de que exista, y este respaldo es lo que ve el visitante cuando
      // la RPC no responde: si mintiera aquí, mentiría justo al fallar la red.
      expect(incluye('social_publishing'), false);
    });

    test('El precio de lista da 5.000 al día exactos (D-189)', () {
      final lista = PublicPlansService.fallbackPlans.single.priceCop;

      // El argumento de venta es "$5.000 al día". Si el precio dejara de ser
      // divisible por 30, la frase pasaría a ser mentira y nadie se enteraría.
      expect(lista, 150000);
      expect(lista % 30, 0);
      expect(lista ~/ 30, 5000);
    });

    test('Caben 10 personas: 9 cuentas de equipo más el dueño (D-189)', () {
      // El propietario NO cuenta contra el tope: lo dejó escrito D-136 al
      // construir create_team_invitation. Por eso el límite es 9 y no 10.
      expect(PublicPlansService.personasIncluidas, 10);

      final equipo = PublicPlansService.fallbackPlans.single.features
          .firstWhere((f) => f.key == 'team_members');
      expect(equipo.enabled, true);
      expect(equipo.limitValue, 9);
    });
  });
}
