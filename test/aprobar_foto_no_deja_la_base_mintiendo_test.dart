import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-284 (hallazgo BW): aprobar una foto anota "publicada" en la base y
/// DESPUÉS mueve el archivo. El 27-sep el movimiento falló por un permiso
/// roto y la base se quedó diciendo "publicada" con el archivo en el almacén
/// privado: el cuadro roto del portafolio.
///
/// **Qué vigila esta prueba y qué no.** Lee el código: no puede probar que
/// la vuelta atrás funcione contra Supabase -- eso lo prueba la pantalla
/// (regla 21) y la lección de D-203 es no fingir lo contrario. Lo que sí
/// garantiza es que nadie la quite sin enterarse: si mover (D-285) deja de ir
/// dentro de un `try` que vuelve a `p_approved: false`, falla.
void main() {
  test('si mover el archivo falla, la aprobación se deshace', () {
    final fuente = File('lib/services/work_photos_service.dart')
        .readAsLinesSync()
        .where((linea) => !linea.trimLeft().startsWith('//'))
        .join('\n');

    final inicio = fuente.indexOf('Future<void> setPortfolioApproval(');
    expect(inicio, isNot(-1), reason: 'No se encontró setPortfolioApproval.');
    final fin = fuente.indexOf("await _moverEnServidor(photoId, 'privado')", inicio);
    final aprobar = fuente.substring(inicio, fin);

    final publicar = aprobar.indexOf("await _moverEnServidor(photoId, 'publico')");
    expect(publicar, isNot(-1));

    final antes = aprobar.substring(0, publicar);
    final despues = aprobar.substring(publicar);
    expect(antes.trimRight(), endsWith('try {'),
        reason: 'Mover el archivo tiene que ir dentro de un try.');
    expect(despues, contains("'p_approved': false"),
        reason: 'Si mover falla, la base tiene que volver a "no publicada".');
    expect(despues, contains('rethrow'),
        reason: 'Y el salón tiene que enterarse del fallo original.');
  });
}
