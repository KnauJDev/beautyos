import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_info.dart';
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

  // --------------------------------------------------------------------------
  // BranchInfo: lo mismo, pero visto desde el propio salón (D-242).
  //
  // Es un modelo aparte a propósito. `BranchSubscription` responde "¿cuánto
  // paga esta sede?" y lo mira el dueño de plataforma; este responde "¿quién
  // la lleva y dónde está?" y lo mira el salón. Juntarlos obligaría a que la
  // Configuración de cada salón arrastrara campos de dinero que no le tocan.
  // --------------------------------------------------------------------------
  group('la sede vista desde su propio salón', () {
    test('llegan los datos y se sabe que los tiene', () {
      final sede = BranchInfo.fromMap(<String, dynamic>{
        'branch_id': 'sede-2',
        'branch_name': 'Uñas Naguara',
        'is_primary': false,
        'manager_name': 'Marta Encargada',
        'address': 'Calle de las peluquerías No. 14-70',
        'city': 'Bogotá',
      });

      expect(sede.branchName, 'Uñas Naguara');
      expect(sede.isPrimary, isFalse);
      expect(sede.managerName, 'Marta Encargada');
      expect(sede.address, 'Calle de las peluquerías No. 14-70');
      expect(sede.contactEmail, isNull);
      expect(sede.tieneDatos, isTrue);
    });

    test('una sede recién creada no tiene datos propios', () {
      final sede = BranchInfo.fromMap(<String, dynamic>{
        'branch_id': 'sede-3',
        'branch_name': 'Sede nueva',
        'is_primary': false,
      });

      expect(
        sede.tieneDatos,
        isFalse,
        reason:
            'Sin datos propios la pantalla explica para qué sirven, en vez de '
            'enseñar siete casillas vacías sin decir por qué están ahí.',
      );
    });

    test('lo borrado se queda borrado, no cuenta como dato', () {
      final sede = BranchInfo.fromMap(<String, dynamic>{
        'branch_id': 'sede-4',
        'branch_name': 'Sede vaciada',
        'is_primary': true,
        'manager_name': '',
        'address': '   ',
      });

      expect(sede.managerName, isNull);
      expect(sede.address, isNull);
      expect(
        sede.tieneDatos,
        isFalse,
        reason:
            'Vaciar los campos deja cadenas vacías, no claves ausentes. Si '
            'contaran, la tarjeta diría que la sede tiene datos y enseñaría '
            'siete renglones en blanco.',
      );
    });
  });
}
