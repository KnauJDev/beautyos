import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/theme/app_brand.dart';

String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Paso 3 del plan de David (03-oct): el tema "Inspirant", para todos.
void main() {
  test('Inspirant es un tema de la lista, con barra dorada y titulos negros', () {
    expect(AppBrand.resolver('inspirant', null), same(AppBrand.inspirant));
    expect(AppBrand.inspirant.label, 'Inspirant');
    expect(AppBrand.predefinidos, contains(AppBrand.inspirant));
  });

  test('la migracion solo agrega inspirant a las dos listas de la base', () {
    final m = leer('supabase/migrations/20261003230000_tema_inspirant_paso3.sql');
    expect(m, contains("'canina', 'inspirant',"));
    expect("EL UNICO CAMBIO, 'inspirant'".allMatches(m).length, 1);
    expect('CREATE OR REPLACE FUNCTION'.allMatches(m).length, 1);
    expect(
      leer('supabase/sql/243_test_tema_inspirant.sql'),
      contains('--- CONTROL 243: 4/4 ---'),
    );
  });
}
