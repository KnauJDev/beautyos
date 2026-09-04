import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato entre Flutter y el SQL para las fechas del Tablero (D-203).
///
/// **Por qué existe esta prueba, en una frase:** durante dos semanas y media
/// la pantalla de Tickets llamó a `get_ticket_board_list_v2` con las fechas en
/// nulo, esa RPC las rechaza desde que existe, y **nadie se enteró** porque un
/// `catch (_)` se tragaba el error y caía a otra RPC. Al retirar ese `catch`
/// (D-199), Tickets se cayó en producción.
///
/// Ninguna de las pruebas que había podía verlo:
///
/// - Las de D-199 leen el código Dart y comprueban que el `catch` no está.
///   Eso seguía siendo cierto — y la pantalla igualmente rota.
/// - Los controles SQL prueban la RPC contra la base, pero **nadie comprobaba
///   que Flutter la llamara como la RPC exige**. El contrato estaba escrito en
///   dos archivos que ninguna prueba leía a la vez.
///
/// Esta sí: lee **los dos lados** y los compara. Es la prueba que habría
/// cazado el fallo el mismo día que se escribió.
///
/// Cubre **las dos** funciones del Tablero (D-147). La de conteos entró en la
/// lista al escribir esto: se descubrió que rechaza los nulos igual que la de
/// listado, así que el mismo error cabía ahí y nadie lo estaba mirando.
void main() {
  /// Cada RPC del Tablero con la migración donde vive su versión vigente.
  ///
  /// La de listado la reescribió D-150 para añadir el número de venta, así que
  /// su versión viva está en la migración de septiembre, no en la de agosto.
  const rpcsDelTablero = <String, String>{
    'get_ticket_board_list_v2':
        'supabase/migrations/20260817210000_numero_de_venta_por_sede.sql',
    'get_ticket_board_counts_v2':
        'supabase/migrations/20260817170000_tablero_agenda_conteos_y_lista.sql',
  };

  group('D-203 — Nadie llama al Tablero con fechas nulas', () {
    for (final entrada in rpcsDelTablero.entries) {
      final rpc = entrada.key;
      final migracion = entrada.value;

      test('$rpc sigue rechazando las fechas nulas en el SQL', () {
        // Si algún día una migración hace que la RPC acepte nulos como "sin
        // límite", esta prueba falla y avisa de que la de abajo ya no hace
        // falta. Mientras el rechazo esté ahí, Flutter tiene que respetarlo.
        final sql = File(migracion).readAsStringSync();

        expect(
          sql,
          contains('p_start_date is null or p_end_date is null'),
          reason:
              '$rpc ya no rechaza las fechas nulas en $migracion. Si se cambió '
              'a propósito (para que null signifique "sin límite"), estas '
              'pruebas se pueden retirar, y el hotfix de D-203 se puede '
              'revertir para volver a la RPC del Tablero, que trae el número '
              'de venta y el teléfono. Si cambió por accidente, es un fallo: '
              'revísalo antes de tocar la prueba.',
        );
      });
    }

    test('ningún archivo de lib/ le manda fechas nulas', () {
      final infractores = <String>[];

      for (final entidad in Directory('lib').listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

        final ruta = entidad.path.replaceAll(r'\', '/');
        final fuente = entidad
            .readAsLinesSync()
            // Los comentarios de documentación cuentan esta historia a
            // propósito, citando la llamada vieja. No son llamadas.
            .where((linea) => !linea.trimLeft().startsWith('//'))
            .join('\n');

        for (final rpc in rpcsDelTablero.keys) {
          for (final llamada in rpc.allMatches(fuente)) {
            // Los parámetros van justo después del nombre de la RPC. 400
            // caracteres cubren de sobra el mapa de `params`.
            final hasta = (llamada.end + 400).clamp(0, fuente.length);
            final parametros = fuente.substring(llamada.end, hasta);

            for (final fecha in ['p_start_date', 'p_end_date']) {
              if (RegExp("'$fecha'\\s*:\\s*null").hasMatch(parametros)) {
                infractores.add('$ruta · $rpc · $fecha: null');
              }
            }
          }
        }
      }

      expect(
        infractores,
        isEmpty,
        reason:
            'Hay una llamada al Tablero con la fecha en nulo. Esas RPC lanzan '
            '"Rango de fechas invalido." y la pantalla se cae. Es exactamente '
            'el fallo que tumbó Tickets en producción el 04-sep, y que estuvo '
            'escondido dos semanas y media detrás de un catch ciego:\n'
            '${infractores.join('\n')}',
      );
    });
  });
}
