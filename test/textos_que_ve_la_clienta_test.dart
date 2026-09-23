import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hallazgos **AV**, **BD** y **AQ** (23-sep): textos que decían algo que no es
/// verdad, o que lo decían mal, en pantallas que ve alguien de fuera.
///
/// Son pruebas sobre el **texto del código**, a propósito: los tres fallos
/// eran de texto, y el riesgo es que vuelvan a escribirse igual.

/// Las cadenas entre comillas simples de un archivo, sin los comentarios.
List<String> _cadenas(String ruta) {
  final lineas = File(ruta)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'));
  return RegExp(r"'([^'\n]*)'")
      .allMatches(lineas.join('\n'))
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  group('AV — las páginas públicas se escriben con tildes', () {
    // Palabras que el 18-sep y el 23-sep aparecieron sin tilde en pantallas
    // que ve una clienta o un salón interesado. "resena" no es "reseña": es
    // otra palabra.
    final sinTilde = RegExp(
      r'\b(resena|resenas|Resena|Resenas|calificacion|Calificacion|opinion|'
      r'pagina|publica|dias|linea|aqui|sabado|todavia|podras|quedara|'
      r'despues|cuentanos|Cuentanos|limites|limite|modulos|MODULOS|credito|'
      r'Escribenos|escribenos|teniamos|parecio|asi|crecio|clausula)\b',
    );

    for (final ruta in [
      'lib/pages/public_review_page.dart',
      'lib/pages/public_plans_page.dart',
    ]) {
      test(ruta, () {
        final malas = _cadenas(ruta).where(sinTilde.hasMatch).toList();
        expect(malas, isEmpty, reason: 'textos sin tilde en $ruta');
      });
    }

    test('las preguntas frecuentes abren con ¿', () {
      final preguntas = RegExp(r"question: '([^']*)'")
          .allMatches(
            File('lib/pages/public_plans_page.dart').readAsStringSync(),
          )
          .map((m) => m.group(1)!)
          .toList();

      expect(preguntas, isNotEmpty);
      for (final p in preguntas) {
        expect(p, startsWith('¿'), reason: p);
      }
    });
  });

  group('BD — ningún candado manda a comprar un plan que no existe', () {
    // D-188 dejó un solo plan, Todo Incluido. Los candados decían "Se activa
    // con el plan Business" o "Profesional". Hoy no se ven; el 9.41 (módulos
    // por sede) los vuelve a encender.
    test('no queda ningún planSugerido ni lockPlan en la aplicación', () {
      final archivos = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final f in archivos) {
        final codigo = f
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(codigo, isNot(contains('planSugerido')), reason: f.path);
        expect(codigo, isNot(contains('lockPlan')), reason: f.path);
        expect(codigo, isNot(contains('Se activa con el plan')), reason: f.path);
      }
    });
  });

  group('AQ — quien sube la foto no firma por la clienta', () {
    test('la casilla dice lo que hizo quien la marca, no lo que hizo ella', () {
      final dialogo = _cadenas('lib/widgets/add_work_photo_dialog.dart');

      expect(
        dialogo.any((c) => c.startsWith('La clienta autorizó')),
        isFalse,
        reason:
            'lo marca el estilista: no puede afirmar un hecho de la clienta',
      );
      expect(dialogo.any((c) => c.startsWith('Confirmo que le pedí')), isTrue);
    });
  });
}
