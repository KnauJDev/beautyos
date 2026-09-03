import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/main.dart';

/// Pruebas del ciclo de vida de las pestañas (TL-10 y Hallazgo Q, D-201).
///
/// **Estas sí ejercitan el comportamiento**, no leen el código fuente como las
/// guardianas de D-199. Se pudo porque `pilaDeModulos` se dejó como función de
/// nivel superior y pura: entra una lista de módulos con sus contadores, sale
/// la lista de hijos del `IndexedStack`. No hace falta sesión de Supabase.
///
/// Lo que se mide es lo único que importa de este bloque: **cuántas veces
/// corre `initState`**. Ahí es donde cada una de las 16 páginas carga sus
/// datos, así que contar montajes es contar consultas a la base.
void main() {
  group('TL-10 — Un módulo no se construye hasta que se entra en él', () {
    testWidgets('lo que nadie ha abierto no llega a montarse', (tester) async {
      final montajes = <String, int>{};

      await tester.pumpWidget(
        _Pila(
          abiertos: const {0},
          visitas: const {},
          montajes: montajes,
          modulos: 3,
        ),
      );

      expect(
        montajes,
        {'pagina-0': 1},
        reason:
            'Solo el módulo abierto puede haber corrido su initState. Si '
            'aparecen los tres, IndexedStack volvió a construirlo todo y '
            'TL-10 está de vuelta: 16 initState y 16 consultas al entrar.',
      );
    });

    testWidgets('la pila conserva el largo aunque no se construya todo', (
      tester,
    ) async {
      // Invariante de IndexedStack: su `index` es una posición dentro de la
      // lista de hijos. Si los huecos no ocuparan sitio, entrar al módulo 5
      // enseñaría el que esté quinto entre los construidos, que es otro.
      final hijos = pilaDeModulos(
        modules: _modulos(4),
        pages: const [
          SizedBox(key: ValueKey('p0')),
          SizedBox(key: ValueKey('p1')),
          SizedBox(key: ValueKey('p2')),
          SizedBox(key: ValueKey('p3')),
        ],
        abiertos: {2},
        visitas: const {},
        indiceActual: 2,
      );

      expect(hijos.length, 4);
      expect(hijos[0], isA<SizedBox>());
      expect(hijos[2], isA<KeyedSubtree>());
    });

    testWidgets('el módulo visible se monta aunque nadie lo marcara', (
      tester,
    ) async {
      // La red del peor caso: si por cualquier camino el índice visible no
      // estuviera en `abiertos`, sin esto el usuario vería un
      // `SizedBox.shrink()` — la pantalla en blanco. Se construye igual.
      final montajes = <String, int>{};

      await tester.pumpWidget(
        _Pila(
          abiertos: const <int>{},
          visitas: const {},
          montajes: montajes,
          modulos: 2,
        ),
      );

      expect(
        montajes,
        {'pagina-0': 1},
        reason:
            'El módulo que se está viendo tiene que construirse pase lo que '
            'pase. Si no, la pantalla queda en blanco y no hay forma de '
            'salir de ahí salvo recargando.',
      );
    });

    testWidgets('entrar a un módulo nuevo lo monta, sin tocar los demás', (
      tester,
    ) async {
      final montajes = <String, int>{};

      await tester.pumpWidget(
        _Pila(
          abiertos: const {0},
          visitas: const {},
          montajes: montajes,
          modulos: 3,
        ),
      );
      expect(montajes, {'pagina-0': 1});

      // El usuario entra al módulo 1 por primera vez.
      await tester.pumpWidget(
        _Pila(
          abiertos: const {0, 1},
          visitas: const {1: 1},
          montajes: montajes,
          modulos: 3,
        ),
      );

      expect(
        montajes,
        {'pagina-0': 1, 'pagina-1': 1},
        reason:
            'El módulo 1 tiene que montarse una vez, y el 0 no puede volver '
            'a montarse: no se ha entrado en él.',
      );
    });
  });

  group('Hallazgo Q — Volver a entrar recarga los datos', () {
    testWidgets('una visita nueva vuelve a montar la página', (tester) async {
      final montajes = <String, int>{};

      await tester.pumpWidget(
        _Pila(
          abiertos: const {0, 1},
          visitas: const {0: 1, 1: 1},
          montajes: montajes,
          modulos: 2,
        ),
      );
      expect(montajes, {'pagina-0': 1, 'pagina-1': 1});

      // El usuario vuelve al módulo 0: sube su contador de visitas.
      await tester.pumpWidget(
        _Pila(
          abiertos: const {0, 1},
          visitas: const {0: 2, 1: 1},
          montajes: montajes,
          modulos: 2,
        ),
      );

      expect(
        montajes['pagina-0'],
        2,
        reason:
            'Este es el Hallazgo Q entero: volver a entrar tiene que remontar '
            'la página para que initState recargue los datos. Si sigue en 1, '
            'el módulo enseña lo que tenía de la vez anterior.',
      );
      expect(
        montajes['pagina-1'],
        1,
        reason: 'El módulo en el que no se ha entrado no se toca.',
      );
    });

    testWidgets('recargaAlEntrar: false conserva el estado de la página', (
      tester,
    ) async {
      // La excepción de Configuración: siete campos de texto en la propia
      // página. Perder lo escrito por ir a mirar la Agenda es peor que ver un
      // dato viejo en un formulario que se está editando de todas formas.
      final montajes = <String, int>{};

      await tester.pumpWidget(
        _Pila(
          abiertos: const {0},
          visitas: const {0: 1},
          montajes: montajes,
          modulos: 1,
          recargaAlEntrar: false,
        ),
      );
      expect(montajes, {'pagina-0': 1});

      await tester.pumpWidget(
        _Pila(
          abiertos: const {0},
          visitas: const {0: 2},
          montajes: montajes,
          modulos: 1,
          recargaAlEntrar: false,
        ),
      );

      expect(
        montajes['pagina-0'],
        1,
        reason:
            'Con recargaAlEntrar en false la llave no lleva el contador, así '
            'que la página no se remonta y no pierde lo que hubiera escrito.',
      );
    });

    test('un módulo recarga al entrar salvo que diga lo contrario', () {
      const normal = BeautyModule(
        section: BeautySection('X', Icons.abc),
        page: SizedBox(),
        allowedRoles: <String>{'owner'},
      );

      expect(
        normal.recargaAlEntrar,
        isTrue,
        reason:
            'El valor por defecto tiene que ser recargar: el Hallazgo Q dice '
            'que entrar a un módulo debe traer datos frescos. No recargar es '
            'la excepción, y una excepción se escribe a mano.',
      );
    });
  });

  group('D-201 — Un solo camino para cambiar de pestaña', () {
    test('nadie escribe selectedIndex fuera del embudo', () {
      // La carga perezosa y el refresco dependen de que TODA navegación pase
      // por `_irAIndice`: un camino que no marque el módulo como abierto deja
      // la pantalla en blanco, y uno que no cuente la visita deja datos
      // viejos. Antes de D-201 había cuatro caminos sueltos.
      final fuente = File('lib/main.dart').readAsLinesSync();
      final asignaciones = <String>[];

      var dentroDelEmbudo = false;
      for (var i = 0; i < fuente.length; i++) {
        final linea = fuente[i];

        if (linea.contains('void _irAIndice(int index)')) {
          dentroDelEmbudo = true;
          continue;
        }
        // El embudo es corto: se cierra en su propio `}` a dos niveles.
        if (dentroDelEmbudo && linea == '  }') {
          dentroDelEmbudo = false;
          continue;
        }
        if (dentroDelEmbudo) continue;
        if (linea.trimLeft().startsWith('//')) continue;
        // La declaración del campo no es navegación.
        if (linea.contains('int selectedIndex')) continue;

        if (RegExp(r'(?<!\w)selectedIndex\s*=(?!=)').hasMatch(linea)) {
          asignaciones.add('main.dart:${i + 1} -> ${linea.trim()}');
        }
      }

      expect(
        asignaciones,
        isEmpty,
        reason:
            'Hay quien cambia de pestaña sin pasar por _irAIndice(). Ese '
            'camino no marca el módulo como abierto ni cuenta la visita, así '
            'que abrirá una pantalla en blanco o con datos viejos:\n'
            '${asignaciones.join('\n')}',
      );
    });
  });
}

/// Módulos de mentira, con lo justo para que `pilaDeModulos` decida.
List<BeautyModule> _modulos(int cuantos, {bool recargaAlEntrar = true}) {
  return List<BeautyModule>.generate(
    cuantos,
    (i) => BeautyModule(
      section: BeautySection('Modulo $i', Icons.abc),
      page: const SizedBox(),
      allowedRoles: const <String>{'owner'},
      recargaAlEntrar: recargaAlEntrar,
    ),
    growable: false,
  );
}

/// Monta una `IndexedStack` real con la pila que arma `pilaDeModulos`, y
/// apunta cada `initState` en [montajes].
class _Pila extends StatelessWidget {
  const _Pila({
    required this.abiertos,
    required this.visitas,
    required this.montajes,
    required this.modulos,
    this.recargaAlEntrar = true,
  });

  final Set<int> abiertos;
  final Map<int, int> visitas;
  final Map<String, int> montajes;
  final int modulos;
  final bool recargaAlEntrar;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: IndexedStack(
        index: 0,
        children: pilaDeModulos(
          modules: _modulos(modulos, recargaAlEntrar: recargaAlEntrar),
          pages: List<Widget>.generate(
            modulos,
            (i) => _PaginaQueCuenta(nombre: 'pagina-$i', montajes: montajes),
            growable: false,
          ),
          abiertos: abiertos,
          visitas: visitas,
          // El mismo 0 que el `index` de la IndexedStack de arriba.
          indiceActual: 0,
        ),
      ),
    );
  }
}

/// Una página de mentira que apunta cada vez que corre su `initState`.
///
/// Es el sustituto de las 16 reales: ahí `initState` es exactamente donde
/// cada página dispara su consulta a Supabase, así que contar montajes es
/// contar cargas de datos.
class _PaginaQueCuenta extends StatefulWidget {
  const _PaginaQueCuenta({required this.nombre, required this.montajes});

  final String nombre;
  final Map<String, int> montajes;

  @override
  State<_PaginaQueCuenta> createState() => _PaginaQueCuentaState();
}

class _PaginaQueCuentaState extends State<_PaginaQueCuenta> {
  @override
  void initState() {
    super.initState();
    widget.montajes[widget.nombre] =
        (widget.montajes[widget.nombre] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Text(widget.nombre);
}
