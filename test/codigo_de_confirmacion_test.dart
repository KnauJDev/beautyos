import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/codigo_de_confirmacion.dart';

/// D-248, corregido el 19-sep.
///
/// **Lo que se prueba de verdad es que esto NO sepa cuántos dígitos tiene un
/// código.** La primera versión exigía exactamente 6; el correo real trajo
/// **8** y el campo habría cortado dos. La longitud vive en Supabase y se
/// cambia desde su panel, así que escribirla aquí es el error de D-245 con
/// otra ropa.
void main() {
  group('El código de confirmación no sabe cuántos dígitos tiene', () {
    test('acepta 6, que era lo que se supuso', () {
      expect(CodigoDeConfirmacion.normalizar('123456'), '123456');
    });

    test('acepta 8, que es lo que llegó de verdad el 19-sep', () {
      // El código real del correo del propietario.
      expect(CodigoDeConfirmacion.normalizar('59875879'), '59875879');
    });

    test('aceptaría 10 el día que alguien lo cambie en Supabase', () {
      expect(CodigoDeConfirmacion.normalizar('1234567890'), '1234567890');
    });

    test('limpia lo que la gente pega: espacios, guiones y saltos', () {
      // Copiar del correo arrastra separadores. Eso no es culpa de nadie.
      expect(CodigoDeConfirmacion.normalizar('5 9 8 7 5 8 7 9'), '59875879');
      expect(CodigoDeConfirmacion.normalizar('598-758'), '598758');
      expect(CodigoDeConfirmacion.normalizar(' 123456\n'), '123456');
    });

    test('rechaza lo que obviamente no es un código', () {
      expect(CodigoDeConfirmacion.normalizar(''), isNull);
      expect(CodigoDeConfirmacion.normalizar('12'), isNull);
      expect(CodigoDeConfirmacion.normalizar('hola'), isNull);
      expect(CodigoDeConfirmacion.normalizar('1234567890123456'), isNull);
    });

    test('el aviso no promete un número de dígitos', () {
      // Prometer "son 6 números" es justo lo que se rompió. El texto no
      // puede afirmar algo que esta capa no sabe.
      expect(CodigoDeConfirmacion.avisoDeFormato, isNot(contains('6')));
      expect(CodigoDeConfirmacion.avisoDeFormato, isNot(contains('8')));
      expect(CodigoDeConfirmacion.avisoDeFormato, isNotEmpty);
    });
  });
}
