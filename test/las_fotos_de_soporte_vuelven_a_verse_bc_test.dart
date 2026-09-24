import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/platform_tenant_detail.dart';

/// Hallazgo BC (D-076, D-274): el acceso de soporte vuelve a ver las fotos
/// que un negocio todavía no ha aprobado, tal como decidió julio.
void main() {
  group('BC — el modelo trae el almacén y la ruta de cada foto', () {
    test('una foto pendiente llega sin dirección pública, pero con su ruta', () {
      final foto = PlatformWorkPhotoSummary.fromMap({
        'photo_id': 'p1',
        'branch_name': 'Sede',
        'client_name': 'Clienta',
        'stylist_name': 'Estilista',
        'photo_url': null,
        'storage_bucket': 'work-photos-private',
        'storage_path': 'sede-1/foto.jpg',
        'photo_type': 'before',
        'visible_to_customer': false,
        'approved_for_portfolio': false,
      });

      expect(foto.photoUrl, isNull);
      expect(foto.displayUrl, isNull);
      expect(foto.storageBucket, 'work-photos-private');
      expect(foto.storagePath, 'sede-1/foto.jpg');
    });

    test('conDisplayUrl le pone la dirección temporal ya firmada', () {
      final foto = PlatformWorkPhotoSummary.fromMap({
        'photo_id': 'p1',
        'branch_name': 'Sede',
        'client_name': 'Clienta',
        'stylist_name': 'Estilista',
        'photo_url': null,
        'storage_bucket': 'work-photos-private',
        'storage_path': 'sede-1/foto.jpg',
        'photo_type': 'before',
        'visible_to_customer': false,
        'approved_for_portfolio': false,
      });

      final firmada = foto.conDisplayUrl('https://firmada.example/foto.jpg');
      expect(firmada.displayUrl, 'https://firmada.example/foto.jpg');
      // Lo demás no cambia.
      expect(firmada.storagePath, foto.storagePath);
    });

    test('una foto aprobada sigue usando su dirección pública de siempre', () {
      final foto = PlatformWorkPhotoSummary.fromMap({
        'photo_id': 'p2',
        'branch_name': 'Sede',
        'client_name': 'Clienta',
        'stylist_name': 'Estilista',
        'photo_url': 'https://publica.example/foto.jpg',
        'storage_bucket': 'work-photos',
        'storage_path': 'sede-1/foto.jpg',
        'photo_type': 'after',
        'visible_to_customer': true,
        'approved_for_portfolio': true,
      });

      expect(foto.displayUrl, 'https://publica.example/foto.jpg');
    });
  });

  group('BC — el servicio pide direcciones temporales para las pendientes', () {
    test('reutiliza WorkPhotoStorage, el mismo helper del propio negocio', () {
      final servicio = File(
        'lib/services/platform_tenant_detail_service.dart',
      ).readAsStringSync();
      expect(servicio, contains("import 'work_photo_storage.dart';"));
      expect(servicio, contains('_storage.firmar('));
    });
  });

  group('BC — la pantalla ya no dice que la foto no está disponible', () {
    test('usa displayUrl, no photoUrl, para pintar la miniatura', () {
      final pantalla = File(
        'lib/pages/platform_tenant_detail_page.dart',
      ).readAsStringSync();
      expect(pantalla, contains('FotoDeTrabajo(url: photo.displayUrl)'));
      expect(pantalla, isNot(contains('FotoDeTrabajo(url: photo.photoUrl)')));
    });
  });
}
