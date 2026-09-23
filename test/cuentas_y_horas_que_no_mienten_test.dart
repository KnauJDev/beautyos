import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hallazgos **AR** y **AX**, cerrados el 23-sep (D-257).
///
/// Pruebas sobre el texto del código a propósito: los dos fallos eran de una
/// línea —un filtro que olvidaba los ensayos, un mensaje que no distinguía dos
/// casos— y lo que hay que vigilar es que la línea no vuelva.
void main() {
  group('AR — el Panel cuenta las pruebas igual arriba y abajo', () {
    final panel = File('lib/pages/platform_panel_page.dart').readAsStringSync();

    test('la píldora En Prueba excluye los ensayos, como la métrica', () {
      // La métrica de arriba viene del servidor (`where not t.is_demo`); la
      // píldora contaba también los ensayos: 0 arriba, 1 abajo.
      expect(panel, contains('.where((t) => t.isTrialing && !t.isDemo)'));
      expect(panel, isNot(contains('allTenants.where((t) => t.isTrialing).length')));
    });

    test('y el filtro enseña lo mismo que cuenta la píldora', () {
      expect(
        panel,
        contains("if (selectedFilter == 'trialing') return t.isTrialing && !t.isDemo;"),
      );
    });
  });

  group('AX — la hora que caduca mientras la clienta escribe', () {
    final reserva = File('lib/pages/public_booking_page.dart').readAsStringSync();
    final envio = reserva.substring(
      reserva.indexOf('Future<void> _submitBooking()'),
      reserva.indexOf('String get _selectedDateText'),
    );

    test('antes de enviar se comprueba si la hora ya pasó', () {
      final comprobacion = envio.indexOf(
        '!slotOption.slot.startsAt.isAfter(DateTime.now())',
      );
      final llamada = envio.indexOf('bookingService.createBooking(');

      expect(comprobacion, greaterThan(0));
      expect(
        comprobacion,
        lessThan(llamada),
        reason: 'hay que avisar ANTES de mandar, no después del rechazo',
      );
    });

    test('"ya pasó" y "te la quitaron" son dos mensajes distintos', () {
      // El servidor dice lo mismo en los dos casos: "Ese horario ya no está
      // disponible". La clienta lo leía como "alguien me ganó" cuando lo que
      // pasó es que se le hizo tarde.
      expect(envio, contains("'Esa hora ya pasó mientras llenabas tus datos."));
      expect(envio, contains("'Alguien acaba de reservar esa hora."));
    });

    test('la lista se recarga sin volver a abrir el calendario', () {
      expect(reserva, contains('Future<void> _cargarHorarios(DateTime picked)'));
      expect(envio, contains('_horaPerdida('));
    });
  });
}
