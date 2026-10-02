import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/mensaje_de_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CF (D-309): el 02-oct el equipo del primer cliente real no pudo entrar.
/// Cada cuenta recibió dos códigos con dos minutos de diferencia, y se escribió
/// el del primer correo, que ya no servía. Supabase dice lo mismo para un
/// código vencido, uno equivocado y uno viejo.
void main() {
  final login = File('lib/pages/login_page.dart').readAsStringSync();
  final registro = File('lib/pages/register_page.dart').readAsStringSync();

  test('el error dice qué hacer: el del correo más reciente', () {
    final m = MensajeDeAuth.enEspanol(
      const AuthException('Token has expired or is invalid', code: 'otp_expired'),
    );
    expect(m, contains('más reciente'));
    expect(m.toLowerCase(), contains('pide otro'));
    expect(m, isNot(contains('venció')), reason: 'Casi nunca es que venció.');
  });

  test('Ingresar con el correo sin confirmar NO manda un código solo', () {
    final ini = login.indexOf('Future<void> pasarAConfirmarPorCodigo(');
    final fin = login.indexOf('\n  }\n', ini);
    final cuerpo = login.substring(ini, fin);
    expect(
      cuerpo,
      isNot(contains('reenviarCodigo(')),
      reason: 'Mandar uno nuevo sin avisar anula el que la persona ya tiene (CF).',
    );
    // Y sigue llevando a la pantalla del código cuando el correo no está confirmado.
    expect(login, contains("error.code == 'email_not_confirmed'"));
    expect(login, contains('pasarAConfirmarPorCodigo(avisar: true)'));
  });

  test('pedir otro código avisa que el anterior deja de servir, en las dos pantallas', () {
    const aviso = 'no sirve: usa el del correo más reciente.';
    expect(login.replaceAll("'\n            '", ''), contains('El anterior ya no sirve: usa el del correo más reciente.'));
    expect(registro.replaceAll("'\n          '", ''), contains('El anterior ya no sirve: usa el del correo más reciente.'));
    expect(login, contains(aviso));
  });

  test('el registro avisa desde el primer código', () {
    expect(registro, contains('Si pides otro, este deja de servir'));
  });
}
