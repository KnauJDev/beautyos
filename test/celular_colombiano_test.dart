import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/celular_colombiano.dart';

/// D-249: el celular es la llave de la clienta, y el campo la exige bien
/// escrita en vez de arreglarla despues.
///
/// **Lo que se prueba de verdad** es que la pantalla y la base digan lo
/// mismo. En `private.beautyos_celular_valido` la regla es: solo digitos,
/// quitar el indicativo 57 cuando sobra, y exactamente diez. Si estas dos
/// caras se separan, vuelve a haber dos reglas para la misma pregunta — que
/// es exactamente lo que fue el hallazgo AW.
void main() {
  group('D-249 — el celular de la clienta', () {
    test('lo normal pasa tal cual', () {
      expect(CelularColombiano.normalizar('3001234567'), '3001234567');
      expect(CelularColombiano.validar('3001234567'), isNull);
    });

    test('limpia lo que la gente pega', () {
      expect(CelularColombiano.normalizar('300 123 45 67'), '3001234567');
      expect(CelularColombiano.normalizar('300-123-4567'), '3001234567');
      expect(CelularColombiano.normalizar(' 3001234567 '), '3001234567');
    });

    test('quita el indicativo del pais, como hace la base', () {
      // El caso que se colo en el control 216 y destapo todo esto: quien
      // copia su numero de WhatsApp lo trae con +57 delante.
      expect(CelularColombiano.normalizar('+57 300 123 4567'), '3001234567');
      expect(CelularColombiano.normalizar('573001234567'), '3001234567');
      expect(CelularColombiano.validar('+57 300 123 4567'), isNull);
    });

    test('pero no confunde un 57 que es parte del numero', () {
      // Diez digitos que empiezan por 57 son un numero, no un indicativo.
      expect(CelularColombiano.normalizar('5730012345'), '5730012345');
    });

    test('un numero a medias se rechaza, y el aviso dice cuanto falta', () {
      final aviso = CelularColombiano.validar('32345678');
      expect(aviso, isNotNull);
      expect(aviso, contains('10'));
      expect(aviso, contains('8'));
    });

    test('vacio se rechaza pidiendo el dato, no regañando', () {
      expect(CelularColombiano.validar(''), contains('Escribe'));
      expect(CelularColombiano.validar(null), contains('Escribe'));
    });

    test('el 10 esta en UN solo sitio', () {
      // Si alguien lo reparte por el codigo, esto deja de tener sentido y es
      // la senyal de que volvio la trampa de D-245 y del hallazgo AY.
      expect(CelularColombiano.digitos, 10);
      expect(CelularColombiano.ejemplo.length, CelularColombiano.digitos);
      expect(
        CelularColombiano.validar(CelularColombiano.ejemplo),
        isNull,
        reason: 'el ejemplo que se le ensenya a la gente debe ser valido',
      );
    });

    test('el campo no deja escribir letras ni pasarse de largo', () {
      expect(CelularColombiano.formatos.length, 2);
      expect(CelularColombiano.indicativo, '+57');
    });
  });
}
