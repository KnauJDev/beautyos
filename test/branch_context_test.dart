import 'package:beautyos/models/branch_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BranchContext', () {
    test('interpreta una sede autorizada devuelta por Supabase', () {
      final context = BranchContext.fromMap({
        'tenant_id': 'tenant-a',
        'tenant_name': 'Bella Mujer',
        'branch_id': 'branch-a1',
        'branch_name': 'Sede Centro',
        'branch_slug': 'sede-centro',
        'role': 'tenant_owner',
        'stylist_id': null,
        'timezone': 'America/Bogota',
        'currency_code': 'COP',
        'is_primary': true,
        'option_count': 2,
      });

      expect(context.tenantId, 'tenant-a');
      expect(context.branchId, 'branch-a1');
      expect(context.branchName, 'Sede Centro');
      expect(context.isPrimary, isTrue);
      expect(context.optionCount, 2);
      expect(context.isLegacyFallback, isFalse);
    });

    test('mantiene compatibilidad mientras v2 no exista en produccion', () {
      final context = BranchContext.legacy(
        tenantId: 'tenant-a',
        tenantName: 'Bella Mujer',
        role: 'owner',
      );

      expect(context.branchId, isNull);
      expect(context.branchName, 'Sede principal');
      expect(context.optionCount, 1);
      expect(context.isLegacyFallback, isTrue);
    });
  });
}
