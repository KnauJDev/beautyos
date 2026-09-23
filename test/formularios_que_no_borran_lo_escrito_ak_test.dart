import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hallazgo **AK** (D-259): los diálogos que se cerraban ANTES de llamar al
/// servidor, de modo que un rechazo borraba todo lo escrito.
///
/// Lo vivió el propietario el 17-sep: un correo sin arroba en los datos de su
/// sede, el diálogo se cerró, el aviso salió abajo *"casi imperceptible"* y
/// tuvo que reescribir los siete campos.
///
/// Pruebas sobre el texto del código a propósito: el fallo es un **orden**
/// —cerrar primero, guardar después— y lo que se vigila es que no vuelva.
void main() {
  group('AK — los datos propios de la sede, un solo formulario', () {
    final dialogo = File(
      'lib/widgets/dialogo_datos_de_sede.dart',
    ).readAsStringSync();

    test('guarda desde dentro y solo se cierra si guardó', () {
      final guardar = dialogo.indexOf('await widget.guardar(');
      final cerrar = dialogo.indexOf('Navigator.of(context).pop(true)');

      expect(guardar, greaterThan(0));
      expect(cerrar, greaterThan(guardar));
    });

    test('un rechazo se queda dentro, junto al campo que lo causó', () {
      expect(dialogo, contains('on PostgrestException catch'));
      expect(dialogo, contains('errorText: error'));
      expect(dialogo, contains("m.contains('arroba')"));
    });

    test('el Panel y la Configuración usan el mismo, no dos copias', () {
      for (final ruta in [
        'lib/pages/platform_panel_page.dart',
        'lib/pages/settings_page.dart',
      ]) {
        final codigo = File(ruta).readAsStringSync();
        expect(codigo, contains('mostrarDialogoDatosDeSede('), reason: ruta);
        expect(
          codigo,
          isNot(contains("'Encargado de la sede'")),
          reason: '$ruta volvió a tener su propia copia del formulario',
        );
      }
    });

    test('la Configuración escribe la sede que miras, no la principal (D-242)', () {
      final config = File('lib/pages/settings_page.dart').readAsStringSync();
      final i = config.indexOf('mostrarDialogoDatosDeSede(');
      final llamada = config.substring(i, config.indexOf(');\n', i));
      expect(llamada, contains('branchId: widget.branchId'));
    });
  });

  group('AK — el precio y el estado de una sede, en el Panel', () {
    final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();
    final inicio = panel.indexOf("title: Text('Sede: \${sede.branchName}')");
    final fin = panel.indexOf('if (guardado == true && mounted) _recargarSedes();', inicio);
    final dialogo = panel.substring(inicio, fin);

    test('llama al servidor desde el botón Guardar, no al cerrarse', () {
      expect(inicio, greaterThan(0));
      final guardar = dialogo.indexOf('setBranchSubscription(');
      final cerrar = dialogo.indexOf('Navigator.of(context).pop(true)');
      expect(guardar, greaterThan(0));
      expect(cerrar, greaterThan(guardar));
      expect(dialogo, contains('errorDelServidor = error.message'));
    });
  });

  group('AK — crear cliente rápido desde la nueva cita', () {
    final tickets = File('lib/pages/tickets_page.dart').readAsStringSync();

    test('el diálogo crea la clienta él mismo y devuelve la creada', () {
      final i = tickets.indexOf('class _QuickCreateClientDialogState');
      final dialogo = tickets.substring(i, tickets.indexOf('\nclass ', i + 10));

      final crear = dialogo.indexOf('widget.clientsService.createClient(');
      final cerrar = dialogo.indexOf('Navigator.of(context).pop(creada)');
      expect(crear, greaterThan(0));
      expect(cerrar, greaterThan(crear));
      expect(dialogo, contains('_errorDelServidor = _friendlyError(error)'));
    });

    test('quien lo abre ya no llama al servidor con el diálogo cerrado', () {
      expect(tickets, isNot(contains('showDialog<_QuickClientFormData>')));
      expect(tickets, isNot(contains('class _QuickClientFormData')));
    });
  });
}
