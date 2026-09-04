import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián de la jerga técnica en pantalla (D-206).
///
/// **Qué pasó.** La fase de prototipo dejó tarjetas fijas en la cabecera de
/// nueve pantallas con títulos como *"Catálogo de servicios conectado a
/// Supabase"* o *"Reseñas conectadas con Supabase"*, y dos textos de carga que
/// decían *"Cargando tickets desde Supabase..."*. A un salón le da igual dónde
/// esté la base de datos: solo aprende que hay una palabra rara que no
/// entiende y que no puede hacer nada al respecto.
///
/// **Por qué una prueba y no solo el borrado.** Esos textos llegaron a
/// producción y estuvieron meses ahí sin que nadie los viera como un problema,
/// porque cada uno por separado parece inofensivo. Es la misma enfermedad que
/// D-102 vigila con los colores sueltos: lo que no tiene guardián, vuelve.
///
/// **Lo que esta prueba NO hace:** juzgar el resto del texto. Solo vigila el
/// nombre del proveedor de base de datos, que es el que se coló nueve veces.
void main() {
  /// Sitios donde nombrar a Supabase es correcto, con su porqué.
  ///
  /// **La lista es corta a propósito.** Si crece, la pregunta no es cómo
  /// añadir una excepción: es por qué la aplicación le está contando a un
  /// salón cómo está construida por dentro.
  ///
  /// **Bajó de tres a una en D-208.** `settings_page` e `inventory_page`
  /// estaban aquí porque sus descripciones de error decían *"Revisa la
  /// conexión con Supabase o la función `get_business_settings`"*. Al
  /// reescribirlas en el idioma del salón, sus excepciones quedaron muertas —
  /// y la prueba de abajo lo detectó sola, citando el motivo que tenían.
  const permitidos = <String, String>{
    'lib/pages/terms_and_privacy_page.dart':
        'Declaración legal: Supabase figura como encargado del tratamiento de '
        'datos (Ley 1581, D-144). Quitarlo de ahí sería una regresión de '
        'cumplimiento, no una limpieza.',
  };

  test('ninguna pantalla nueva le enseña "Supabase" al salón', () {
    // Solo texto entre comillas simples, que es lo que acaba en la pantalla.
    // El código (`Supabase.instance.client`) y los comentarios no cuentan.
    final literal = RegExp(r"'[^']*Supabase[^']*'");
    final infractores = <String>[];

    for (final entidad in Directory('lib').listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

      final ruta = entidad.path.replaceAll(r'\', '/');
      // Los servicios hablan con la base: ahí el nombre es inevitable, y no
      // es texto de pantalla.
      if (ruta.startsWith('lib/services/')) continue;
      if (permitidos.containsKey(ruta)) continue;

      final lineas = entidad.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (linea.trimLeft().startsWith('//')) continue;
        if (linea.contains('Supabase.instance')) continue;

        if (literal.hasMatch(linea)) {
          infractores.add('$ruta:${i + 1} -> ${linea.trim()}');
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Hay texto de pantalla que nombra a Supabase. A un salón le da igual '
          'dónde esté la base de datos: si el mensaje tiene que decir algo, '
          'que lo diga en su idioma ("No se pudo conectar", "Vuelve a '
          'intentarlo"). Si de verdad hay una razón, añádela a `permitidos` '
          'con su porqué:\n${infractores.join('\n')}',
    );
  });

  test('las excepciones siguen existiendo y siguen haciendo falta', () {
    // Una excepción que ya no se usa es peor que no tenerla: hace creer que
    // el texto sigue ahí cuando puede haberse borrado hace meses.
    final literal = RegExp(r"'[^']*Supabase[^']*'");

    for (final entrada in permitidos.entries) {
      final fichero = File(entrada.key);
      expect(
        fichero.existsSync(),
        isTrue,
        reason: 'La excepción ${entrada.key} apunta a un archivo que ya no existe.',
      );
      expect(
        literal.hasMatch(fichero.readAsStringSync()),
        isTrue,
        reason:
            '${entrada.key} ya no nombra a Supabase en ningún texto, así que '
            'su excepción sobra y se puede quitar de esta prueba. Motivo que '
            'tenía: ${entrada.value}',
      );
    }
  });

  test('ninguna pantalla le enseña al salón el nombre de una función', () {
    // **Lee los dos lados y los compara** (D-208), como
    // `contrato_rpc_fechas_test.dart` (D-203) y `sesion_fresca_test.dart`
    // (D-207): saca de las migraciones **todas** las funciones que existen y
    // comprueba que ninguna aparece en un texto de pantalla.
    //
    // Se hace así, y no con una lista de dos o tres nombres a mano, porque el
    // proyecto tiene 219 funciones y mañana tendrá más. Una lista escrita a
    // mano solo vigila lo que ya se rompió una vez.
    final declaradas = <String>{};
    final declaracion = RegExp(
      r'create\s+or\s+replace\s+function\s+(?:public|private)\.([a-z0-9_]+)',
      caseSensitive: false,
      multiLine: true,
    );

    for (final entidad in Directory('supabase/migrations').listSync()) {
      if (entidad is! File || !entidad.path.endsWith('.sql')) continue;
      for (final m in declaracion.allMatches(entidad.readAsStringSync())) {
        final nombre = m.group(1)!;
        // Un nombre corto o sin guión bajo podría chocar con una palabra
        // normal del texto. Los del proyecto son todos largos y con guión.
        if (nombre.length >= 8 && nombre.contains('_')) declaradas.add(nombre);
      }
    }

    expect(
      declaradas.length,
      greaterThan(50),
      reason:
          'Se leyeron solo ${declaradas.length} funciones de las migraciones. '
          'Si cambió la forma de declararlas, esta prueba dejó de vigilar '
          'casi nada y hay que arreglarla antes de fiarse de que pasa.',
    );

    final literal = RegExp("'([^']*)'");
    final infractores = <String>[];

    for (final entidad in Directory('lib/pages').listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

      final ruta = entidad.path.replaceAll(r'\', '/');
      final lineas = entidad.readAsLinesSync();

      for (var i = 0; i < lineas.length; i++) {
        final recortada = lineas[i].trimLeft();
        if (recortada.startsWith('//')) continue;
        // Las rutas de import son cadenas, pero no son texto de pantalla, y
        // un archivo puede llamarse como una función (create_branch_dialog).
        if (recortada.startsWith('import') || recortada.startsWith('export')) {
          continue;
        }

        for (final m in literal.allMatches(lineas[i])) {
          final texto = m.group(1)!;
          for (final funcion in declaradas) {
            if (texto.contains(funcion)) {
              infractores.add('$ruta:${i + 1} -> $funcion');
            }
          }
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Hay texto en una pantalla que nombra una función de la base. A un '
          'salón no le sirve de nada saber que falló `get_business_settings`: '
          'no puede hacer nada con eso, y solo aprende que la aplicación está '
          'rota por dentro. Dile qué puede hacer él ("Revisa tu conexión a '
          'internet o intenta nuevamente más tarde"). Y si esto saltó porque '
          'una página llama a una RPC directamente, el sitio de esa llamada '
          'es un servicio de `lib/services/`, no la pantalla:\n'
          '${infractores.join('\n')}',
    );
  });
}
