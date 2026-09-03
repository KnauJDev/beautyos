import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/services/image_compression.dart';

/// Guardián de la compresión de imágenes (TL-20, D-199).
///
/// **Qué protege.** Los cinco servicios de subida llamaban a `pickImage`
/// sin `maxWidth`, `maxHeight` ni `imageQuality`: la foto viajaba tal cual
/// salía del celular, y el único techo era el `file_size_limit` de 10 MB del
/// almacén, que no comprime nada — solo rechaza lo que se pase.
///
/// **Por qué una prueba que lee el código fuente.** `ImagePicker` necesita un
/// canal de plataforma: en `flutter test` no hay galería que abrir ni foto que
/// devolver, así que no se puede comprobar el efecto de verdad. Lo que sí se
/// puede vigilar es que nadie vuelva a escribir la llamada sin comprimir — que
/// es exactamente cómo llegaron a ser cinco. Mismo recurso que
/// `sin_colores_sueltos_test.dart` (D-102).
void main() {
  group('TL-20 — Las imágenes se comprimen antes de subir', () {
    test('la política declara los tres límites acordados', () {
      expect(kLadoMaximoDeImagen, 1920);
      expect(kCalidadDeImagen, 85);
    });

    test('nadie llama a ImagePicker fuera de image_compression.dart', () {
      final infractores = <String>[];
      final llamada = RegExp(r'ImagePicker\s*\(\s*\)');

      for (final entidad in Directory('lib').listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

        final ruta = entidad.path.replaceAll(r'\', '/');
        if (ruta.endsWith('lib/services/image_compression.dart')) continue;

        final lineas = entidad.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          // Los comentarios de documentación citan la llamada vieja a
          // propósito, para explicar qué se cambió y por qué.
          if (lineas[i].trimLeft().startsWith('///')) continue;
          if (llamada.hasMatch(lineas[i])) {
            infractores.add('$ruta:${i + 1} -> ${lineas[i].trim()}');
          }
        }
      }

      expect(
        infractores,
        isEmpty,
        reason:
            'Hay una llamada suelta a ImagePicker. Si se abre el selector sin '
            'los límites de image_compression.dart, la foto sube sin comprimir '
            '(TL-20): usa elegirImagenComprimida().\n${infractores.join('\n')}',
      );
    });

    test('los cinco servicios de subida usan la política única', () {
      const servicios = <String>[
        'blog_cover_upload_service',
        'stylist_photo_upload_service',
        'tenant_cover_upload_service',
        'tenant_logo_upload_service',
        'work_photos_upload_service',
      ];

      for (final servicio in servicios) {
        final fuente = File('lib/services/$servicio.dart').readAsStringSync();

        expect(
          fuente.contains("import 'image_compression.dart';"),
          isTrue,
          reason: '$servicio.dart ya no importa la política de compresión.',
        );
        expect(
          fuente.contains('elegirImagenComprimida()'),
          isTrue,
          reason:
              '$servicio.dart abre el selector por su cuenta. La política de '
              'compresión vive en un solo sitio a propósito (lección de D-198: '
              'tres cifras copiadas cinco veces son cuatro sitios donde una se '
              'queda atrás).',
        );
      }
    });
  });
}
