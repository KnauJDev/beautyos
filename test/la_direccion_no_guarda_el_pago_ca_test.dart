import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/direccion_sin_ref_payco.dart';

/// CA (D-298): ePayco devuelve a `salonymas.com/?ref_payco=...` y la dirección
/// se quedaba así. Cada recarga volvía a preguntar por el pago y a enseñar el
/// aviso, y una pestaña vieja podía enseñárselo a otro negocio.
void main() {
  group('direccionSinRefPayco', () {
    test('el caso real: la vuelta de ePayco queda en la raíz', () {
      expect(
        direccionSinRefPayco(
          Uri.parse('https://salonymas.com/?ref_payco=abc123def456'),
        ),
        'https://salonymas.com/',
      );
    });

    test('sin ref_payco no hay nada que cambiar', () {
      expect(direccionSinRefPayco(Uri.parse('https://salonymas.com/')), isNull);
      expect(
        direccionSinRefPayco(Uri.parse('https://salonymas.com/?reservar=x')),
        isNull,
      );
    });

    test('solo quita ref_payco: los demás parámetros se quedan', () {
      final limpia = Uri.parse(
        direccionSinRefPayco(
          Uri.parse('https://salonymas.com/?ref=AMIGO&ref_payco=abc&x=1'),
        )!,
      );
      expect(limpia.queryParameters, {'ref': 'AMIGO', 'x': '1'});
      expect(limpia.queryParameters.containsKey('ref_payco'), isFalse);
    });

    test('conserva el fragmento, el puerto y la ruta', () {
      expect(
        direccionSinRefPayco(
          Uri.parse('http://localhost:8080/mi-salon?ref_payco=abc#/agenda'),
        ),
        'http://localhost:8080/mi-salon#/agenda',
      );
    });

    test('un ref_payco vacío también se quita', () {
      expect(
        direccionSinRefPayco(Uri.parse('https://salonymas.com/?ref_payco=')),
        'https://salonymas.com/',
      );
    });
  });

  group('la app limpia la dirección de verdad', () {
    final main = File('lib/main.dart').readAsStringSync();

    test('main.dart limpia la dirección antes de preguntarle a ePayco', () {
      final limpia = main.indexOf(
        'reemplazarDireccionSinRecargar(direccionLimpia)',
      );
      final pregunta = main.indexOf("'verify-epayco-transaction'");
      expect(limpia, greaterThan(-1));
      expect(pregunta, greaterThan(-1));
      expect(
        limpia,
        lessThan(pregunta),
        reason: 'Si se limpia después del await, una recarga a mitad de la '
            'consulta vuelve a enseñar el aviso.',
      );
      expect(main, contains('direccionSinRefPayco(Uri.base)'));
    });

    test('en Web se usa replaceState conservando el state de Flutter', () {
      final web = File(
        'lib/services/limpiar_direccion_web.dart',
      ).readAsStringSync();
      expect(web, contains('replaceState(_historial.state'));
      expect(web, isNot(contains('pushState')));
    });

    test('la importación condicional apunta a la versión Web', () {
      final puerta = File(
        'lib/services/limpiar_direccion.dart',
      ).readAsStringSync();
      expect(puerta, contains("if (dart.library.js_interop) 'limpiar_direccion_web.dart'"));
    });
  });
}
