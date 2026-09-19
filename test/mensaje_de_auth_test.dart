import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/mensaje_de_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hallazgo BA (19-sep): la pantalla le contestó «Token has expired or is
/// invalid» a un salón colombiano.
///
/// **Lo que se prueba de verdad** es la misma regla que en AM: los mensajes
/// están en español y dicen qué hacer, y **lo que no se conoce no se traga en
/// silencio**. Un mensaje en inglés es malo; ninguno es peor.
void main() {
  group('BA — los errores de Auth hablan español', () {
    test('el caso real del 19-sep: código vencido', () {
      final mensaje = MensajeDeAuth.enEspanol(
        const AuthException(
          'Token has expired or is invalid',
          code: 'otp_expired',
        ),
      );

      expect(mensaje, isNot(contains('Token')));
      expect(mensaje, isNot(contains('expired')));
      // Y dice qué hacer, no solo qué pasó.
      expect(mensaje.toLowerCase(), contains('pide otro'));
    });

    test('ninguno de los conocidos deja palabras en inglés ni jerga', () {
      const codigos = [
        'otp_expired',
        'invalid_credentials',
        'email_not_confirmed',
        'over_email_send_rate_limit',
        'user_already_exists',
        'weak_password',
        'validation_failed',
        'signup_disabled',
      ];

      for (final codigo in codigos) {
        final mensaje = MensajeDeAuth.enEspanol(
          AuthException('mensaje original en ingles', code: codigo),
        );

        expect(mensaje, isNot(contains('ingles')), reason: codigo);
        expect(mensaje, isNot(contains('token')), reason: codigo);
        expect(mensaje, isNot(contains('Token')), reason: codigo);
        expect(mensaje.trim(), isNotEmpty, reason: codigo);
      }
    });

    test('un código desconocido deja pasar el original, no lo calla', () {
      // Preferir un mensaje en ingles a no decir nada: callar es el fallo
      // que costó AM.
      final mensaje = MensajeDeAuth.enEspanol(
        const AuthException('Something odd happened', code: 'algo_nuevo'),
      );

      expect(mensaje, 'Something odd happened');
    });

    test('sin código tampoco se pierde el mensaje', () {
      final mensaje = MensajeDeAuth.enEspanol(
        const AuthException('Network error'),
      );

      expect(mensaje, 'Network error');
    });
  });
}
