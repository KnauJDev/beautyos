import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/services/monitoreo_service.dart';

/// Pruebas para MonitoreoService y captura segura de errores técnicos (D-209).
void main() {
  group('MonitoreoService.capturar', () {
    test('devuelve el valor correcto cuando la operación tiene éxito', () async {
      final resultado = await MonitoreoService.capturar(
        () async => 'datos_cargados_ok',
        motivo: 'Operación exitosa de prueba',
      );

      expect(resultado, equals('datos_cargados_ok'));
    });

    test('registra el error y relanza (rethrow) la excepción intacta cuando falla', () async {
      final excepcionOriginal = StateError('Fallo de red simulado');

      expect(
        () => MonitoreoService.capturar(
          () async => throw excepcionOriginal,
          motivo: 'Fallo simulado de prueba',
        ),
        throwsA(same(excepcionOriginal)),
      );
    });
  });

  group('Sanitización de PII (Ley 1581) en MonitoreoService', () {
    test('oculta direcciones de correo electrónico', () {
      final texto = 'El usuario contacto@salonymas.com reportó un fallo con test.dev+123@empresa.co';
      final sanitizado = MonitoreoService.taparDatosSensibles(texto);

      expect(sanitizado, contains('[correo oculto]'));
      expect(sanitizado, isNot(contains('contacto@salonymas.com')));
      expect(sanitizado, isNot(contains('test.dev+123@empresa.co')));
    });

    test('oculta números de teléfono de 7 a 15 dígitos', () {
      final texto = 'WhatsApp al 3001234567 o al fijo 6017654321 internacional 573109876543';
      final sanitizado = MonitoreoService.taparDatosSensibles(texto);

      expect(sanitizado, isNot(contains('3001234567')));
      expect(sanitizado, isNot(contains('6017654321')));
      expect(sanitizado, isNot(contains('573109876543')));
      expect(sanitizado, contains('[número oculto]'));
    });

    test('preserva identificadores técnicos no sensibles', () {
      final texto = 'Fallo en branch_reports_v3 con status code 500';
      final sanitizado = MonitoreoService.taparDatosSensibles(texto);

      expect(sanitizado, equals('Fallo en branch_reports_v3 con status code 500'));
    });
  });

  group('Guardián de excepciones no expuestas en UI', () {
    test('ninguna pantalla le muestra snapshot.error.toString() en crudo al salón', () {
      final infractores = <String>[];
      final regex = RegExp(r'snapshot\.error\.toString\(\)');

      for (final entidad in Directory('lib/pages').listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

        final ruta = entidad.path.replaceAll(r'\', '/');
        final lineas = entidad.readAsLinesSync();

        for (var i = 0; i < lineas.length; i++) {
          final linea = lineas[i];
          if (linea.trimLeft().startsWith('//')) continue;

          if (regex.hasMatch(linea)) {
            infractores.add('$ruta:${i + 1} -> ${linea.trim()}');
          }
        }
      }

      expect(
        infractores,
        isEmpty,
        reason:
            'Hay pantallas que enseñan snapshot.error.toString() en crudo al salón. '
            'El salón debe ver un mensaje amigable y el error técnico debe ir a MonitoreoService:\n'
            '${infractores.join('\n')}',
      );
    });
  });
}
