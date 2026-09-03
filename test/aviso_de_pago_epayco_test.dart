import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/aviso_de_pago.dart';

/// Lo que ve el dueño al volver de pagar en ePayco (D-200).
///
/// **Lo que se está probando de verdad** no es el texto: es la regla de que
/// **un fallo de esta llamada no se le cuenta como un pago fallido**. La vía
/// autoritativa de activación es el webhook (D-141); `verify-epayco-transaction`
/// es solo el atajo para que la confirmación se vea sin esperar. Decirle
/// "hubo un error" a alguien que acaba de pagar bien sería peor que el
/// silencio que había antes de este bloque.
void main() {
  group('D-200 — Pago aprobado', () {
    test('aprobado y ya activo: se promete que quedó al día', () {
      final aviso = AvisoDePago.desdeLaPasarela({
        'success': true,
        'transactionState': 'Aceptada',
        'codResponse': '1',
        'newStatus': 'active',
      });

      expect(aviso.tono, TonoDeAviso.exito);
      expect(aviso.mensaje, contains('al día'));
    });

    test('aprobado pero el negocio sigue en revisión: no se promete activa', () {
      // Guard de negocio de D-125/D-138: la base registra el pago pero NO
      // reactiva mientras el negocio esté pendiente de aprobación. Prometer
      // "tu suscripción está activa" ahí sería mentir sobre dinero.
      final aviso = AvisoDePago.desdeLaPasarela({
        'success': true,
        'transactionState': 'Aceptada',
        'codResponse': '1',
        'newStatus': 'pending',
      });

      expect(aviso.tono, TonoDeAviso.informacion);
      expect(aviso.mensaje, contains('aprobó tu pago'));
      expect(aviso.mensaje, isNot(contains('al día')));
    });

    test('el código 1 basta aunque el estado venga con otro nombre', () {
      final aviso = AvisoDePago.desdeLaPasarela({
        'transactionState': 'Algo que ePayco invente mañana',
        'codResponse': '1',
        'newStatus': 'active',
      });

      expect(aviso.tono, TonoDeAviso.exito);
    });
  });

  group('D-200 — Pago no aprobado', () {
    test('rechazada y fallida avisan sin alarmar', () {
      for (final estado in ['Rechazada', 'Fallida']) {
        final aviso = AvisoDePago.desdeLaPasarela({
          'transactionState': estado,
        });

        expect(aviso.tono, TonoDeAviso.advertencia, reason: estado);
        expect(aviso.mensaje, contains('no aprobó'), reason: estado);
      }
    });

    test('los códigos 2 y 4 son rechazo, el 6 es reverso', () {
      expect(
        AvisoDePago.desdeLaPasarela({'codResponse': '2'}).mensaje,
        contains('no aprobó'),
      );
      expect(
        AvisoDePago.desdeLaPasarela({'codResponse': '4'}).mensaje,
        contains('no aprobó'),
      );
      expect(
        AvisoDePago.desdeLaPasarela({'codResponse': '6'}).mensaje,
        contains('reversó'),
      );
    });
  });

  group('D-200 — Cuando no se sabe, no se afirma', () {
    test('un pago pendiente dice que se está validando', () {
      final aviso = AvisoDePago.desdeLaPasarela({
        'transactionState': 'Pendiente',
      });

      expect(aviso.tono, TonoDeAviso.informacion);
      expect(aviso.mensaje, contains('validando'));
    });

    test('un cuerpo que no se entiende no inventa nada', () {
      for (final cuerpo in <Object?>[null, 'texto suelto', 42, <String, Object?>{}]) {
        final aviso = AvisoDePago.desdeLaPasarela(cuerpo);

        expect(aviso.tono, TonoDeAviso.informacion, reason: '$cuerpo');
        expect(aviso.mensaje, contains('validando'), reason: '$cuerpo');
      }
    });

    test('un fallo de la llamada NO se cuenta como pago fallido', () {
      // Este es el corazón del bloque. Red caída, sesión vencida (401), pago
      // de otro negocio (403), factura no atribuible (409), 500 del servidor:
      // en los cinco el webhook sigue vivo y activa igual, así que al dueño
      // se le dice la verdad -- que se está validando-- y nunca "error".
      final aviso = AvisoDePago.enValidacion();

      expect(aviso.tono, TonoDeAviso.informacion);
      expect(aviso.tono, isNot(TonoDeAviso.advertencia));
      expect(aviso.mensaje, contains('validando'));
      expect(aviso.mensaje.toLowerCase(), isNot(contains('error')));
      expect(aviso.mensaje.toLowerCase(), isNot(contains('falló')));
    });
  });

  group('D-200 — Los estados no se desalinean de la base', () {
    test('son exactamente los que clasifica beautyos_procesar_evento_epayco', () {
      // Copiados de la migración 20260823150000, que es quien de verdad
      // decide qué le pasa a la suscripción. Si allí se añade un estado y
      // aquí no, el salón vería un mensaje que no corresponde con lo que hizo
      // la base: esta prueba obliga a tocar los dos sitios a la vez.
      expect(
        AvisoDePago.estadosAceptados,
        {'aceptada', 'aprobada', 'approved', 'success'},
      );
      expect(
        AvisoDePago.estadosRechazados,
        {'rechazada', 'fallida', 'rejected', 'failed'},
      );
      expect(AvisoDePago.estadosReversados, {'reversada', 'reversed'});
    });

    test('el estado se lee sin importar mayúsculas ni espacios', () {
      final aviso = AvisoDePago.desdeLaPasarela({
        'transactionState': '  ACEPTADA  ',
        'newStatus': 'ACTIVE',
      });

      expect(aviso.tono, TonoDeAviso.exito);
    });
  });
}
