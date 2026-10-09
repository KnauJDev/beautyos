import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/contrasena_nueva.dart';
import 'package:salonymas/models/mensaje_de_auth.dart';
import 'package:salonymas/pages/crear_contrasena_nueva_page.dart';
import 'package:salonymas/pages/recuperar_contrasena_page.dart';
import 'package:salonymas/services/contrasena_service.dart';
import 'package:salonymas/widgets/cambiar_contrasena_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hallazgo CO (D-327, 09-oct): nadie podía cambiar ni recuperar su
/// contraseña. Prototipo: https://claude.ai/artifact/G1TdLy6V3VVGmbKWGpJCoK
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

class FakeContrasena extends ContrasenaService {
  FakeContrasena({this.fallaAlEntrar, this.pideSeguridad = false});

  final AuthException? fallaAlEntrar;
  bool pideSeguridad;
  final correos = <String>[];
  final codigos = <String>[];
  final cambios = <({String nueva, String? codigo})>[];
  int codigosDeSeguridad = 0;

  @override
  Future<void> pedirCodigo(String correo) async => correos.add(correo.trim());

  @override
  Future<void> entrarConCodigo({required String correo, required String codigo}) async {
    codigos.add(codigo);
    if (fallaAlEntrar != null) throw fallaAlEntrar!;
  }

  @override
  Future<void> cambiar(String nueva, {String? codigo}) async {
    if (pideSeguridad && codigo == null) {
      throw const AuthException('Reauthentication required', code: 'reauthentication_needed');
    }
    cambios.add((nueva: nueva, codigo: codigo));
  }

  @override
  Future<void> pedirCodigoDeSeguridad() async => codigosDeSeguridad++;
}

void main() {
  group('la contraseña nueva', () {
    test('al menos 8 caracteres y las dos iguales', () {
      expect(ContrasenaNueva.aviso('', ''), 'Escribe la contraseña nueva.');
      expect(ContrasenaNueva.aviso('corta', 'corta'), 'Usa al menos 8 caracteres.');
      expect(ContrasenaNueva.aviso('Peluqueria2026', 'Peluqueria2025'), 'Las dos contraseñas no coinciden.');
      expect(ContrasenaNueva.aviso('Peluqueria2026', 'Peluqueria2026'), isNull);
    });

    test('los errores nuevos de Supabase, en español', () {
      expect(MensajeDeAuth.enEspanol(const AuthException('x', code: 'same_password')), contains('misma contraseña'));
      expect(MensajeDeAuth.enEspanol(const AuthException('x', code: 'reauthentication_not_valid')), contains('Ese código no sirve'));
      expect(MensajeDeAuth.enEspanol(const AuthException('x', code: 'insufficient_aal')), contains('app autenticadora'));
    });
  });

  group('¿Olvidaste tu contraseña?', () {
    Future<bool?> abrir(WidgetTester tester, FakeContrasena falso) async {
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RecuperarContrasenaPage(correoInicial: ' juan@ejemplo.com ', servicio: falso),
                ),
              );
            },
            child: const Text('entrar'),
          ),
        ),
      ));
      await tester.tap(find.text('entrar'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('correo, código, y se cierra con la sesión abierta', (tester) async {
      final falso = FakeContrasena();
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RecuperarContrasenaPage(correoInicial: 'juan@ejemplo.com', servicio: falso),
                ),
              );
            },
            child: const Text('entrar'),
          ),
        ),
      ));
      await tester.tap(find.text('entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Recupera tu cuenta'), findsOneWidget);

      await tester.tap(find.text('Enviarme el código'));
      await tester.pumpAndSettle();
      expect(falso.correos, ['juan@ejemplo.com']);
      expect(find.text('Escribe el código'), findsOneWidget);

      // Pegado con espacio, como llega a veces.
      await tester.enterText(find.byType(TextField), '4821 7730');
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(falso.codigos, ['48217730']);
      expect(resultado, isTrue);
    });

    testWidgets('pedir otro avisa que el anterior ya no sirve', (tester) async {
      final falso = FakeContrasena();
      await abrir(tester, falso);
      await tester.tap(find.text('Enviarme el código'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No me llegó — pedir otro código'));
      await tester.pumpAndSettle();
      expect(falso.correos, hasLength(2));
      expect(find.textContaining('El anterior ya no sirve'), findsOneWidget);
    });

    testWidgets('un código vencido lo dice en español y no cierra', (tester) async {
      final falso = FakeContrasena(fallaAlEntrar: const AuthException('Token has expired or is invalid', code: 'otp_expired'));
      await abrir(tester, falso);
      await tester.tap(find.text('Enviarme el código'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '11112222');
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ese código ya no sirve'), findsOneWidget);
      expect(find.text('Escribe el código'), findsOneWidget);
    });

    testWidgets('sin correo no manda nada', (tester) async {
      final falso = FakeContrasena();
      await tester.pumpWidget(MaterialApp(home: RecuperarContrasenaPage(servicio: falso)));
      await tester.tap(find.text('Enviarme el código'));
      await tester.pumpAndSettle();
      expect(falso.correos, isEmpty);
      expect(find.text('Escribe el correo con el que entras.'), findsOneWidget);
    });
  });

  group('crear la contraseña nueva', () {
    testWidgets('guarda y apaga el pendiente', (tester) async {
      crearContrasenaNueva.value = true;
      addTearDown(() => crearContrasenaNueva.value = false);
      final falso = FakeContrasena();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CrearContrasenaNuevaPage(servicio: falso))));
      await tester.enterText(find.byType(TextField).at(0), 'Peluqueria2026');
      await tester.enterText(find.byType(TextField).at(1), 'Peluqueria2025');
      await tester.tap(find.text('Guardar y entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Las dos contraseñas no coinciden.'), findsOneWidget);
      expect(falso.cambios, isEmpty);

      await tester.enterText(find.byType(TextField).at(1), 'Peluqueria2026');
      await tester.tap(find.text('Guardar y entrar'));
      await tester.pumpAndSettle();
      expect(falso.cambios.single.nueva, 'Peluqueria2026');
      expect(crearContrasenaNueva.value, isFalse);
    });

    testWidgets('"Cerrar sesión" sale y apaga el pendiente', (tester) async {
      crearContrasenaNueva.value = true;
      addTearDown(() => crearContrasenaNueva.value = false);
      var salio = false;
      await tester.pumpWidget(MaterialApp(
        home: CrearContrasenaNuevaPage(servicio: FakeContrasena(), onSalir: () async => salio = true),
      ));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect((salio, crearContrasenaNueva.value), (true, false));
    });
  });

  group('cambiar la contraseña con la sesión abierta', () {
    Future<bool?> abrir(WidgetTester tester, FakeContrasena falso) async {
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await showDialog<bool>(
                  context: context,
                  builder: (_) => CambiarContrasenaDialog(servicio: falso),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'NuevaClave2026');
      await tester.enterText(find.byType(TextField).at(1), 'NuevaClave2026');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('se guarda a la primera', (tester) async {
      final falso = FakeContrasena();
      await abrir(tester, falso);
      expect(falso.cambios.single, (nueva: 'NuevaClave2026', codigo: null));
    });

    testWidgets('si Supabase pide confirmar, manda el código y lo pide sin perder lo escrito', (tester) async {
      final falso = FakeContrasena(pideSeguridad: true);
      await abrir(tester, falso);
      expect(falso.codigosDeSeguridad, 1);
      expect(find.textContaining('Por seguridad te mandamos un código'), findsOneWidget);
      expect(falso.cambios, isEmpty);

      await tester.enterText(find.byType(TextField).at(2), '5510 2948');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(falso.cambios.single, (nueva: 'NuevaClave2026', codigo: '55102948'));
    });
  });

  test('la entrada, la puerta y Seguridad de tu cuenta', () {
    final entrar = leer('lib/pages/login_page.dart');
    expect(entrar, contains("child: const Text('¿Olvidaste tu contraseña?'),"));
    final puerta = leer('lib/pages/auth_gate.dart');
    // Después de la verificación en dos pasos, no antes.
    expect(
      puerta.indexOf('if (crearContrasenaNueva.value) {') > puerta.indexOf('if (needsMfaChallenge) {'),
      isTrue,
    );
    final seguridad = leer('lib/widgets/security_settings_dialog.dart');
    expect(seguridad, contains('builder: (_) => const CambiarContrasenaDialog(),'));
    final servicio = leer('lib/services/contrasena_service.dart');
    expect(servicio, contains('type: OtpType.recovery,'));
  });
}
