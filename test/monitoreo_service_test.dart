import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/services/monitoreo_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Pruebas para MonitoreoService, sanitización de Sentry y guardián de excepciones limpias en UI (D-209, D-210).
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

    test('oculta números de teléfono de 7 a 15 dígitos y con espacios', () {
      final texto = 'WhatsApp al 300 123 4567 o al fijo 6017654321 internacional +57 310 987 6543';
      final sanitizado = MonitoreoService.taparDatosSensibles(texto);

      expect(sanitizado, isNot(contains('300 123 4567')));
      expect(sanitizado, isNot(contains('6017654321')));
      expect(sanitizado, isNot(contains('310 987 6543')));
      expect(sanitizado, contains('[número oculto]'));
    });

    test('preserva identificadores técnicos no sensibles', () {
      final texto = 'Fallo en branch_reports_v3 con status code 500';
      final sanitizado = MonitoreoService.taparDatosSensibles(texto);

      expect(sanitizado, equals('Fallo en branch_reports_v3 con status code 500'));
    });

    test('_limpiar sanea message, exceptions y breadcrumbs en un SentryEvent completo', () {
      final eventoOriginal = SentryEvent(
        message: SentryMessage('Error de usuario juan@salon.com con celular 300 987 6543'),
        exceptions: [
          SentryException(
            type: 'PostgrestException',
            value: 'Error en base con cliente maria@beauty.com o tel 3151234567',
          ),
        ],
        breadcrumbs: [
          Breadcrumb(
            message: 'debugPrint: PostgrestException con titular carlos@empresa.co cel 320 555 1234',
          ),
        ],
      );

      final eventoLimpio = MonitoreoService.limpiarEventoParaPruebas(eventoOriginal);

      // Verificación de message
      expect(eventoLimpio.message?.formatted, isNot(contains('juan@salon.com')));
      expect(eventoLimpio.message?.formatted, isNot(contains('300 987 6543')));
      expect(eventoLimpio.message?.formatted, contains('[correo oculto]'));
      expect(eventoLimpio.message?.formatted, contains('[número oculto]'));

      // Verificación de exceptions
      final exLimpia = eventoLimpio.exceptions?.first;
      expect(exLimpia?.value, isNot(contains('maria@beauty.com')));
      expect(exLimpia?.value, isNot(contains('3151234567')));
      expect(exLimpia?.value, contains('[correo oculto]'));
      expect(exLimpia?.value, contains('[número oculto]'));

      // Verificación de breadcrumbs
      final bLimpio = eventoLimpio.breadcrumbs?.first;
      expect(bLimpio?.message, isNot(contains('carlos@empresa.co')));
      expect(bLimpio?.message, isNot(contains('320 555 1234')));
      expect(bLimpio?.message, contains('[correo oculto]'));
      expect(bLimpio?.message, contains('[número oculto]'));
    });
  });

  group('Guardián estricto de excepciones no expuestas en UI (D-209, D-210)', () {
    /// Archivos con excepción explícita permitida y su motivo arquitectónico.
    const permitidos = <String, String>{
      'lib/pages/platform_panel_page.dart':
          'Panel de superadministrador/dueño de plataforma SaaS: diagnóstico técnico de tenants/operadores.',
      'lib/pages/platform_tenant_detail_page.dart':
          'Detalle de plataforma para el dueño de SaaS: diagnóstico técnico de negocio.',
    };

    test('ninguna pantalla de cara al salón le enseña snapshot.error en crudo al usuario', () {
      final infractores = <String>[];
      // Detecta tanto .toString() como interpolaciones ${snapshot.error} o snapshot.error directo en strings/widgets
      final regex = RegExp(r'(?:snapshot\.error\.toString\(\)|\$\{snapshot\.error\}|snapshot\.error)');

      final directorios = ['lib/pages', 'lib/widgets', 'lib'];

      for (final dir in directorios) {
        final d = Directory(dir);
        if (!d.existsSync()) continue;

        final entidades = dir == 'lib'
            ? [File('lib/main.dart')]
            : d.listSync(recursive: true).whereType<File>().toList();

        for (final entidad in entidades) {
          if (!entidad.path.endsWith('.dart')) continue;

          final ruta = entidad.path.replaceAll(r'\', '/');
          if (permitidos.containsKey(ruta)) continue;
          if (ruta.startsWith('lib/services/')) continue;

          final lineas = entidad.readAsLinesSync();

          for (var i = 0; i < lineas.length; i++) {
            final linea = lineas[i];
            final recortada = linea.trimLeft();
            if (recortada.startsWith('//')) continue;
            if (recortada.startsWith('if (snapshot.hasError') ||
                recortada.startsWith('if (s.hasError') ||
                recortada.startsWith('if (!snapshot.hasError')) {
              continue;
            }

            if (regex.hasMatch(linea)) {
              infractores.add('$ruta:${i + 1} -> ${linea.trim()}');
            }
          }
        }
      }

      expect(
        infractores,
        isEmpty,
        reason:
            'Hay pantallas de cara al salón que enseñan snapshot.error en crudo al usuario. '
            'El salón debe ver un mensaje amigable y el error técnico debe ir a MonitoreoService:\n'
            '${infractores.join('\n')}',
      );
    });
  });
}
