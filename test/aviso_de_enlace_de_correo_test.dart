import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/aviso_de_enlace_de_correo.dart';

/// Hallazgo AM (18-sep): un acceso fallido no decía absolutamente nada.
///
/// **Lo que se prueba de verdad** no son los textos, es la regla: **ningún
/// error llega en silencio, y todo aviso dice qué hacer**. El fallo original
/// no fue que el mensaje estuviera mal escrito — es que no había mensaje, y
/// el texto del error viajó en la barra de direcciones de un estilista
/// durante toda su sesión sin que nadie lo leyera.
void main() {
  group('AM — el error que llega en la dirección', () {
    test('sin error no se molesta a nadie', () {
      expect(
        AvisoDeEnlaceDeCorreo.desdeLaDireccion(
          Uri.parse('https://salonymas.com/'),
        ),
        isNull,
      );
    });

    test('un parámetro cualquiera no se confunde con un error', () {
      // La dirección lleva doce parámetros legítimos (reservar, resena,
      // planes, ref, ref_payco...). Ninguno debe disparar el aviso.
      expect(
        AvisoDeEnlaceDeCorreo.desdeLaDireccion(
          Uri.parse('https://salonymas.com/?reservar=abc&ref=MANITO'),
        ),
        isNull,
      );
    });

    test('el caso real del 18-sep: otp_expired dice que se inicie sesión', () {
      // Esta es la dirección exacta que vio el estilista invitado.
      final aviso = AvisoDeEnlaceDeCorreo.desdeLaDireccion(
        Uri.parse(
          'https://salonymas.com/?error=access_denied&error_code=otp_expired'
          '&error_description=Email+link+is+invalid+or+has+expired',
        ),
      );

      expect(aviso, isNotNull);
      expect(aviso!.queHacer, contains('contraseña'));
      // Lo que NO debe hacer: repetirle el inglés de Supabase.
      expect(aviso.titulo, isNot(contains('invalid')));
      expect(aviso.titulo, isNot(contains('expired')));
    });

    test('también lo lee cuando viene detrás del #', () {
      // Supabase manda el error en el fragmento en algunos flujos. Mirar solo
      // la consulta dejaría la mitad de los casos sin aviso.
      final aviso = AvisoDeEnlaceDeCorreo.desdeLaDireccion(
        Uri.parse(
          'https://salonymas.com/#error=access_denied&error_code=otp_expired',
        ),
      );

      expect(aviso, isNotNull);
      expect(aviso!.queHacer, isNotEmpty);
    });

    test('un código desconocido NO se traga en silencio', () {
      // La regla de este hallazgo: el silencio es el fallo. Un código que
      // todavía no conocemos avisa igual, aunque sea con palabras generales.
      final aviso = AvisoDeEnlaceDeCorreo.desdeLaDireccion(
        Uri.parse('https://salonymas.com/?error_code=algo_que_no_existe_aun'),
      );

      expect(aviso, isNotNull);
      expect(aviso!.queHacer, isNotEmpty);
    });

    test('todo aviso dice qué hacer, nunca solo qué pasó', () {
      const codigos = ['otp_expired', 'access_denied', 'inventado'];

      for (final codigo in codigos) {
        final aviso = AvisoDeEnlaceDeCorreo.desdeLaDireccion(
          Uri.parse('https://salonymas.com/?error_code=$codigo'),
        );

        expect(aviso, isNotNull, reason: codigo);
        expect(aviso!.titulo, isNotEmpty, reason: codigo);
        expect(aviso.queHacer, isNotEmpty, reason: codigo);
      }
    });

    test('un fragmento que no son parámetros no revienta', () {
      expect(
        AvisoDeEnlaceDeCorreo.desdeLaDireccion(
          Uri.parse('https://salonymas.com/#/alguna/ruta'),
        ),
        isNull,
      );
    });
  });
}
