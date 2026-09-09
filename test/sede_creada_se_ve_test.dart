import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián de la regla 16-ter en el camino de crear una sede (D-238).
///
/// EL FALLO QUE VIGILA
///
/// Configuración enseñaba «Sede creada» y no recargaba nada. La sede quedaba
/// escrita en la base y **no existía en la pantalla**: el propietario creó
/// «Barberia Barber Elite», la vio en el Panel de Plataforma, y desde su
/// propia aplicación no había forma de llegar a ella.
///
/// Y era peor que una lista desactualizada. El selector de sedes solo se
/// convierte en menú cuando hay más de una (`branches.length > 1`): con una
/// sola es una **etiqueta muerta**, sin flecha y sin nada que pulsar. Así que
/// no es que la sede nueva faltara en una lista desplegable; es que no había
/// lista desplegable que abrir.
///
/// POR QUÉ SE VIGILA LEYENDO EL CÓDIGO
///
/// El compilador ya obliga a **pasar** `onSedeCreada`, pero no obliga a
/// llamarlo ni a que haga algo. Un refactor que se lleve la llamada, o que
/// deje el callback vacío, compila y pasa las 391 pruebas. Es el mismo tipo de
/// invariante que vigilan `sin_colores_sueltos_test` y `web_headers_security_test`:
/// no se puede montar el árbol entero en una prueba, pero sí se puede exigir
/// que las dos mitades del cable sigan conectadas.
///
/// LO QUE ESTA PRUEBA **NO** DEMUESTRA: que la recarga funcione. Eso se
/// verificó a mano contra la base real. Lo que demuestra es que nadie
/// desconectó el cable sin darse cuenta.
void main() {
  /// Lee el archivo **sin sus comentarios de línea**.
  ///
  /// No es un detalle: la primera versión de esta prueba buscaba
  /// `onSedeCreada()` con `contains` y **daba verde con la llamada comentada**.
  /// Un comentario que menciona lo que hay que hacer satisface la búsqueda
  /// igual que hacerlo. Ya pasó una vez en este proyecto, verificando un
  /// precio contra un `50.00` que estaba escrito dentro de una explicación.
  String leerCodigo(String ruta) {
    final archivo = File(ruta);
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'No existe $ruta. Si se movió, hay que mover esta prueba con él.',
    );
    return archivo
        .readAsLinesSync()
        .where((linea) => !linea.trimLeft().startsWith('//'))
        .join('\n');
  }

  test('crear una sede avisa a quien tiene la lista de sedes', () {
    final fuente = leerCodigo('lib/pages/settings_page.dart');

    final inicio = fuente.indexOf('class _SedesCard');
    expect(
      inicio,
      greaterThan(-1),
      reason:
          '_SedesCard es el único punto de entrada a CreateBranchDialog '
          '(D-161). Si cambió de nombre, esta prueba dejó de vigilar nada.',
    );

    // El final del archivo sirve de tope: _SedesCard es la última clase, y si
    // dejara de serlo el trozo solo sería más grande, nunca más pequeño.
    final tarjeta = fuente.substring(inicio);

    expect(
      tarjeta.contains('CreateBranchDialog'),
      isTrue,
      reason: 'La tarjeta de sedes ya no abre el diálogo de crear sede.',
    );

    expect(
      tarjeta.contains('onSedeCreada()'),
      isTrue,
      reason:
          'La tarjeta de sedes abre el diálogo de crear sede y NO llama a '
          'onSedeCreada(). Vuelve el fallo de D-238: la sede se guarda, el '
          'aviso dice que ya se puede usar, y el selector de arriba ni se '
          'entera. Con una sola sede ese selector ni siquiera es un menú.',
    );
  });

  test('quien recibe el aviso recarga de verdad el contexto', () {
    final fuente = leerCodigo('lib/main.dart');

    final inicio = fuente.indexOf('onSedeCreada:');
    expect(
      inicio,
      greaterThan(-1),
      reason:
          'main.dart ya no le pasa onSedeCreada a ConfiguracionPage. Es el '
          'único sitio donde vive la lista de sedes (_loadHomeContext).',
    );

    // Basta con mirar las líneas siguientes: el callback es corto a propósito.
    final tramo = fuente.substring(
      inicio,
      (inicio + 400).clamp(0, fuente.length),
    );

    expect(
      tramo.contains('homeContextFuture = _loadHomeContext()'),
      isTrue,
      reason:
          'onSedeCreada existe pero no rehace homeContextFuture. Un callback '
          'que no recarga nada es peor que no tenerlo: la pantalla promete '
          'algo (regla 16-ter) y encima ahora parece que alguien se ocupó.',
    );
  });
}
