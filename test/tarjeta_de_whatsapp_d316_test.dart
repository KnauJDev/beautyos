import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-316 (03-oct): la tarjeta de WhatsApp de cada salón y los íconos de la
/// página pública.
///
/// La tarjeta la arma `functions/[slug].js`, una función de Cloudflare Pages
/// que la app no ejecuta; aquí se vigila lo que no debe romperse nunca: que
/// solo lleve la llave publicable, que deje en paz a las personas y que los
/// archivos de la app no pasen por ella.
void main() {
  // Sin los \r de Windows: en una copia con CRLF la búsqueda de varias líneas
  // fallaría sin que nada estuviera mal.
  final funcion = File(
    'functions/[slug].js',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  test('la función de la tarjeta solo lleva la llave publicable', () {
    expect(funcion, contains('sb_publishable_'));
    expect(funcion, isNot(contains('sb_secret_')));
    expect(funcion, isNot(contains('service_role')));
    // La misma llave que la app, para que no haya dos que se desincronicen.
    final main = File('lib/main.dart').readAsStringSync();
    final llave = RegExp(r"sb_publishable_[A-Za-z0-9_]+").firstMatch(funcion)!;
    expect(main, contains(llave.group(0)!));
  });

  test('a una persona le devuelve la página como hoy', () {
    // `env.ASSETS.fetch` aplica `_headers` y `_redirects`; una respuesta
    // armada a mano no los llevaría.
    expect(funcion, contains('env.ASSETS.fetch(request)'));
    expect(
      funcion,
      contains(
        "if (!esLectorDeVistaPrevia(request.headers.get('User-Agent'))) return comoHoy();",
      ),
    );
    expect(funcion, contains('} catch (_) {\n    return comoHoy();'));
  });

  test('el texto y la imagen son los que eligió el propietario', () {
    expect(funcion, contains('Agenda tu cita en línea'));
    expect(funcion, contains('imagen: portada || logo'));
  });

  test('los archivos de la app no pasan por la función', () {
    final rutas =
        jsonDecode(File('web/_routes.json').readAsStringSync())
            as Map<String, dynamic>;
    final fuera = (rutas['exclude'] as List).cast<String>();
    for (final archivo in [
      '/',
      '/index.html',
      '/main.dart.js',
      '/flutter_bootstrap.js',
      '/build-info.json',
      '/assets/*',
      '/canvaskit/*',
    ]) {
      expect(fuera, contains(archivo));
    }
    expect(rutas['include'], ['/*']);
    // Cloudflare no admite más de 100 reglas.
    expect(fuera.length + (rutas['include'] as List).length, lessThan(100));
  });

  test('la página pública ya no usa emojis de calendario ni de persona', () {
    final salon = File('lib/pages/public_salon_page.dart').readAsStringSync();
    final reserva = File(
      'lib/pages/public_booking_page.dart',
    ).readAsStringSync();
    for (final codigo in [salon, reserva]) {
      expect(codigo, isNot(contains("Text('📅'")));
      expect(codigo, isNot(contains("Text('👤'")));
    }
    expect(salon, contains('Icons.event_available_outlined'));
    expect(salon, contains('Icons.person_outline'));
  });
}
