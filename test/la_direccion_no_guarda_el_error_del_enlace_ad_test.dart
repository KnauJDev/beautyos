import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/aviso_de_enlace_de_correo.dart';

/// AD (D-299), la mitad que dejó D-298: cuando un enlace de correo falla,
/// Supabase devuelve a `salonymas.com/?error=…&error_code=otp_expired` y la
/// dirección se quedaba así. El 27-sep la sesión de un estilista seguía con el
/// error en la barra días después.
void main() {
  const casoReal =
      'https://salonymas.com/?error=access_denied&error_code=otp_expired'
      '&error_description=Email+link+is+invalid+or+has+expired';

  group('direccionSinElError', () {
    test('el caso real del 18-sep queda en la raíz', () {
      expect(
        AvisoDeEnlaceDeCorreo.direccionSinElError(Uri.parse(casoReal)),
        'https://salonymas.com/',
      );
    });

    test('también lo quita cuando viene detrás del #', () {
      expect(
        AvisoDeEnlaceDeCorreo.direccionSinElError(
          Uri.parse(
            'https://salonymas.com/#error=access_denied&error_code=otp_expired'
            '&error_description=Email+link+is+invalid+or+has+expired',
          ),
        ),
        'https://salonymas.com/',
      );
    });

    test('la dirección limpia ya no produce aviso', () {
      // La prueba que importa: lo que queda en la barra no vuelve a contar
      // el fallo, ni en una recarga ni al cerrar sesión días después.
      for (final sucia in [
        casoReal,
        'https://salonymas.com/#error=access_denied&error_code=otp_expired',
        'https://salonymas.com/?error=server_error&ref=MANITO',
      ]) {
        final limpia = AvisoDeEnlaceDeCorreo.direccionSinElError(
          Uri.parse(sucia),
        );
        expect(limpia, isNotNull, reason: sucia);
        expect(
          AvisoDeEnlaceDeCorreo.desdeLaDireccion(Uri.parse(limpia!)),
          isNull,
          reason: sucia,
        );
      }
    });

    test('sin error no hay nada que cambiar', () {
      expect(
        AvisoDeEnlaceDeCorreo.direccionSinElError(
          Uri.parse('https://salonymas.com/'),
        ),
        isNull,
      );
      expect(
        AvisoDeEnlaceDeCorreo.direccionSinElError(
          Uri.parse('https://salonymas.com/?reservar=abc&ref=MANITO'),
        ),
        isNull,
      );
    });

    test('solo quita el error: los demás parámetros se quedan', () {
      final limpia = Uri.parse(
        AvisoDeEnlaceDeCorreo.direccionSinElError(
          Uri.parse('$casoReal&ref=MANITO'),
        )!,
      );
      expect(limpia.queryParameters, {'ref': 'MANITO'});
    });

    test('un fragmento que es una ruta se conserva', () {
      expect(
        AvisoDeEnlaceDeCorreo.direccionSinElError(
          Uri.parse('https://salonymas.com/?error=access_denied#/agenda'),
        ),
        'https://salonymas.com/#/agenda',
      );
    });
  });

  group('la app limpia la dirección de verdad', () {
    test('la pantalla de acceso lee el aviso ANTES de limpiar', () {
      final login = File('lib/pages/login_page.dart').readAsStringSync();
      final initState = login.indexOf('void initState()');
      final lee = login.indexOf('if (avisoDelEnlace != null)', initState);
      final limpia = login.indexOf(
        'AvisoDeEnlaceDeCorreo.direccionSinElError(',
        initState,
      );
      final reemplaza = login.indexOf(
        'reemplazarDireccionSinRecargar(direccionLimpia)',
        initState,
      );
      expect(initState, greaterThan(-1));
      expect(lee, greaterThan(initState));
      expect(
        limpia,
        greaterThan(lee),
        reason: 'Si se limpia antes de leer el aviso, el aviso no sale nunca.',
      );
      expect(reemplaza, greaterThan(limpia));
    });

    test('con la sesión abierta, AuthGate quita el error de la dirección', () {
      final puerta = File('lib/pages/auth_gate.dart').readAsStringSync();
      final conSesion = puerta.indexOf('if (isAuthenticated) {');
      expect(conSesion, greaterThan(-1));
      expect(
        puerta.indexOf('AvisoDeEnlaceDeCorreo.direccionSinElError(', conSesion),
        greaterThan(conSesion),
      );
      expect(
        puerta.indexOf(
          'reemplazarDireccionSinRecargar(direccionLimpia)',
          conSesion,
        ),
        greaterThan(conSesion),
      );
    });
  });
}
