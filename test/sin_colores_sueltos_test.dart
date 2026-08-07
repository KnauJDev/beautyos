import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardian del sistema de diseno (D-102).
///
/// La tarea 2.2 elimino **54 colores distintos escritos a mano en 33
/// archivos**. Sin algo que lo vigile, eso vuelve solo: basta que una pantalla
/// nueva escriba su propio morado "porque era mas rapido" y en seis meses hay
/// otra vez cinco moradlos distintos.
///
/// Esta prueba falla si alguien escribe un color literal fuera de `lib/theme/`.
/// Si de verdad hace falta un tono nuevo, se agrega a `AppColors` y se usa por
/// su nombre.
void main() {
  test('ningun archivo de lib/ escribe colores a mano fuera de lib/theme', () {
    final literal = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
    final infractores = <String>[];

    for (final entidad in Directory('lib').listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

      final ruta = entidad.path.replaceAll(r'\', '/');
      if (ruta.startsWith('lib/theme/')) continue;

      final lineas = entidad.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (literal.hasMatch(lineas[i])) {
          infractores.add('$ruta:${i + 1} -> ${lineas[i].trim()}');
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Colores escritos a mano fuera del tema. Agregalos a AppColors y '
          'usalos por su nombre:\n${infractores.join('\n')}',
    );
  });
}
