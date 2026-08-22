import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/main.dart';
import 'package:salonymas/models/platform_tenant_summary.dart';
import 'package:salonymas/theme/app_theme.dart';

void main() {
  group('BeautyCategory & BeautySection Tests', () {
    test('Las 4 categorías semánticas existen con sus etiquetas', () {
      expect(BeautyCategory.operacion.label, 'OPERACIÓN');
      expect(BeautyCategory.finanzas.label, 'FINANZAS Y GESTIÓN');
      expect(BeautyCategory.portafolio.label, 'PORTAFOLIO');
      expect(BeautyCategory.sistema.label, 'CATÁLOGO Y AJUSTES');
    });

    test('BeautySection guarda título, icono y categoría por defecto o asignada', () {
      const sectionOp = BeautySection('Agenda', Icons.calendar_month_outlined);
      expect(sectionOp.title, 'Agenda');
      expect(sectionOp.category, BeautyCategory.operacion);

      const sectionFin = BeautySection(
        'Dashboard',
        Icons.dashboard_outlined,
        category: BeautyCategory.finanzas,
      );
      expect(sectionFin.title, 'Dashboard');
      expect(sectionFin.category, BeautyCategory.finanzas);
    });
  });

  group('Modern Shell & Navigation Widget Tests', () {
    testWidgets('Sidebar categorizado agrupa y renderiza secciones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                Container(
                  width: 240,
                  color: AppColors.surface,
                  child: ListView(
                    children: const [
                      Text('OPERACIÓN'),
                      Text('Agenda'),
                      Text('Tickets & Caja'),
                      Text('FINANZAS Y GESTIÓN'),
                      Text('Dashboard'),
                      Text('PORTAFOLIO'),
                      Text('Fotos'),
                      Text('CATÁLOGO Y AJUSTES'),
                      Text('Configuración'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('OPERACIÓN'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Tickets & Caja'), findsOneWidget);
      expect(find.text('FINANZAS Y GESTIÓN'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('PORTAFOLIO'), findsOneWidget);
      expect(find.text('Fotos'), findsOneWidget);
      expect(find.text('CATÁLOGO Y AJUSTES'), findsOneWidget);
      expect(find.text('Configuración'), findsOneWidget);
    });
  });

  group('PlatformTenantSummary Model & Pricing Tests (Paso 4.11 / D-158)', () {
    test('Calcula precio efectivo con 50% Pionero correctamente', () {
      final summaryFounder = PlatformTenantSummary(
        tenantId: '11111111-1111-1111-1111-111111111111',
        tenantName: 'Naguara de Uñas',
        contactEmail: 'naguara@gmail.com',
        whatsapp: '3197364923',
        tenantActive: true,
        isDemo: false,
        planCode: 'basico',
        subscriptionStatus: 'active',
        isFounder: true,
        trialEndsAt: null,
        currentPeriodEnd: DateTime(2026, 9, 15),
        graceEndsAt: null,
        createdAt: DateTime(2026, 8, 1),
      );

      // Básico $160.000 con 50% = $80.000
      expect(summaryFounder.effectivePriceCop, 80000);
      expect(summaryFounder.formattedEffectivePrice, '\$80.000 COP/mes');
      expect(summaryFounder.planNameFormatted, 'Básico');
    });

    test('Respeta precio personalizado fijo guardado en BD', () {
      final summaryCustom = PlatformTenantSummary(
        tenantId: '22222222-2222-2222-2222-222222222222',
        tenantName: 'Barbería Élite',
        contactEmail: 'elite@gmail.com',
        whatsapp: '3211234567',
        tenantActive: true,
        isDemo: false,
        planCode: 'profesional',
        subscriptionStatus: 'trialing',
        isFounder: false,
        priceCop: 60000,
        trialEndsAt: DateTime(2026, 8, 23),
        currentPeriodEnd: null,
        graceEndsAt: null,
        createdAt: DateTime(2026, 8, 15),
      );

      expect(summaryCustom.effectivePriceCop, 60000);
      expect(summaryCustom.formattedEffectivePrice, '\$60.000 COP/mes');
      expect(summaryCustom.isTrialing, true);
    });
  });
}
