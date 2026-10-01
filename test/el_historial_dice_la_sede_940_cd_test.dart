import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/tenant_subscription_history_entry.dart';

/// 9.40 y CD (D-303): el historial del Panel dice de qué sede es cada cobro, y
/// un cambio de sede desde el Panel queda escrito.
void main() {
  group('el modelo', () {
    test('lee la sede que manda el servidor', () {
      final e = TenantSubscriptionHistoryEntry.fromMap({
        'event_id': 'e1',
        'event_type': 'epayco_sede_aceptada',
        'amount_cop': 10000,
        'branch_id': 'b1',
        'branch_name': 'Sede Norte',
      });
      expect(e.branchId, 'b1');
      expect(e.branchName, 'Sede Norte');
    });

    test('aguanta un servidor que todavía no manda la sede', () {
      // Da igual publicar la app antes o después de aplicar la migración.
      final e = TenantSubscriptionHistoryEntry.fromMap({
        'event_id': 'e2',
        'event_type': 'tenant_approved',
      });
      expect(e.branchId, isNull);
      expect(e.branchName, isNull);
    });
  });

  group('la tabla del historial', () {
    final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();
    final ini = panel.indexOf("'Fecha y Hora'");
    final fin = panel.indexOf('}).toList()', ini);
    final tabla = panel.substring(ini, fin);

    test('tiene la columna Sede y la llena con la sede del renglón', () {
      expect(tabla, contains("'Sede'"));
      expect(tabla, contains('entry.branchName'));
    });

    test('tantas columnas como celdas, o la tabla revienta en pantalla', () {
      // `'Fecha y Hora'` ya está dentro de la primera columna, así que se
      // cuenta una más de las que encuentra el patrón.
      final columnas = 'DataColumn('.allMatches(tabla).length + 1;
      final celdas = 'DataCell('.allMatches(tabla).length;
      expect(columnas, 5);
      expect(celdas, columnas);
    });
  });

  group('la migración y su control', () {
    final migracion = File(
      'supabase/migrations/20260930190000_el_historial_dice_la_sede_940_cd.sql',
    ).readAsStringSync();

    test('el cambio de sede escribe su evento solo si algo cambió', () {
      expect(migracion, contains("'sede_cambiada_desde_el_panel'"));
      expect(migracion, contains('is distinct from'));
      expect(migracion, contains('auth.uid()'));
    });

    test('al recrear el historial le devuelve sus permisos', () {
      expect(
        migracion,
        contains(
          'drop function if exists '
          'public.platform_get_tenant_subscription_history(uuid);',
        ),
      );
      expect(
        migracion,
        contains(
          'revoke all on function '
          'public.platform_get_tenant_subscription_history(uuid) from public, anon;',
        ),
      );
      expect(
        migracion,
        contains(
          'grant execute on function '
          'public.platform_get_tenant_subscription_history(uuid) to authenticated;',
        ),
      );
      expect(migracion.trimRight(), endsWith('commit;'));
    });

    test('el control existe y termina en rollback', () {
      final control = File(
        'supabase/sql/237_test_el_historial_dice_la_sede_940_cd.sql',
      ).readAsStringSync();
      expect(control, contains('CONTROL 237: 9/9'));
      expect(control.trimRight(), endsWith('rollback;'));
    });
  });
}
