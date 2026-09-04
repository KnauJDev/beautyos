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
  const permitidos = <String, String>{
    'lib/pages/terms_and_privacy_page.dart':
        'Declaración legal: Supabase figura como encargado del tratamiento de '
        'datos (Ley 1581, D-144). Quitarlo de ahí sería una regresión de '
        'cumplimiento, no una limpieza.',
    'lib/pages/settings_page.dart':
        'Descripciones de error que orientan a quien depura ("Revisa la '
        'conexión con Supabase o la función get_business_settings"). Son '
        'estados de fallo, no cabecera. Reescribirlas en el idioma del salón '
        'es un trabajo aparte que D-206 dejó anotado.',
    'lib/pages/inventory_page.dart':
        'Misma razón que settings_page: una descripción de error, no una '
        'tarjeta de cabecera.',
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
}
