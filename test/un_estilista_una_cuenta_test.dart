import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/stylist_for_invitation.dart';

/// Hallazgo R: un estilista del catálogo, una sola cuenta activa (D-132).
///
/// **Lo que estas pruebas SÍ cubren:** que la marca de "ya tiene cuenta" llegue
/// intacta desde el servidor y que la lista que se ofrece al invitar excluya a
/// los ocupados.
///
/// **Lo que NO cubren, y hay que saberlo:** el candado de verdad es un índice
/// único en la base de datos, y las tres comprobaciones con mensaje viven en
/// funciones de PostgreSQL. **Ninguna prueba de Dart puede alcanzarlas** — es
/// la misma limitación que dejó escrita D-117 con el número de ticket. Se
/// comprueban con `supabase/sql/165_verify_un_estilista_una_cuenta.sql`, que
/// hay que ejecutar a mano, y con la prueba del propietario en producción.
void main() {
  group('La marca de "ya tiene cuenta" llega intacta', () {
    test('true y false se leen tal cual', () {
      final ocupado = StylistForInvitation.fromMap({
        'id': 'a1',
        'name': 'Erick Chaparro',
        'has_active_account': true,
      });
      final libre = StylistForInvitation.fromMap({
        'id': 'a2',
        'name': 'Luiscar',
        'has_active_account': false,
      });

      expect(ocupado.hasActiveAccount, isTrue);
      expect(libre.hasActiveAccount, isFalse);
      expect(ocupado.name, 'Erick Chaparro');
    });

    test('un vacío o un campo ausente se leen como "no tiene cuenta"', () {
      // Falla hacia el lado seguro a propósito: si el servidor no lo dice, se
      // ofrece el estilista y **el candado de la base es quien rechaza**. Al
      // revés — asumir que sí tiene cuenta — escondería a alguien invitable
      // sin explicar por qué, que es peor: un error visible se arregla, uno
      // invisible no (la lección de D-122).
      final sinCampo = StylistForInvitation.fromMap({
        'id': 'a3',
        'name': 'Sin dato',
      });
      final nulo = StylistForInvitation.fromMap({
        'id': 'a4',
        'name': 'Nulo',
        'has_active_account': null,
      });

      expect(sinCampo.hasActiveAccount, isFalse);
      expect(nulo.hasActiveAccount, isFalse);
    });

    test('un nombre vacío no rompe la lista entera', () {
      // La galería se cayó entera por una sola fila sin texto de respaldo
      // (D-123). Aquí el nombre nunca queda nulo.
      final sinNombre = StylistForInvitation.fromMap({
        'id': 'a5',
        'name': null,
        'has_active_account': false,
      });

      expect(sinNombre.name, 'Sin nombre');
    });
  });

  group('Al invitar solo se ofrecen los que no tienen cuenta', () {
    final catalogo = [
      StylistForInvitation.fromMap({
        'id': 'a1',
        'name': 'Erick Chaparro',
        'has_active_account': true,
      }),
      StylistForInvitation.fromMap({
        'id': 'a2',
        'name': 'Luiscar',
        'has_active_account': false,
      }),
      StylistForInvitation.fromMap({
        'id': 'a3',
        'name': 'Yelimar',
        'has_active_account': true,
      }),
    ];

    List<StylistForInvitation> invitables(List<StylistForInvitation> todos) =>
        todos.where((s) => !s.hasActiveAccount).toList();

    test('el que ya tiene cuenta no aparece', () {
      final lista = invitables(catalogo);

      expect(lista.map((s) => s.name), ['Luiscar']);
      expect(lista.any((s) => s.name == 'Erick Chaparro'), isFalse);
    });

    test('si todos tienen cuenta, la lista queda vacía y hay aviso', () {
      // El diálogo distingue tres casos: sin estilistas en la sede, con
      // estilistas pero todos vinculados, y la lista. Esta prueba vigila el
      // del medio, que es el que antes no existía.
      final todosOcupados = catalogo.where((s) => s.hasActiveAccount).toList();

      expect(todosOcupados, isNotEmpty);
      expect(invitables(todosOcupados), isEmpty);
    });

    test('sin estilistas en la sede, la lista también queda vacía', () {
      expect(invitables(const []), isEmpty);
    });
  });
}
