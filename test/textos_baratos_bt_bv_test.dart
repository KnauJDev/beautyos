import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/tipo_de_negocio.dart';
import 'package:salonymas/pages/agenda_page.dart';

/// Turno C, «lo que ve el cliente, barato»: BT y BV.
///
/// BT: el aviso del Tablero de Agenda decía «1 tickets pendientes».
/// BV: la página pública del salón enseñaba el código interno del tipo de
/// negocio («salon», en minúscula y sin tilde) porque lo pintaba tal cual.
void main() {
  group('BT — el aviso de pendientes de cierre sabe decir el singular', () {
    test('uno es singular en las dos palabras', () {
      expect(
        textoDePendientesDeCierre(1),
        '1 ticket pendiente de cierre comercial',
      );
    });

    test('dos o más es plural', () {
      expect(
        textoDePendientesDeCierre(2),
        '2 tickets pendientes de cierre comercial',
      );
      expect(
        textoDePendientesDeCierre(12),
        '12 tickets pendientes de cierre comercial',
      );
    });

    test('la pantalla usa la función, no el número pegado a «tickets»', () {
      final fuente = File('lib/pages/agenda_page.dart').readAsStringSync();

      // D-312 le añadió `tresEstados`: se mira sin espacios.
      expect(
        fuente.replaceAll(RegExp(r'\s+'), ''),
        contains('textoDePendientesDeCierre(pendientesCierre,'),
      );
      expect(
        fuente.contains(r"'$pendientesCierre tickets pendientes"),
        isFalse,
        reason: 'el número pegado a «tickets» es justo el fallo de BT',
      );
    });
  });

  group('BV (D-291) — Configuración y el Panel enseñan el texto, no el código',
      () {
    test('si no se toca el campo, se conserva el código original', () {
      expect(
        tipoDeNegocioAGuardar(
          original: 'salon',
          escrito: 'Peluquería / Salón de Belleza',
        ),
        'salon',
        reason: 'guardar otro dato del formulario no debe reescribir el tipo',
      );
    });

    test('si se cambia, se guarda lo que escribió', () {
      expect(
        tipoDeNegocioAGuardar(original: 'salon', escrito: ' Estudio de cejas '),
        'Estudio de cejas',
      );
      expect(
        tipoDeNegocioAGuardar(original: 'salon', escrito: 'Barbería'),
        'Barbería',
      );
    });

    test('un texto libre que no se toca queda igual', () {
      expect(
        tipoDeNegocioAGuardar(
          original: 'Peluquería canina',
          escrito: 'Peluquería canina',
        ),
        'Peluquería canina',
      );
    });

    test('vaciar el campo guarda vacío, como antes', () {
      expect(tipoDeNegocioAGuardar(original: 'salon', escrito: '  '), '');
      expect(tipoDeNegocioAGuardar(original: '', escrito: ''), '');
    });

    test('ida y vuelta: lo que se enseña y se guarda sin tocar no cambia nada',
        () {
      for (final opcion in tiposDeNegocio) {
        final codigo = opcion['value']!;
        final enPantalla = etiquetaDelTipoDeNegocio(codigo);

        expect(
          tipoDeNegocioAGuardar(original: codigo, escrito: enPantalla),
          codigo,
        );
      }
    });

    test('las pantallas usan las dos funciones, no el código crudo', () {
      final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();
      final ajustes = File('lib/pages/settings_page.dart').readAsStringSync();

      expect(
        panel,
        contains("etiquetaDelTipoDeNegocio(\n                            tenant.businessType ?? 'Peluquería / Salón',"),
      );
      expect(panel, contains('etiquetaDelTipoDeNegocio(tenant.businessType ?? \'\')'));
      expect(panel, contains('tipoDeNegocioAGuardar('));
      expect(ajustes, contains('etiquetaDelTipoDeNegocio(_tipoOriginal)'));
      expect(ajustes, contains('tipoDeNegocioAGuardar('));
      expect(
        ajustes.contains('businessType: _businessTypeController.text.trim()'),
        isFalse,
        reason: 'guardar el texto crudo reescribiría el código sin que nadie lo pida',
      );
    });
  });

  group('BV — la página pública traduce el tipo de negocio', () {
    test('«salon» se lee como se eligió al registrarse', () {
      expect(
        etiquetaDelTipoDeNegocio('salon'),
        'Peluquería / Salón de Belleza',
      );
    });

    test('todos los códigos del registro se traducen', () {
      for (final opcion in tiposDeNegocio) {
        final etiqueta = etiquetaDelTipoDeNegocio(opcion['value']!);

        expect(etiqueta, opcion['label']);
        expect(etiqueta, isNot(opcion['value']));
      }
    });

    test('un código con mayúsculas o espacios también se traduce', () {
      expect(
        etiquetaDelTipoDeNegocio('  Barberia '),
        'Barbería',
      );
    });

    test('el texto escrito a mano se respeta tal cual', () {
      expect(
        etiquetaDelTipoDeNegocio('Peluquería canina'),
        'Peluquería canina',
      );
      expect(
        etiquetaDelTipoDeNegocio('  Estudio de cejas  '),
        'Estudio de cejas',
      );
    });

    test('un código desconocido no se inventa: se deja como llegó', () {
      expect(etiquetaDelTipoDeNegocio('tatuajes'), 'tatuajes');
    });

    test('una sola lista: el registro y la página pública comparten la misma',
        () {
      final registro =
          File('lib/pages/complete_tenant_setup_page.dart').readAsStringSync();
      final publica = File('lib/pages/public_salon_page.dart').readAsStringSync();

      expect(registro, contains('= tiposDeNegocio'));
      expect(
        registro.contains("'label': 'Barbería'"),
        isFalse,
        reason: 'una copia de la lista en el registro es lo que D-198 prohíbe',
      );
      expect(publica, contains('etiquetaDelTipoDeNegocio(salon.businessType!)'));
    });
  });
}
