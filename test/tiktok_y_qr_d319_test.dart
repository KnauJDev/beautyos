import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:salonymas/models/business_settings.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/pages/settings_page.dart' show TuEnlaceCard;
import 'package:salonymas/widgets/codigo_qr_del_enlace.dart';

/// D-319 (07-oct): cómo se comparte el enlace del salón. TikTok junto a
/// Instagram y Facebook (lo pidió David), y el código QR que la tarjeta *Tu
/// enlace* prometía y la app no hacía. El servidor lo prueba el control 246.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

PublicSalonProfile conTiktok(String? tiktok) => PublicSalonProfile.fromMap({
  'tenant_id': 't1',
  'name': 'Inspirant Salon',
  'slug': 'inspirant-salon',
  'tiktok': tiktok,
});

void main() {
  group('TikTok', () {
    test('acepta el usuario con o sin @, y la dirección con o sin https', () {
      const perfil = 'https://www.tiktok.com/@inspirant';
      expect(conTiktok('@inspirant').tiktokUri.toString(), perfil);
      expect(conTiktok('inspirant').tiktokUri.toString(), perfil);
      expect(conTiktok('  @inspirant  ').tiktokUri.toString(), perfil);
      expect(conTiktok(perfil).tiktokUri.toString(), perfil);
      expect(conTiktok('tiktok.com/@inspirant').tiktokUri.toString(), 'https://tiktok.com/@inspirant');
      expect(conTiktok('').tiktokUri, isNull);
      expect(conTiktok('@').tiktokUri, isNull);
      expect(conTiktok(null).tiktokUri, isNull);
    });

    test('Configuración y la página lo leen del servidor', () {
      expect(BusinessSettings.fromMap({'tiktok': '@inspirant'}).tiktok, '@inspirant');
      expect(BusinessSettings.fromMap({}).tiktok, isNull);
      expect(conTiktok('@inspirant').tiktok, '@inspirant');
    });

    test('se guarda siempre: el servicio lo exige y lo manda como texto', () {
      final servicio = leer('lib/services/business_settings_service.dart');
      expect(servicio, contains('required String tiktok,'));
      expect(servicio, contains("'p_tiktok': tiktok,"));
      final ajustes = leer('lib/pages/settings_page.dart');
      expect(ajustes, contains("labelText: 'TikTok',"));
      expect(ajustes, contains('tiktok: _tiktokController.text.trim(),'));
    });

    test('la página pública enseña su botón', () {
      final pagina = leer('lib/pages/public_salon_page.dart');
      expect(pagina, contains('if (salon.tiktokUri != null)'));
      // Desde D-320, un botón redondo más de la fila de contacto.
      expect(pagina, contains("etiqueta: 'TikTok',"));
    });

    test('la migración: una columna, null no borra, y los permisos de siempre', () {
      final m = leer('supabase/migrations/20261007200000_tiktok_del_salon_d319.sql');
      expect(m, contains('alter table public.tenants add column if not exists tiktok text;'));
      expect(m, contains('p_tiktok text default null'));
      expect(m, contains('when p_tiktok is null then tiktok'));
      expect(m, contains('grant execute on function public.get_public_salon_by_slug(text) to anon, authenticated;'));
      expect(m, contains('revoke execute on function public.get_business_settings() from anon, public;'));
      // El Panel no se toca.
      expect(m, isNot(contains('create or replace function public.platform_list_tenants')));
      final c = leer('supabase/sql/246_test_tiktok_del_salon.sql');
      expect(c, contains('--- CONTROL 246: 6/6 ---'));
      expect(c.trimRight(), endsWith('rollback;'));
    });
  });

  group('el código QR', () {
    test('el archivo lleva el nombre del salón, sin tildes', () {
      expect(nombreDelArchivoQr('Peluquería Éxito Prueba'), 'qr-peluqueria-exito-prueba.png');
      expect(nombreDelArchivoQr('  '), 'qr-de-tu-salon.png');
      expect(nombreDelArchivoQr(null), 'qr-de-tu-salon.png');
    });

    test('corrección de errores media: un QR impreso se raya', () {
      expect(nivelDelQr, QrErrorCorrectLevel.M);
    });

    testWidgets('la imagen para imprimir es un PNG', (tester) async {
      final bytes = await tester.runAsync(
        () => imagenDelCodigoQr(
          enlace: 'https://salonymas.com/inspirant-salon',
          nombreDelSalon: 'Inspirant Salon',
        ),
      );
      expect(bytes, isNotNull);
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets('Tu enlace tiene el botón, y abre el QR de su enlace', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TuEnlaceCard(
            branchId: 'sede-1',
            slugDelSalon: 'inspirant-salon',
            nombreDelSalon: 'Inspirant Salon',
            esSedePrincipal: true,
            origen: 'https://salonymas.com',
          ),
        ),
      ));
      await tester.tap(find.text('Código QR'));
      await tester.pumpAndSettle();
      expect(find.text('Código QR de tu enlace'), findsOneWidget);
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.semanticsLabel, 'Código QR de https://salonymas.com/inspirant-salon');
      expect(find.text('Descargar imagen'), findsOneWidget);
    });

    test('se descarga de verdad, no abriendo una pestaña con data:', () {
      final web = leer('lib/services/descargar_archivo_web.dart');
      expect(web, contains('..download = nombre'));
      expect(web, isNot(contains('data:')));
      expect(leer('pubspec.yaml'), contains('qr_flutter: ^4.1.0'));
    });
  });
}
