import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_subscription.dart';

/// Los datos propios de una sede (D-241, paso 9.42).
///
/// POR QUÉ IMPORTA ESTE MODELO EN CONCRETO
///
/// `BranchSubscription` lo llenan **dos lectores distintos**:
///
/// * `get_branch_subscriptions()`, que ve el propio salón y **no manda** los
///   campos nuevos — al salón no le hacen falta, son suyos;
/// * `platform_get_tenant_branches()`, que ve el dueño de plataforma y sí.
///
/// Así que el mismo modelo tiene que sobrevivir a que falten esas claves. Si
/// se rompiera, no se rompería en el Panel —donde se probó— sino en la
/// pantalla de Configuración de todos los salones.
void main() {
  Map<String, dynamic> base() => <String, dynamic>{
    'branch_id': 'sede-1',
    'branch_name': 'Uñas Naguara',
    'is_primary': false,
    'branch_active': true,
    'status': 'active',
    'al_dia': true,
    'precio_cop': 150000,
    'motivo_precio': 'Precio de lista',
    'tiene_precio_pactado': false,
  };

  group('el lector del Panel manda los datos de la sede', () {
    test('los siete campos llegan al modelo', () {
      final sede = BranchSubscription.fromMap({
        ...base(),
        'manager_name': 'Marta Encargada',
        'contact_email': 'marta@naguara.com',
        'contact_phone': '6011234567',
        'whatsapp': '3001234567',
        'address': 'Calle 123 #45-67',
        'city': 'Bogotá',
        'department': 'Cundinamarca',
      });

      expect(sede.managerName, 'Marta Encargada');
      expect(sede.contactEmail, 'marta@naguara.com');
      expect(sede.contactPhone, '6011234567');
      expect(sede.whatsapp, '3001234567');
      expect(sede.address, 'Calle 123 #45-67');
      expect(sede.city, 'Bogotá');
      expect(sede.department, 'Cundinamarca');
      expect(sede.tieneDatosPropios, isTrue);
    });

    test('un solo campo basta para que la sede tenga datos propios', () {
      final sede = BranchSubscription.fromMap({
        ...base(),
        'manager_name': 'Marta Encargada',
      });

      expect(sede.tieneDatosPropios, isTrue);
      expect(sede.contactEmail, isNull);
    });
  });

  group('el lector del salón no manda esos campos, y no pasa nada', () {
    test('sin las claves, el modelo se construye igual', () {
      final sede = BranchSubscription.fromMap(base());

      expect(sede.branchName, 'Uñas Naguara');
      expect(sede.precioCop, 150000);
      expect(sede.managerName, isNull);
      expect(sede.address, isNull);
      expect(
        sede.tieneDatosPropios,
        isFalse,
        reason:
            'Sin campos propios, la pantalla debe poder decir "esta sede '
            'todavía no tiene datos propios" en vez de pintar siete guiones, '
            'que parecen un error de carga.',
      );
    });
  });

  group('vacío y en blanco valen lo mismo que ausente', () {
    test('la cadena vacía no cuenta como dato', () {
      final sede = BranchSubscription.fromMap({
        ...base(),
        'manager_name': '',
        'contact_email': '',
        'address': '',
      });

      expect(sede.managerName, isNull);
      expect(sede.contactEmail, isNull);
      expect(
        sede.tieneDatosPropios,
        isFalse,
        reason:
            'Una sede a la que se le borraron los datos tiene cadenas vacías, '
            'no claves ausentes. Si contaran como dato, la ficha diría que '
            'tiene datos propios y enseñaría siete campos en blanco.',
      );
    });

    test('solo espacios tampoco cuenta, y lo demás se recorta', () {
      final sede = BranchSubscription.fromMap({
        ...base(),
        'manager_name': '   ',
        'city': '  Bogotá  ',
      });

      expect(sede.managerName, isNull);
      expect(
        sede.city,
        'Bogotá',
        reason:
            'Un nombre de ciudad con espacios alrededor rompe cualquier '
            'comparación o búsqueda posterior sin que nadie vea por qué.',
      );
      expect(sede.tieneDatosPropios, isTrue);
    });
  });
}
