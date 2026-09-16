import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián del maestro-detalle del Panel de Plataforma (D-239).
///
/// EL FALLO QUE VIGILA, QUE SERÍA INVISIBLE
///
/// Con la ficha empotrada a la derecha, pasar de un negocio a otro **no
/// desmonta el widget**: Flutter reaprovecha el estado si el tipo coincide, y
/// `initState` no vuelve a correr. Como es ahí donde se piden las sedes y el
/// historial, verías **las sedes y los pagos del negocio anterior bajo el
/// nombre del nuevo**.
///
/// No daría error. No habría nada en rojo. Solo estarías mirando el dinero de
/// otro cliente creyendo que es de este — y con el cobro yendo por sede, eso
/// es exactamente la decisión que no se puede tomar con datos prestados.
///
/// Lo evita una `ValueKey` con el identificador del negocio. Es una línea, y
/// una línea que nadie echaría de menos al refactorizar.
///
/// Es el mismo fallo que D-211, que ya costó una vez: un `FutureBuilder` que
/// creaba su futuro en el `build` y lo relanzaba en cada repintado.
///
/// LO QUE ESTA PRUEBA **NO** DEMUESTRA: que la ficha pinte bien. Eso se mira
/// en pantalla. Demuestra que la llave sigue puesta.
void main() {
  /// Lee el archivo sin comentarios de línea, para que una mención dentro de
  /// una explicación no satisfaga la búsqueda. (Ver `sede_creada_se_ve_test`:
  /// esa comprobación dio verde con la llamada comentada.)
  String leerCodigo(String ruta) {
    final archivo = File(ruta);
    expect(archivo.existsSync(), isTrue, reason: 'No existe $ruta.');
    return archivo
        .readAsLinesSync()
        .where((linea) => !linea.trimLeft().startsWith('//'))
        .join('\n');
  }

  const ruta = 'lib/pages/platform_panel_page.dart';

  test('la ficha se reconstruye al cambiar de negocio', () {
    final fuente = leerCodigo(ruta);

    expect(
      fuente.contains("key: ValueKey('ficha-\${tenant.tenantId}')"),
      isTrue,
      reason:
          'La ficha del negocio perdió su ValueKey por identificador. Sin '
          'ella, al pasar de un negocio a otro en el panel derecho se '
          'reaprovecha el estado anterior: verías las sedes y el historial '
          'del negocio previo bajo el nombre del nuevo, sin ningún error '
          'que lo delate (D-239, y antes D-211).',
    );
  });

  test('la ficha se construye en un solo sitio', () {
    final fuente = leerCodigo(ruta);

    // La declaración de la clase no cuenta: se busca la LLAMADA.
    final llamadas = RegExp(
      r'_TenantDetailSheet\(',
    ).allMatches(fuente).length;
    final declaracion = RegExp(
      r'const _TenantDetailSheet\(',
    ).allMatches(fuente).length;

    expect(
      llamadas - declaracion,
      1,
      reason:
          'Hay ${llamadas - declaracion} sitios que construyen la ficha del '
          'negocio y debería haber uno solo (`_fichaDeNegocio`). Dos casas '
          'para la misma ficha fue justo el problema que D-239 vino a '
          'resolver, y un segundo constructor es por donde se cuela una '
          'copia sin ValueKey o sin la mitad de los callbacks.',
    );
  });

  test('la columna estrecha no lleva botones de gestión', () {
    final fuente = leerCodigo(ruta);

    expect(
      fuente.contains('final bool compacto;'),
      isTrue,
      reason:
          'Desapareció el modo compacto de la tarjeta. En la columna '
          'izquierda del maestro-detalle la fila de botones no cabe --se '
          'desborda-- y además un botón que toca dinero desde una fila de '
          'lista no deja ver a quién se lo estás tocando (D-239).',
    );
  });
}
