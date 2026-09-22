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

  /// **Reescrito el 22-sep por el hallazgo AG, y conviene leer por qué.**
  ///
  /// Estas dos pruebas nacieron con el paso 4.11 (D-158) y afirmaban que el
  /// modelo **calculaba** el precio aquí: plan `basico` a $160.000, un pionero
  /// llevándose el 50%, y un precio pactado ganándole al descuento.
  ///
  /// Después pasaron dos cosas y ninguna las tocó:
  ///
  /// * **D-188 (01-sep)** jubiló `basico`, `business` y `profesional`. La base
  ///   los marca `retired`; el único activo es `pro`.
  /// * **D-221 (07-sep)** quitó del servidor el 50% del pionero — *"el pionero
  ///   es una etiqueta, no un 50%"* — y nació el control 207 para vigilarlo.
  ///
  /// **Siguieron en verde, y eso fue el problema:** mantenían sujeto en la
  /// aplicación justo lo que se había quitado del servidor. Un panel podía
  /// enseñar $80.000 mientras la factura decía $150.000, y ninguna prueba
  /// protestaba porque la prueba era cómplice.
  ///
  /// Ahora el precio **lo dice el servidor** y estas comprobaciones vigilan lo
  /// contrario de lo que vigilaban: que aquí no se calcule nada.
  group('PlatformTenantSummary: el precio viene del servidor (AG)', () {
    test('un pionero NO se lleva la mitad por su cuenta (D-221)', () {
      final pionero = PlatformTenantSummary(
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
        effectiveMonthlyPrice: 150000,
      );

      // Antes esta línea decía 80000: $160.000 del plan `basico` partidos por
      // la mitad. Ni ese plan existe ya ni ese 50% lo aplica el servidor.
      expect(pionero.effectivePriceCop, 150000);
      expect(pionero.formattedEffectivePrice, '\$150.000 COP/mes');
      // El nombre del plan sí es cosa de la pantalla, y ese no cambia.
      expect(pionero.planNameFormatted, 'Básico');
    });

    test('un precio pactado se lee del servidor, no se copia del campo', () {
      final pactado = PlatformTenantSummary(
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
        discountPercent: 50,
        trialEndsAt: DateTime(2026, 8, 23),
        currentPeriodEnd: null,
        graceEndsAt: null,
        createdAt: DateTime(2026, 8, 15),
        effectiveMonthlyPrice: 30000,
      );

      // **La trampa de D-222, que el control 207 dejó probada:** el precio
      // pactado y el descuento NO son alternativas, se acumulan. $60.000 con
      // un 50% cobran $30.000. La versión vieja devolvía los $60.000 del
      // campo y enseñaba el doble de lo que se cobraba.
      expect(pactado.effectivePriceCop, 30000);
      expect(pactado.formattedEffectivePrice, '\$30.000 COP/mes');
      expect(pactado.tieneAcuerdo, isTrue);
      expect(pactado.isTrialing, true);
    });
  });
}
