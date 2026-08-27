import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/public_salon_profile.dart';

void main() {
  group('PublicSalonProfile (D-098 / D-164)', () {
    test('fromMap mapea todos los campos de la RPC pública', () {
      final profile = PublicSalonProfile.fromMap({
        'tenant_id': 'tenant-1',
        'name': 'Naguara de Uñas',
        'slug': 'naguara-de-unas',
        'business_type': 'Salón de uñas',
        'logo_url': 'https://ejemplo.com/logo.png',
        'cover_photo_url': 'https://ejemplo.com/portada.png',
        'theme_key': 'esmeralda',
        'brand_color': null,
        'city': 'Bogotá',
        'address': 'Calle 100 #10-20',
        'whatsapp': '+573001234567',
        'contact_phone': '+576011234567',
        'instagram': '@naguaradeunas',
        'facebook': 'NaguaraDeUnas',
      });

      expect(profile.tenantId, 'tenant-1');
      expect(profile.name, 'Naguara de Uñas');
      expect(profile.slug, 'naguara-de-unas');
      expect(profile.businessType, 'Salón de uñas');
      expect(profile.logoUrl, 'https://ejemplo.com/logo.png');
      expect(profile.coverPhotoUrl, 'https://ejemplo.com/portada.png');
      expect(profile.themeKey, 'esmeralda');
      expect(profile.brandColor, isNull);
      expect(profile.city, 'Bogotá');
      expect(profile.address, 'Calle 100 #10-20');
      expect(profile.whatsapp, '+573001234567');
      expect(profile.contactPhone, '+576011234567');
      expect(profile.instagram, '@naguaradeunas');
      expect(profile.facebook, 'NaguaraDeUnas');
    });

    test('name cae en "Este negocio" si la RPC no trae nombre', () {
      final profile = PublicSalonProfile.fromMap({
        'tenant_id': 'tenant-1',
        'slug': 'algun-slug',
      });

      expect(profile.name, 'Este negocio');
    });

    test('locationLine combina ciudad y dirección con " · ", omitiendo lo vacío', () {
      final conAmbos = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'city': 'Bogotá',
        'address': 'Calle 1',
      });
      expect(conAmbos.locationLine, 'Bogotá · Calle 1');

      final soloCiudad = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'city': 'Bogotá',
      });
      expect(soloCiudad.locationLine, 'Bogotá');

      final ninguno = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(ninguno.locationLine, '');
    });

    test('instagramHandle quita el "@" del hint de Configuración', () {
      final conArroba = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'instagram': '@naguaradeunas',
      });
      expect(conArroba.instagramHandle, 'naguaradeunas');
      expect(conArroba.instagramUri.toString(), 'https://instagram.com/naguaradeunas');

      final sinArroba = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'instagram': 'naguaradeunas',
      });
      expect(sinArroba.instagramHandle, 'naguaradeunas');

      final vacio = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(vacio.instagramHandle, isNull);
      expect(vacio.instagramUri, isNull);
    });

    test('facebookUri respeta una URL completa y arma una a partir de un handle', () {
      final urlCompleta = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'facebook': 'https://facebook.com/paginaReal',
      });
      expect(urlCompleta.facebookUri.toString(), 'https://facebook.com/paginaReal');

      final soloHandle = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'facebook': 'NaguaraDeUnas',
      });
      expect(soloHandle.facebookUri.toString(), 'https://facebook.com/NaguaraDeUnas');

      final vacio = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(vacio.facebookUri, isNull);
    });
  });
}
