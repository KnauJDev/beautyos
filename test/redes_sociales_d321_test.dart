import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/models/redes_sociales.dart';

/// D-321 (08-oct): David escribió los NOMBRES de sus cuentas ("Inspirant
/// salon", "Inspirant peluquería") y no sus usuarios; la página armaba
/// enlaces a cuentas que no existen y TikTok devolvía a la clienta.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

PublicSalonProfile salon({String? instagram, String? facebook, String? tiktok}) =>
    PublicSalonProfile.fromMap({
      'tenant_id': 't1',
      'name': 'Inspirant Salon',
      'slug': 'inspirant-salon',
      'instagram': instagram,
      'facebook': facebook,
      'tiktok': tiktok,
    });

void main() {
  test('lo que escribió David: un usuario sí, los nombres no', () {
    expect(esUsuarioOEnlaceDeRed('@inspirantsalon'), isTrue);
    expect(esUsuarioOEnlaceDeRed('Inspirant salon'), isFalse);
    expect(esUsuarioOEnlaceDeRed('Inspirant peluquería'), isFalse);
    expect(esUsuarioOEnlaceDeRed('peluquería'), isFalse, reason: 'un usuario no lleva tildes');
  });

  test('los enlaces y los usuarios bien escritos pasan', () {
    for (final v in [
      '',
      '  ',
      'inspirant.salon',
      'inspirant_salon',
      'https://www.tiktok.com/@inspirant',
      'https://vm.tiktok.com/ZMabc123/',
      'tiktok.com/@inspirant',
      'www.facebook.com/inspirantsalon',
      'https://www.facebook.com/profile.php?id=1000',
    ]) {
      expect(esUsuarioOEnlaceDeRed(v), isTrue, reason: v);
    }
    expect(avisoDeRed('Inspirant salon'), avisoDeRedInvalida);
    expect(avisoDeRed('@inspirantsalon'), isNull);
  });

  test('la página no enseña el botón de un nombre: no hay perfil al que ir', () {
    final david = salon(
      instagram: '@inspirantsalon',
      facebook: 'Inspirant salon',
      tiktok: 'Inspirant peluquería',
    );
    expect(david.instagramUri.toString(), 'https://instagram.com/inspirantsalon');
    expect(david.facebookUri, isNull);
    expect(david.tiktokUri, isNull);
  });

  test('ya corregido, los tres botones abren su perfil', () {
    final david = salon(
      instagram: 'https://www.instagram.com/inspirantsalon/',
      facebook: 'www.facebook.com/inspirantsalon',
      tiktok: '@inspirant.peluqueria',
    );
    expect(david.instagramUri.toString(), 'https://www.instagram.com/inspirantsalon/');
    expect(david.facebookUri.toString(), 'https://www.facebook.com/inspirantsalon');
    expect(david.tiktokUri.toString(), 'https://www.tiktok.com/@inspirant.peluqueria');
  });

  test('el Panel ve el TikTok: la migración solo le suma esa columna', () {
    final m = leer('supabase/migrations/20261008100000_tiktok_en_el_panel_d321.sql');
    expect(m, contains('branches_breakdown text, tiktok text)'));
    expect(m, contains("coalesce(sedes.branches_breakdown, 'Sin sedes activas'),"));
    expect(m, contains('    t.tiktok\n'));
    expect(m, contains("SET search_path TO 'pg_catalog'"), reason: 'el texto vivo, tal cual');
    expect(m, contains('grant execute on function public.platform_list_tenants() to authenticated;'));
    final c = leer('supabase/sql/247_test_tiktok_en_el_panel.sql');
    expect(c, contains('--- CONTROL 247: 4/4 ---'));
    expect(c.trimRight(), endsWith('rollback;'));
    expect(leer('lib/models/platform_tenant_summary.dart'), contains("tiktok: map['tiktok']?.toString(),"));
    expect(leer('lib/pages/platform_panel_page.dart'), contains("'TikTok:',"));
  });

  test('Configuración avisa en el campo y no guarda un nombre con espacios', () {
    final ajustes = leer('lib/pages/settings_page.dart');
    expect(ajustes, contains('_avisoFacebook = avisoDeRed(_facebookController.text);'));
    expect(ajustes, contains('errorText: _avisoTiktok,'));
    expect(
      ajustes,
      contains('if (_avisoInstagram != null || _avisoFacebook != null || _avisoTiktok != null) {\n      return;'),
    );
  });
}
