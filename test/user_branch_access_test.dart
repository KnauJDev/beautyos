import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/user_branch_access.dart';

void main() {
  group('Paso 8.6 — Modelo UserBranchAccess (Hallazgo V)', () {
    test('fromMap mapea correctamente todos los campos con acceso y catálogo', () {
      final map = {
        'branch_id': '00000000-0000-0000-0000-000000000001',
        'branch_name': 'Sede Principal Chapinero',
        'is_primary': true,
        'has_access': true,
        'in_catalog': true,
      };

      final access = UserBranchAccess.fromMap(map);

      expect(access.branchId, '00000000-0000-0000-0000-000000000001');
      expect(access.branchName, 'Sede Principal Chapinero');
      expect(access.isPrimary, true);
      expect(access.hasAccess, true);
      expect(access.inCatalog, true);
    });

    test('fromMap maneja valores por defecto y usuario no estilista (inCatalog null)', () {
      final map = {
        'branch_id': '00000000-0000-0000-0000-000000000002',
        'branch_name': 'Sede Norte',
        'is_primary': false,
        'has_access': false,
        'in_catalog': null,
      };

      final access = UserBranchAccess.fromMap(map);

      expect(access.branchId, '00000000-0000-0000-0000-000000000002');
      expect(access.branchName, 'Sede Norte');
      expect(access.isPrimary, false);
      expect(access.hasAccess, false);
      expect(access.inCatalog, isNull);
    });

    test('copyWith preserva valores originales al no especificarlos', () {
      const original = UserBranchAccess(
        branchId: 'b-1',
        branchName: 'Sede Centro',
        isPrimary: true,
        hasAccess: false,
        inCatalog: false,
      );

      final updated = original.copyWith(hasAccess: true, inCatalog: true);

      expect(updated.branchId, 'b-1');
      expect(updated.branchName, 'Sede Centro');
      expect(updated.isPrimary, true);
      expect(updated.hasAccess, true);
      expect(updated.inCatalog, true);
    });
  });
}
