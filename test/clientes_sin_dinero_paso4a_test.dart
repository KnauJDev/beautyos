import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/pages/clients_page.dart'
    show mensajeDeWhatsAppAClienta;

/// Leído con los saltos de línea normalizados.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Paso 4A del plan de David (03-oct): en un negocio con la caja apagada la
/// pantalla Clientes no enseña dinero. Como no cobra en la app, todas sus
/// citas parecían sin pagar, y cada clienta salía debiendo. Y el saludo de
/// WhatsApp decía "Salón y Más" en todos los negocios.
void main() {
  group('el WhatsApp a una clienta', () {
    test('en riesgo: la invita a volver, con el salón y su enlace', () {
      final m = mensajeDeWhatsAppAClienta(
        nombre: 'Ana',
        enRiesgo: true,
        tieneSaldo: true,
        saldo: r'$30.000',
        sinDinero: true,
        nombreDelSalon: 'Inspirant Salon',
        enlace: 'https://salonymas.com/inspirant-salon',
      );
      expect(m, contains('¡te extrañamos en Inspirant Salon!'));
      expect(m, contains('agenda aquí 👉 https://salonymas.com/inspirant-salon'));
      expect(m, isNot(contains('saldo')));
    });

    test('sin caja, nunca le recuerda un saldo que no existe', () {
      final m = mensajeDeWhatsAppAClienta(
        nombre: 'Ana',
        enRiesgo: false,
        tieneSaldo: true,
        saldo: r'$30.000',
        sinDinero: true,
        nombreDelSalon: 'Inspirant Salon',
      );
      expect(m, isNot(contains('saldo')));
      expect(m, 'Hola Ana, te escribimos de Inspirant Salon.');
    });

    test('con caja, el recordatorio de saldo sigue como estaba', () {
      expect(
        mensajeDeWhatsAppAClienta(
          nombre: 'Ana',
          enRiesgo: false,
          tieneSaldo: true,
          saldo: r'$30.000',
          sinDinero: false,
          nombreDelSalon: 'Peluquería Éxito',
        ),
        r'Hola Ana, te escribimos para recordarte tu saldo pendiente de $30.000.',
      );
    });

    test('el saludo dice el nombre del salón, no "Salón y Más"', () {
      final m = mensajeDeWhatsAppAClienta(
        nombre: 'Ana',
        enRiesgo: false,
        tieneSaldo: false,
        saldo: r'$0',
        sinDinero: false,
        nombreDelSalon: 'Peluquería Éxito',
      );
      expect(m, 'Hola Ana, te escribimos de Peluquería Éxito.');
      expect(m, isNot(contains('Salón y Más')));
    });
  });

  group('la pantalla Clientes sin caja', () {
    final clientes = leer('lib/pages/clients_page.dart');

    test('esconde el filtro "Con saldo", el gasto y la deuda', () {
      expect(clientes, contains('if (withBalanceCount > 0 && !widget.sinDinero)'));
      expect(clientes, contains('if (client.totalSpent > 0 && !sinDinero)'));
      expect(clientes, contains('if (client.hasPendingBalance && !sinDinero)'));
      expect(clientes, isNot(contains("'Hola \${client.firstName}, te escribimos de Salón y Más.'")));
    });

    test('la ficha tampoco enseña gasto, ticket promedio ni mora', () {
      expect(clientes, contains('if (!sinDinero) ...['));
      expect(
        clientes,
        contains('if (client.hasPendingBalance && !sinDinero) ...['),
      );
    });

    test('main la enciende con la caja apagada y le da el salón', () {
      final main = leer('lib/main.dart');
      expect(main, contains('page: ClientesPage(\n          sinDinero: cajaOculta,'));
    });
  });

  test('el Panel abre la página pública de cada salón', () {
    final panel = leer('lib/pages/platform_panel_page.dart');
    expect(panel, contains("label: const Text('Ver su página pública'),"));
    expect(panel, contains('const SlugDelSalonService().leer(sede.branchId)'));
  });
}
