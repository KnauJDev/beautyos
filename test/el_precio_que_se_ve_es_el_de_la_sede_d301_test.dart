import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-301: la ficha del Panel enseñaba "Acuerdo del negocio: $4.500 — no se
/// cobra", un precio viejo del negocio que desde D-239 no decide nada. El
/// propietario lo leyó como vigente el 30-sep y pidió ver el que se cobra: el
/// de la sede elegida arriba (D-244).
void main() {
  final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();

  test('la tarjeta del plan enseña el precio de la sede elegida', () {
    final tarjeta = panel.substring(panel.indexOf("title: '3. Plan del negocio'"));
    final precio = tarjeta.indexOf("'Precio de esta sede:'");
    expect(precio, greaterThan(-1));
    // Lee la misma sede que la tarjeta 1, buscada por su identificador.
    expect(tarjeta.substring(0, precio), contains('_sedeVigente(sedes)'));
    expect(tarjeta, contains("'pactado'"));
    expect(tarjeta, contains("'tarifa de lista'"));
  });

  test('el precio viejo del negocio ya no se enseña en el Panel', () {
    expect(panel, isNot(contains("'Acuerdo del negocio:'")));
    expect(panel, isNot(contains("'no se cobra'")));
    expect(
      panel,
      isNot(contains('formattedEffectivePrice')),
      reason: 'Ni en la ficha ni en la lista de clientes: no cobra desde D-239.',
    );
  });

  test('el aviso manda a la tarjeta que existe, con su nombre de hoy', () {
    expect(panel, isNot(contains("'Míralo en la tarjeta de sedes.'")));
    expect(panel, contains('«1. Esta sede», botón Pago.'));
    expect(panel, contains("title: '1. Esta sede'"));
    expect(panel, contains("label: const Text('Pago')"));
  });
}
