import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián de los dos hallazgos de Tickets del Bloque 5 (D-199).
///
/// **TL-16 — el `catch (_)` ciego.** `getTicketsSummary` envolvía la llamada a
/// `get_ticket_board_list_v2` en un `catch (_)` que caía a
/// `get_tickets_summary_v2` ante *cualquier* excepción. Un fallo de red o un
/// rechazo de permisos de sede quedaba tragado y la pantalla enseñaba el
/// respaldo sin avisar: nadie se enteraba de que algo iba mal.
///
/// **TL-09 — la lista se construía entera.** El historial llega sin filtro de
/// fechas (`p_start_date: null, p_end_date: null`) y se pintaba completo con
/// un `...filteredTickets.map(` dentro de una `Column`: un `TicketRow` por
/// ticket, todos en memoria, aunque en pantalla se vieran ocho.
///
/// **Por qué se lee el código fuente.** Las dos correcciones viven dentro de
/// código que necesita sesión de Supabase — `getTicketsSummary` llama a la
/// base, y el `build` de `TicketsPage` cuelga de un `FutureBuilder` sobre esa
/// llamada — así que no hay forma de ejercitarlas en `flutter test` sin montar
/// una inyección de dependencias que hoy no existe. Lo que sí se puede vigilar
/// es que ninguna de las dos vuelva sola. Mismo recurso que
/// `sin_colores_sueltos_test.dart` (D-102).
void main() {
  group('TL-16 — Los errores de Tickets ya no se tragan', () {
    late String fuente;

    setUpAll(() {
      // Solo código: los comentarios de documentación citan a propósito el
      // `catch (_)` y el respaldo que este bloque retiró, para dejar escrito
      // qué se cambió y por qué. Si no se filtran, la prueba se detecta a sí
      // misma y falla por su propia explicación.
      fuente = File('lib/services/tickets_service.dart')
          .readAsLinesSync()
          .where((linea) => !linea.trimLeft().startsWith('//'))
          .join('\n');
    });

    test('no queda ningún catch ciego en TicketsService', () {
      final ciegos = RegExp(r'catch\s*\(\s*_\s*\)').allMatches(fuente).length;

      expect(
        ciegos,
        0,
        reason:
            'Hay $ciegos "catch (_)" en tickets_service.dart. Un catch ciego '
            'aquí convierte "se cayó la red" y "no tienes permiso en esta '
            'sede" en "no hay tickets" (TL-16). Si de verdad hace falta '
            'atrapar algo, atrapa el tipo concreto y déjalo dicho.',
      );
    });

    test('getTicketsSummary ya no cae al respaldo get_tickets_summary_v2', () {
      expect(
        fuente.contains('get_ticket_board_list_v2'),
        isTrue,
        reason: 'La llamada al tablero desapareció de TicketsService.',
      );
      expect(
        fuente.contains('get_tickets_summary_v2'),
        isFalse,
        reason:
            'Volvió el respaldo a get_tickets_summary_v2. Existía solo para '
            'cubrir la migración a get_ticket_board_list_v2 (D-147), y lo que '
            'hacía de verdad era esconder el error real.',
      );
    });
  });

  group('TL-09 — La lista de tickets no se construye entera', () {
    late String fuente;

    setUpAll(() {
      fuente = File('lib/pages/tickets_page.dart').readAsStringSync();
    });

    test('la lista se pinta por tandas de 10', () {
      expect(
        fuente.contains('static const int _ticketsPorTanda = 10;'),
        isTrue,
        reason:
            'Cambió el tamaño de la tanda. No es un error por sí mismo, pero '
            'es una decisión de producto (D-199, elegida por el propietario): '
            'si se cambia, se cambia también aquí y se deja escrito por qué.',
      );
    });

    test('no se recorre la lista filtrada completa', () {
      expect(
        fuente.contains('...filteredTickets.map('),
        isFalse,
        reason:
            'Volvió el "...filteredTickets.map(" dentro de la Column: eso '
            'construye un TicketRow por cada ticket del historial (TL-09). '
            'La lista tiene que recorrer ticketsALaVista, que es la tanda.',
      );
      expect(
        fuente.contains('...ticketsALaVista.map('),
        isTrue,
        reason: 'La lista ya no recorre la tanda visible.',
      );
    });

    test('todo setState que toca un filtro reinicia la paginación', () {
      // Es lo que más fácil se olvida al añadir un filtro nuevo: sin esto,
      // alguien que amplió la lista a 60 y después busca por nombre sigue
      // viendo un tope de 60 sobre un resultado de 3.
      final tocaUnFiltro = RegExp(
        r'_(searchQuery|selectedDateFilter|selectedStateFilter|'
        r'selectedStylist|customDateRange) = ',
      );
      final saltoDeLinea = RegExp(r'\n');

      final olvidadizos = <String>[];

      for (final apertura in 'setState(() {'.allMatches(fuente)) {
        final desde = apertura.end;
        final hasta = fuente.indexOf('});', desde);
        if (hasta == -1) continue;

        final cuerpo = fuente.substring(desde, hasta);
        if (!tocaUnFiltro.hasMatch(cuerpo)) continue;
        if (cuerpo.contains('_reiniciarPaginacion()')) continue;

        final linea =
            saltoDeLinea.allMatches(fuente.substring(0, desde)).length + 1;
        olvidadizos.add('tickets_page.dart:$linea');
      }

      expect(
        olvidadizos,
        isEmpty,
        reason:
            'Estos setState cambian un filtro sin devolver la lista al tope '
            'inicial, así que el tope de la búsqueda anterior se arrastra al '
            'resultado nuevo: ${olvidadizos.join(', ')}',
      );
    });
  });
}
