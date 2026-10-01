import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/cifra_escrita.dart';

/// CC (D-302): del lado del salón, los campos en pesos se leían con
/// `num.tryParse`, que toma el punto de miles como decimal. "35.000" en el
/// precio de un servicio se guardaba como $35, sin aviso.
void main() {
  group('el caso del fallo', () {
    test('"35.000" son treinta y cinco mil, no treinta y cinco', () {
      // Lo que hacía la pantalla antes, para que quede escrito:
      expect(num.tryParse('35.000'), 35);
      // Lo que hace ahora:
      expect(CifraEscrita.pesos('35.000').valor, 35000);
    });
  });

  group('centavos en cero: lo que la propia app precarga', () {
    for (final (escrito, esperado) in [
      ('35000.0', 35000),
      ('35000.00', 35000),
      ('35.000,00', 35000),
      (r'$35.000,00', 35000),
      ('0', 0),
      ('0.0', 0),
    ]) {
      test('"$escrito" son $esperado pesos', () {
        expect(CifraEscrita.pesos(escrito).valor, esperado);
      });
    }

    test('abrir un precio guardado y guardar sin tocarlo sigue funcionando', () {
      // Las casillas se precargan con `valor.toString()`. Fuera del navegador
      // un decimal se escribe "35000.0"; si el lector lo rechazara, editar el
      // nombre de un servicio fallaría por un precio que nadie tocó.
      for (final guardado in <num>[35000, 35000.0, 1250000.0, 0, 0.0]) {
        expect(
          CifraEscrita.pesos(guardado.toString()).valor,
          guardado.toInt(),
          reason: 'precargado como "${guardado.toString()}"',
        );
      }
    });

    test('centavos de verdad siguen sin leerse', () {
      for (final escrito in ['35000,50', '35000.5', '35.000,50']) {
        expect(CifraEscrita.pesos(escrito).esLegible, isFalse, reason: escrito);
      }
    });
  });

  group('las pantallas del salón usan el lector', () {
    String leer(String pagina) =>
        File('lib/pages/$pagina').readAsStringSync();

    test('cada campo en pesos lee con CifraEscrita', () {
      expect(
        leer('services_page.dart'),
        contains('CifraEscrita.pesos(priceController.text).valor'),
      );
      expect(
        leer('expenses_page.dart'),
        contains('CifraEscrita.pesos(amountController.text).valor'),
      );
      final inventario = leer('inventory_page.dart');
      expect(
        inventario,
        contains('CifraEscrita.pesos(purchasePriceController.text).valor'),
      );
      expect(
        inventario,
        contains('CifraEscrita.pesos(salePriceController.text).valor'),
      );
      final compras = leer('purchases_page.dart');
      expect(
        'CifraEscrita.pesos(line.unitCostController.text)'
            .allMatches(compras)
            .length,
        2,
        reason: 'Lo que se guarda y el total estimado tienen que leer igual.',
      );
      expect(
        'CifraEscrita.pesos(fixedController.text).valor'
            .allMatches(leer('settings_page.dart'))
            .length,
        2,
        reason: 'Las dos ventanas de comisión con valor fijo.',
      );
    });

    test('ninguna pantalla vuelve a leer dinero con tryParse', () {
      // El guardián que habría evitado CB y CC: un campo de dinero (precio,
      // valor, costo, fijo) leído con tryParse en cualquier pantalla.
      final patron = RegExp(
        r'(num|int|double)\.tryParse\(\s*[\w.]*'
        r'(price|Price|amount|Amount|cost|Cost|fixed|Fixed)\w*Controller',
      );
      final culpables = <String>[];
      for (final archivo in Directory('lib').listSync(recursive: true)) {
        if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
        for (final m in patron.allMatches(archivo.readAsStringSync())) {
          culpables.add('${archivo.path}: ${m.group(0)}');
        }
      }
      expect(culpables, isEmpty);
    });
  });
}
