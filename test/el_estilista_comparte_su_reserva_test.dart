import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/enlace_de_reserva.dart';

/// D-266 y D-267: el estilista NO agenda —para que no pueda llevarse la base de
/// clientas del salón—, pero trae a sus conocidos compartiendo el enlace de
/// reservas de su sede, que es lo que el propietario dijo.
void main() {
  test('el enlace de reserva es el de la sede y lleva directo a reservar', () {
    final enlace = enlaceDeReservaDeSede(
      'sede-123',
      origen: 'https://salonymas.com',
    );
    expect(enlace, 'https://salonymas.com/?reservar=sede-123');
  });

  test('Mi agenda le pone el enlace a mano al estilista', () {
    final agenda = File('lib/pages/my_stylist_agenda_page.dart').readAsStringSync();
    // D-312 le añadió un segundo dato (si la cita nace confirmada): se mira
    // la llamada sin espacios para no depender de cómo quedó partida.
    final sinEspacios = agenda.replaceAll(RegExp(r'\s+'), '');
    expect(sinEspacios, contains('CompartirReservaDelEstilista(branchId:widget.branchId'));
  });

  test('la tarjeta no le enseña ni le deja crear clientas', () {
    // Es justo lo que D-266 quiso evitar: que el estilista vea la lista.
    final tarjeta = File(
      'lib/widgets/compartir_reserva_del_estilista.dart',
    ).readAsStringSync();
    expect(tarjeta, isNot(contains('ClientsService')));
    expect(tarjeta, isNot(contains('getClients')));
    expect(tarjeta, isNot(contains('createClient')));
  });

  test('el enlace se arma en un solo sitio', () {
    // Configuración y Mi agenda usan la misma función: dos copias del mismo
    // enlace son dos enlaces el día que cambie uno.
    // D-313: las dos tarjetas usan `enlaceParaCompartir`, que vive en el
    // mismo archivo que `enlaceDeReservaDeSede` y la llama cuando no puede
    // usar la dirección con el nombre del salón. Sigue siendo un solo sitio.
    // D-318 (07-oct): Configuración tiene una sola tarjeta, *Tu enlace*, que
    // usa la página del salón en cualquier sede (y el directo de la sede
    // debajo): `enlaceDeLaPaginaDelSalon`, del mismo archivo.
    for (final (ruta, funcion) in [
      ('lib/pages/settings_page.dart', 'enlaceDeLaPaginaDelSalon('),
      ('lib/widgets/compartir_reserva_del_estilista.dart', 'enlaceParaCompartir('),
    ]) {
      final codigo = File(ruta).readAsStringSync();
      expect(codigo, contains(funcion), reason: ruta);
      expect(codigo, isNot(contains("?reservar=\$")), reason: ruta);
    }
  });
}
