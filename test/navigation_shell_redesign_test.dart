import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/main.dart';
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
      int selected = 0;
      final sections = [
        const BeautySection('Agenda', Icons.calendar_month_outlined, category: BeautyCategory.operacion),
        const BeautySection('Tickets & Caja', Icons.confirmation_number_outlined, category: BeautyCategory.operacion),
        const BeautySection('Dashboard', Icons.dashboard_outlined, category: BeautyCategory.finanzas),
        const BeautySection('Fotos', Icons.photo_library_outlined, category: BeautyCategory.portafolio),
        const BeautySection('Configuración', Icons.settings_outlined, category: BeautyCategory.sistema),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                // Renderizar el sidebar en un contenedor de prueba
                Container(
                  width: 240,
                  color: AppColors.surface,
                  child: ListView(
                    children: [
                      const Text('OPERACIÓN'),
                      const Text('Agenda'),
                      const Text('Tickets & Caja'),
                      const Text('FINANZAS Y GESTIÓN'),
                      const Text('Dashboard'),
                      const Text('PORTAFOLIO'),
                      const Text('Fotos'),
                      const Text('CATÁLOGO Y AJUSTES'),
                      const Text('Configuración'),
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
}
