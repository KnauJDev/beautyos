import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_summary.dart';
import 'package:salonymas/pages/agenda_page.dart' show buildWhatsAppUri;

/// Hallazgo CK (03-oct): los enlaces de WhatsApp a personas salían sin el 57.
/// Desde D-249 los celulares se guardan con diez dígitos y sin indicativo, y
/// `wa.me/3506815620` es un número de Gibraltar, no de Colombia. Lo vio el
/// propietario al probar *Invitar a volver*: la dirección decía
/// `phone=3506815620`.
void main() {
  test('el celular guardado con diez dígitos sale con el 57', () {
    expect(
      buildWhatsAppUri('3506815620').toString(),
      'https://wa.me/573506815620',
    );
    expect(
      buildWhatsAppUri('3506815620', text: 'Hola').host,
      'wa.me',
    );
    expect(
      buildWhatsAppUri('3506815620', text: 'Hola').path,
      '/573506815620',
    );
  });

  test('el que ya trae el 57, o el +57, no se toca', () {
    expect(
      buildWhatsAppUri('573506815620').toString(),
      'https://wa.me/573506815620',
    );
    expect(
      buildWhatsAppUri('+57 350 681 5620').toString(),
      'https://wa.me/573506815620',
    );
  });

  test('lo que no es un celular colombiano de diez dígitos queda igual', () {
    // Un fijo de Bogotá con su indicativo, o un número de otro país.
    expect(buildWhatsAppUri('6015551234').toString(), 'https://wa.me/6015551234');
    expect(buildWhatsAppUri('+1 305 555 1234').toString(), 'https://wa.me/13055551234');
  });

  test('"Cada ~1 día", en singular', () {
    ClientSummary con(int? cadencia, int visitas) => ClientSummary.fromMap({
      'id': 'c',
      'name': 'Ana',
      'phone': '3000000000',
      'active': true,
      'total_visits': visitas,
      'avg_days_between_visits': cadencia,
      'segment': 'recurrente',
    });
    expect(con(1, 2).cadenceText, 'Cada ~1 día');
    expect(con(6, 3).cadenceText, 'Cada ~6 días');
  });
}
