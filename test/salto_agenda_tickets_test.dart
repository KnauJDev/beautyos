import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián del salto Agenda → Tickets (C-03, D-199).
///
/// **Qué protege.** Desde D-163 la tarjeta de una cita en Agenda abre la Ficha
/// Completa en Tickets, y D-195 añadió el botón "Cobrar" por el mismo camino.
/// Los dos saltan con `selectedIndex = selectedIndex + 1`, o sea: **dan por
/// hecho que Tickets es el módulo inmediatamente siguiente a Agenda**, en la
/// lista ya filtrada por rol.
///
/// **Por qué hacía falta una prueba.** Esa adyacencia estaba solo escrita en
/// un comentario de `main.dart`. Basta con que alguien meta un módulo nuevo
/// entre los dos, o que le quite el rol `assistant` a Tickets, para que el
/// botón "Cobrar" de una recepcionista abra Clientes. **No revienta nada, no
/// sale ningún error: simplemente se abre la pantalla equivocada.** Un fallo
/// silencioso no lo encuentra nadie hasta que un cliente lo reporta.
///
/// **Por qué se lee el código fuente y no se construye la lista.**
/// `_modulesForProfile` es privado del `State` de la pantalla principal y
/// arma páginas reales (`AgendaPage`, `TicketsPage`), que necesitan sesión de
/// Supabase. Leer la fuente es el mismo recurso que ya usa
/// `sin_colores_sueltos_test.dart` (D-102) para vigilar una convención que no
/// se puede comprobar en tiempo de ejecución.
void main() {
  group('C-03 — Agenda y Tickets siguen siendo adyacentes (D-163, D-195)', () {
    late String listaDeModulos;
    late List<String> titulos;
    late List<Set<String>> rolesPermitidos;
    late String fuenteCompleta;

    setUpAll(() {
      fuenteCompleta = File('lib/main.dart').readAsStringSync();

      // Solo interesa el literal de lista de `_modulesForProfile`, no el resto
      // del archivo: `BeautySection` también aparece en `conCandado()`.
      const anclaInicio = 'modules = <BeautyModule>[';
      const anclaFin = '\n    ];';

      final inicio = fuenteCompleta.indexOf(anclaInicio);
      expect(
        inicio,
        isNonNegative,
        reason:
            'No se encontró "$anclaInicio" en lib/main.dart. Si la lista de '
            'módulos se reorganizó, hay que actualizar esta prueba ANTES de '
            'darla por buena: sin ella el salto de D-163 queda sin vigilancia.',
      );

      final fin = fuenteCompleta.indexOf(anclaFin, inicio);
      expect(fin, isNonNegative, reason: 'No se encontró el cierre de la lista.');

      listaDeModulos = fuenteCompleta.substring(inicio, fin);

      titulos = RegExp(r"BeautySection\(\s*'([^']+)'")
          .allMatches(listaDeModulos)
          .map((m) => m.group(1)!)
          .toList();

      rolesPermitidos = RegExp(r'allowedRoles:\s*(?:const\s*)?<String>\{([^}]*)\}')
          .allMatches(listaDeModulos)
          .map(
            (m) => RegExp(r"'([^']+)'")
                .allMatches(m.group(1)!)
                .map((r) => r.group(1)!)
                .toSet(),
          )
          .toList();
    });

    test('cada módulo declara exactamente un título y un juego de roles', () {
      // Si esto falla, el emparejamiento título↔roles de las pruebas de abajo
      // deja de ser fiable y hay que revisar los patrones antes que nada.
      expect(titulos, isNotEmpty);
      expect(
        rolesPermitidos.length,
        titulos.length,
        reason:
            'Se leyeron ${titulos.length} títulos y ${rolesPermitidos.length} '
            'juegos de roles en la lista de módulos. Deberían ser iguales: '
            'cada BeautyModule lleva un section y un allowedRoles.',
      );
    });

    test('Tickets & Caja va justo después de Agenda', () {
      final indiceAgenda = titulos.indexOf('Agenda');
      expect(
        indiceAgenda,
        isNonNegative,
        reason: 'No hay ningún módulo titulado "Agenda" en lib/main.dart.',
      );

      expect(
        titulos.length,
        greaterThan(indiceAgenda + 1),
        reason: 'Agenda es el último módulo: no hay nada en selectedIndex + 1.',
      );

      expect(
        titulos[indiceAgenda + 1],
        'Tickets & Caja',
        reason:
            'Agenda salta a Tickets con selectedIndex + 1 (D-163 y D-195). '
            'Ahora mismo el módulo siguiente es "${titulos[indiceAgenda + 1]}", '
            'así que el botón "Cobrar" y la Ficha Completa abren esa pantalla '
            'en vez de Tickets. Orden actual:\n  ${titulos.join('\n  ')}',
      );
    });

    test('todo rol que ve Agenda ve también Tickets', () {
      // Esta es la mitad que se rompe sin que se note. La lista se filtra por
      // rol ANTES de navegar (`modules.where((m) => m.canAccess(role))`), así
      // que si un rol ve Agenda pero no Tickets, Tickets desaparece de la
      // lista y selectedIndex + 1 cae en el módulo de más allá.
      final indiceAgenda = titulos.indexOf('Agenda');
      final rolesAgenda = rolesPermitidos[indiceAgenda];
      final rolesTickets = rolesPermitidos[indiceAgenda + 1];

      expect(
        rolesTickets.containsAll(rolesAgenda),
        isTrue,
        reason:
            'Hay roles que ven Agenda y no ven Tickets: '
            '${rolesAgenda.difference(rolesTickets)}. Para ellos Tickets no '
            'está en la lista filtrada y selectedIndex + 1 abre otra pantalla.',
      );
    });

    test('el salto sigue apoyándose en el índice siguiente', () {
      // **Actualizada en D-201, y la prueba hizo justo lo que tenía que
      // hacer.** Hasta el 02-sep el salto era `selectedIndex = selectedIndex
      // + 1` escrito a mano en los dos callbacks de Agenda. D-201 los mandó
      // por el embudo `_irAIndice`, así que aquella cadena desapareció y esta
      // prueba falló — obligando a decidir a conciencia si C-03 seguía vivo.
      //
      // Sigue vivo: `_irAIndice(selectedIndex + 1)` se apoya en la adyacencia
      // exactamente igual que antes. Lo que cambió es la forma, no la
      // dependencia. Si algún día el salto busca el módulo por su título
      // (como hace el Dashboard desde D-168), entonces sí, esta prueba entera
      // se puede retirar.
      expect(
        fuenteCompleta.contains('_irAIndice(selectedIndex + 1)'),
        isTrue,
        reason:
            'Ya no hay ningún "_irAIndice(selectedIndex + 1)" en lib/main.dart. '
            'Si el salto Agenda → Tickets ahora busca el módulo por su título, '
            'esta prueba sobra y se puede borrar entera (C-03 quedaría cerrado '
            'por construcción). Si se borró por error, es un fallo: revísalo '
            'antes de tocar la prueba.',
      );
    });
  });
}
