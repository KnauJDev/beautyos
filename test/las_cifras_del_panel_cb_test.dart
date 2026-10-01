import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/cifra_escrita.dart';

/// 9.9 y CB (D-300): las pruebas del Panel de plataforma en precios y
/// aprobaciones, que es la caja registradora del SaaS.
///
/// Salieron de escribirlas: los tres campos de dinero del Panel leían
/// "15.000" como vacío (o como 15), sin avisar. En la ventana de la sede,
/// vacío significa volver a la tarifa vigente, así que el acuerdo se borraba.
void main() {
  group('CifraEscrita.pesos: como lo escribe una persona en Colombia', () {
    for (final (escrito, esperado) in [
      ('75000', 75000),
      ('75.000', 75000),
      (r'$75.000', 75000),
      (r'$ 75.000', 75000),
      ('75 000', 75000),
      ('75,000', 75000),
      ('1.250.000', 1250000),
      ('  10000  ', 10000),
    ]) {
      test('"$escrito" son $esperado pesos', () {
        final cifra = CifraEscrita.pesos(escrito);
        expect(cifra.esLegible, isTrue);
        expect(cifra.valor, esperado);
      });
    }

    test('el caso del fallo: "15.000" ya no se lee como vacío', () {
      // Con int.tryParse era null, y en la ventana de la sede null borraba el
      // precio pactado (limpiarPrecio). Esta es la prueba que importa.
      final cifra = CifraEscrita.pesos('15.000');
      expect(cifra.estaVacia, isFalse);
      expect(cifra.valor, 15000);
    });

    test('vacío es vacío, no un error: en la sede significa tarifa vigente', () {
      for (final escrito in ['', '   ']) {
        final cifra = CifraEscrita.pesos(escrito);
        expect(cifra.estaVacia, isTrue, reason: '"$escrito"');
        expect(cifra.esLegible, isTrue, reason: '"$escrito"');
      }
    });

    for (final escrito in [
      'setenta mil',
      '75000,50',
      '75.000,50',
      '7.5000',
      '1.250,000',
      '-75000',
      '1234567890123',
    ]) {
      test('"$escrito" no se lee: se avisa en vez de adivinar', () {
        final cifra = CifraEscrita.pesos(escrito);
        expect(cifra.esLegible, isFalse);
        expect(cifra.valor, isNull);
        expect(cifra.estaVacia, isFalse);
      });
    }
  });

  group('CifraEscrita.porcentaje: la comisión de un aliado', () {
    for (final (escrito, esperado) in [
      ('15', 15.0),
      ('12,5', 12.5),
      ('12.5', 12.5),
      ('15%', 15.0),
      ('15 %', 15.0),
    ]) {
      test('"$escrito" es $esperado %', () {
        expect(CifraEscrita.porcentaje(escrito).valor, esperado);
      });
    }

    test('"15.000" como porcentaje no se lee: era un valor en pesos', () {
      expect(CifraEscrita.porcentaje('15.000').esLegible, isFalse);
    });

    test('lo que no es un número ya no se vuelve 15 en silencio', () {
      expect(CifraEscrita.porcentaje('quince').valor, isNull);
      expect(CifraEscrita.porcentaje('').valor, isNull);
    });
  });

  group('el Panel usa el lector en sus tres campos de dinero', () {
    final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();

    test('ningún campo de dinero se lee ya con tryParse', () {
      expect(panel, isNot(contains('int.tryParse(priceController')));
      expect(panel, isNot(contains('int.tryParse(precioTexto)')));
      expect(panel, isNot(contains('double.tryParse(valueController')));
      expect(panel, isNot(contains('?? 15.0')));
    });

    test('aprobar: la cifra se comprueba antes de cerrar la ventana', () {
      final aprobar = panel.substring(
        panel.indexOf('Future<void> handleApprove('),
      );
      final comprueba = aprobar.indexOf('CifraEscrita.pesos(price).esLegible');
      final cierra = aprobar.indexOf('Navigator.of(context).pop(true)');
      expect(comprueba, greaterThan(-1));
      expect(
        comprueba,
        lessThan(cierra),
        reason: 'Validar después de cerrar borra lo escrito (hallazgo AK).',
      );
    });

    test('la sede: lo ilegible se detiene antes de decidir si se limpia', () {
      final lee = panel.indexOf('CifraEscrita.pesos(precioCtrl.text)');
      final detiene = panel.indexOf('if (!lectura.esLegible)', lee);
      final limpia = panel.indexOf('limpiarPrecio:', lee);
      expect(lee, greaterThan(-1));
      expect(detiene, greaterThan(lee));
      expect(
        limpia,
        greaterThan(detiene),
        reason: 'Si llega a limpiarPrecio con la cifra ilegible, borra el '
            'acuerdo: el fallo de CB.',
      );
    });

    test('aliados: la comisión se lee según su tipo y no tiene valor por '
        'defecto', () {
      expect(panel, contains('CifraEscrita.porcentaje(valueController.text)'));
      expect(panel, contains('CifraEscrita.pesos(valueController.text)'));
      expect(panel, contains('commissionValue: comision.valor!.toDouble()'));
    });
  });
}
