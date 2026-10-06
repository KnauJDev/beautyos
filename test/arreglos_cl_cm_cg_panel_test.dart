import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_board.dart' show formatCOP;
import 'package:salonymas/pages/register_page.dart'
    show errorTrasMarcarTerminos, mensajeDeTerminosSinAceptar;

/// Cuatro arreglos pequeños del 06-oct, antes del paso 6:
///   * CL: la cabecera ya no dice "BeautyOS" bajo el nombre del salón.
///   * CM: el precio medio y los totales llevan punto de miles.
///   * CG: el aviso de términos se va al marcar la casilla.
///   * El Panel actualiza su "N ajustes especiales" al mover un interruptor.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('CL: debajo del nombre del salón no va nada (decisión del propietario)', () {
    expect(leer('lib/main.dart'), isNot(contains("'BeautyOS',")));
  });

  group('CM: los pesos con punto de miles', () {
    test('el formateador de siempre', () {
      expect(formatCOP(24333.33), r'$24.333');
      expect(formatCOP(1250000), r'$1.250.000');
    });

    test('servicios, gastos y compras lo usan', () {
      expect(leer('lib/pages/services_page.dart'), contains('value: formatCOP(avgPrice),'));
      expect(leer('lib/pages/expenses_page.dart'), contains('value: formatCOP(totalAmount),'));
      final compras = leer('lib/pages/purchases_page.dart');
      expect(compras, contains('value: formatCOP(totalAmount),'));
      expect(compras, contains(r"'Total estimado: ${formatCOP(_estimatedTotal)}'"));
      for (final ruta in [
        'lib/pages/services_page.dart',
        'lib/pages/expenses_page.dart',
        'lib/pages/purchases_page.dart',
      ]) {
        expect(leer(ruta), isNot(contains(r"'\$${")), reason: ruta);
      }
    });
  });

  group('CG: el aviso de términos', () {
    test('se va al marcar la casilla', () {
      expect(errorTrasMarcarTerminos(mensajeDeTerminosSinAceptar, aceptado: true), isNull);
    });

    test('se queda si se desmarca, y los demás avisos no se tocan', () {
      expect(
        errorTrasMarcarTerminos(mensajeDeTerminosSinAceptar, aceptado: false),
        mensajeDeTerminosSinAceptar,
      );
      const otro = 'La contraseña debe tener al menos 8 caracteres.';
      expect(errorTrasMarcarTerminos(otro, aceptado: true), otro);
      expect(errorTrasMarcarTerminos(null, aceptado: true), isNull);
    });
  });

  test('el Panel avisa a la lista al mover un interruptor o un límite', () {
    final panel = leer('lib/pages/platform_panel_page.dart');
    expect('onCambio: widget.onAjustesCambiados,'.allMatches(panel).length, 2);
    expect(panel, contains('onAjustesCambiados: _refrescarSinParpadeo,'));
    expect(panel, contains('      widget.onCambio?.call();'));
    // Y la lista no se cambia por la ruedita al recargar: la ficha abierta se
    // queda donde está.
    expect(
      panel,
      contains(
        'if (snapshot.connectionState == ConnectionState.waiting &&\n'
        '            !snapshot.hasData) {',
      ),
    );
  });
}
