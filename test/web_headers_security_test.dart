import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián de las cabeceras de seguridad web (TL-03, D-202).
///
/// **Qué protege.** `web/_headers` es un archivo de texto que nadie compila y
/// que ninguna prueba de Flutter toca: se puede borrar media línea y todo
/// seguiría en verde hasta que alguien mirase la respuesta HTTP en producción.
/// La auditoría del 01-sep encontró que faltaban CSP, HSTS y protección contra
/// clickjacking; esta prueba existe para que lo que se añadió no se vaya sin
/// que nadie se entere.
///
/// **Lo que NO puede comprobar.** Que Cloudflare las sirva de verdad. Esto lee
/// el archivo del repositorio, no la respuesta del servidor. Comprobar lo
/// segundo es trabajo del propietario, con las herramientas del navegador o
/// `curl -I https://salonymas.com`.
void main() {
  late String archivo;
  late List<String> lineasDeCabecera;

  setUpAll(() {
    final fichero = File('web/_headers');
    expect(
      fichero.existsSync(),
      isTrue,
      reason:
          'Desapareció web/_headers. Sin él, Cloudflare vuelve a servir la app '
          'con cache de cuatro horas (D-096) y sin ninguna cabecera de '
          'seguridad (TL-03).',
    );

    archivo = fichero.readAsStringSync();

    // Solo las cabeceras de verdad: el archivo lleva un comentario largo que
    // cita a proposito las directivas que NO hay que anadir, y si se contaran
    // como si estuvieran puestas esta prueba se enganaria sola.
    lineasDeCabecera = fichero
        .readAsLinesSync()
        .where((linea) => !linea.trimLeft().startsWith('#'))
        .toList();
  });

  String? valorDe(String cabecera) {
    for (final linea in lineasDeCabecera) {
      final recortada = linea.trim();
      if (recortada.toLowerCase().startsWith('${cabecera.toLowerCase()}:')) {
        return recortada.substring(cabecera.length + 1).trim();
      }
    }
    return null;
  }

  group('TL-03 — Las cabeceras de seguridad siguen puestas', () {
    test('la regla cubre todas las rutas', () {
      expect(
        lineasDeCabecera.any((linea) => linea.trim() == '/*'),
        isTrue,
        reason:
            'El patrón "/*" es el que aplica las cabeceras a toda la app. Si '
            'se acota a unas rutas, el resto queda sin proteger y sin aviso.',
      );
    });

    test('no se puede enmarcar la aplicación en otro sitio', () {
      expect(
        valorDe('X-Frame-Options'),
        'DENY',
        reason:
            'Sin esto, cualquiera puede meter Salón y Más en un iframe suyo y '
            'poner botones encima para que un dueño pulse lo que no cree '
            'estar pulsando (clickjacking).',
      );

      final csp = valorDe('Content-Security-Policy');
      expect(csp, isNotNull, reason: 'Desapareció la Content-Security-Policy.');
      expect(
        csp,
        contains("frame-ancestors 'none'"),
        reason:
            'frame-ancestors es la versión moderna de X-Frame-Options, y es la '
            'que respetan los navegadores actuales. Las dos van juntas a '
            'propósito: la vieja cubre a los que no entienden la nueva.',
      );
    });

    test('cámara, micrófono y ubicación quedan apagados', () {
      final politica = valorDe('Permissions-Policy');
      expect(politica, isNotNull);

      for (final funcion in ['camera', 'microphone', 'geolocation']) {
        expect(
          politica,
          contains('$funcion=()'),
          reason:
              'Falta "$funcion=()". La aplicación no usa esa función — '
              'image_picker abre la galería, no la cámara — así que dejarla '
              'disponible solo sirve para que la use un script inyectado.',
        );
      }
    });

    test('siguen las cabeceras que ya había, y la revalidación de D-096', () {
      // Este bloque añadió cabeceras; no puede haberse llevado por delante las
      // que ya estaban. La de cache no es cosmética: sin ella un despliegue
      // tarda hasta cuatro horas en llegar, y si el arreglo es de cobros, se
      // cobra mal durante cuatro horas.
      expect(valorDe('Cache-Control'), 'public, max-age=0, must-revalidate');
      expect(valorDe('X-Content-Type-Options'), 'nosniff');
      expect(valorDe('Referrer-Policy'), 'strict-origin-when-cross-origin');
    });
  });

  group('TL-03 — La CSP no puede crecer sin romper el cobro', () {
    test('la CSP no restringe de dónde salen los scripts', () {
      // **Esta es la prueba importante de este archivo.**
      //
      // Ahora que existe una línea de Content-Security-Policy, lo natural es
      // que alguien la quiera "completar". CSP es opt-in por directiva: lo que
      // no se nombra no se restringe, y por eso hoy es segura. En cuanto
      // aparezca default-src, script-src o frame-src se rompen dos cosas:
      //
      //   1. https://checkout.epayco.co/checkout-v2.js -- la pasarela. Se cae
      //      el cobro de suscripciones para todos los negocios.
      //   2. passkeys_bundle.js, que usa WebAuthn.
      //
      // Y no se ve en flutter test ni en flutter analyze: solo aparece cuando
      // un negocio real intenta pagar. De ahí que lo vigile una prueba.
      final csp = valorDe('Content-Security-Policy')!;

      const peligrosas = ['default-src', 'script-src', 'frame-src'];
      final anadidas = peligrosas.where(csp.contains).toList();

      expect(
        anadidas,
        isEmpty,
        reason:
            'Se añadió ${anadidas.join(', ')} a la Content-Security-Policy. '
            'Eso bloquea checkout.epayco.co (la pasarela de pago) y '
            'passkeys_bundle.js, y el fallo solo se ve cuando un negocio real '
            'intenta pagar. Si de verdad hace falta endurecer la CSP, hay que '
            'permitir esos orígenes explícitamente y probar un pago antes de '
            'desplegar. Ver el comentario de web/_headers.',
      );
    });

    test('el aviso de por qué está escrito en el propio archivo', () {
      // La prueba dice que algo se rompió; el archivo tiene que decir por qué.
      // Quien edite `_headers` lo abre a él, no a esta prueba.
      expect(
        archivo,
        contains('checkout.epayco.co'),
        reason:
            'Se borró del comentario de web/_headers la advertencia sobre la '
            'pasarela de pago. Quien vaya a tocar la CSP abre ese archivo, no '
            'esta prueba: si el aviso no está ahí, no lo lee nadie.',
      );
    });
  });
}
