import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/pages/login_page.dart';
import 'package:salonymas/pages/register_page.dart';
import 'package:salonymas/pages/terms_and_privacy_page.dart';

void main() {
  group('TermsAndPrivacyPage - Contenido legal (Paso 3.3 / Ley 1581)', () {
    testWidgets('la pestaña de Términos de Servicio muestra su contenido',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsAndPrivacyPage(initialTab: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Términos de Servicio'), findsWidgets);
      expect(find.textContaining('Colombia'), findsWidgets);
      expect(find.textContaining('ePayco'), findsWidgets);
      expect(find.textContaining('No reventa'), findsWidgets);
    });

    testWidgets(
        'la pestaña de Privacidad expone Habeas Data, derechos ARCO y contacto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsAndPrivacyPage(initialTab: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ley 1581'), findsWidgets);
      expect(find.textContaining('Derechos ARCO'), findsWidgets);
      expect(find.textContaining('hola@salonymas.com'), findsWidgets);
      expect(find.textContaining('Supabase'), findsWidgets);
    });

    testWidgets('se puede cambiar de pestaña con el TabBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsAndPrivacyPage(initialTab: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ley 1581'), findsNothing);

      await tester.tap(find.text('Privacidad (Habeas Data)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ley 1581'), findsWidgets);
    });
  });

  group('RegisterPage - Aceptación obligatoria de Términos (Paso 3.3)', () {
    testWidgets('el checkbox de aceptación inicia sin marcar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(onRegisterSuccess: () {})),
      );
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets(
        'bloquea el registro con un aviso claro si no se aceptan los términos',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(onRegisterSuccess: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Correo'),
        'dueño@salon.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña (mínimo 8 caracteres)'),
        'contraseñaSegura123',
      );

      // El checkbox NO se marca a propósito: no debe permitir continuar.
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Debes aceptar los Términos de Servicio'),
        findsOneWidget,
      );
    });

    testWidgets('marcar el checkbox quita el bloqueo previo de términos',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(onRegisterSuccess: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Correo'),
        'dueño@salon.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña (mínimo 8 caracteres)'),
        'contraseñaSegura123',
      );

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Debes aceptar los Términos de Servicio'),
        findsOneWidget,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('tocar "Términos de Servicio" abre la vista legal completa',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterPage(onRegisterSuccess: () {})),
      );
      await tester.pumpAndSettle();

      // El enlace vive dentro de un Text.rich con varios TextSpan; se activa
      // su recognizer directamente, igual que lo haría un tap real sobre ese
      // fragmento de texto.
      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Acepto los'),
        ),
      );
      // Text.rich envuelve el TextSpan recibido dentro de un TextSpan
      // sintético con el estilo por defecto fusionado, así que hay que bajar
      // un nivel más para llegar a los spans propios.
      final wrapper = richText.text as TextSpan;
      final ownRoot = wrapper.children!.single as TextSpan;
      final enlaceTerminos = ownRoot.children!.firstWhere(
        (s) => (s as TextSpan).text == 'Términos de Servicio',
      ) as TextSpan;
      (enlaceTerminos.recognizer as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();

      expect(find.byType(TermsAndPrivacyPage), findsOneWidget);
      expect(find.text('Privacidad (Habeas Data)'), findsOneWidget);
    });
  });

  group('Paso 8.5 — Clarificar pantalla de acceso para invitados (Hallazgo S)', () {
    testWidgets('LoginPage muestra guía para colaboradores invitados y botón para registrar salón', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            onLoginSuccess: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subtítulo neutral
      expect(find.text('Ingresa a tu cuenta'), findsOneWidget);

      // Bloque de orientación al colaborador invitado por correo
      expect(
        find.textContaining('¿Te invitaron a un equipo?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Inicia sesión con el correo de tu invitación'),
        findsOneWidget,
      );

      // Camino explícito de registrar negocio nuevo
      expect(
        find.text('¿Quieres usar Salón y Más en tu centro?'),
        findsOneWidget,
      );
      expect(
        find.text('Registra tu negocio gratis'),
        findsOneWidget,
      );
    });

    testWidgets('RegisterPage clarifica que es para registrar un negocio y orienta a invitados a iniciar sesión', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            onRegisterSuccess: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Título claro de creación de negocio
      expect(find.text('Registra tu negocio en Salón y Más'), findsOneWidget);
      expect(find.text('21 días de prueba gratis, sin tarjeta.'), findsOneWidget);

      // Enlace de retorno que acoge a invitados
      expect(
        find.text('¿Ya tienes cuenta o te invitaron a un equipo? Inicia sesión'),
        findsOneWidget,
      );
    });
  });
}
