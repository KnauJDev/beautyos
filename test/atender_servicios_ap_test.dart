import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/acciones_de_ticket.dart';

/// Hallazgo AP: el duenyo, el administrador y la recepcion pueden dar por
/// iniciado y por terminado un servicio desde Tickets & Caja.
///
/// **Lo que esta prueba cuida de verdad.** No es que un boton aparezca: es
/// que la tabla de estados que la pantalla usa sea **la misma** que exige
/// `public.change_ticket_service_status`. Si se separan, vuelve a haber dos
/// reglas para la misma pregunta y la pantalla ofrece pasos que el servidor
/// rechaza --que es exactamente lo que fue D-095.
///
/// Lo que **no** prueba: que el servidor autorice. Eso lo ejercita el
/// control 218 contra la base real, porque una prueba que lee Dart no sabe
/// nada de permisos (D-245).
void main() {
  group('AP — atender servicios desde Tickets & Caja', () {
    test('el paso de cada servicio es el que el servidor admite', () {
      // En `change_ticket_service_status`: pendiente -> en_proceso y
      // en_proceso -> finalizado. No hay mas caminos hacia adelante.
      expect(
        AccionesDeTicket.siguienteEstadoDelServicio('pendiente'),
        'en_proceso',
      );
      expect(
        AccionesDeTicket.siguienteEstadoDelServicio('en_proceso'),
        'finalizado',
      );
    });

    test('un servicio terminado o cancelado ya no avanza', () {
      // Deshacer una finalizacion toca comisiones ya calculadas y tiene su
      // via propia, con motivo obligatorio y solo para duenyo y admin
      // (`reopen_finished_ticket_service_v2`). Si apareciera aqui seria una
      // puerta trasera a esa regla.
      expect(
        AccionesDeTicket.siguienteEstadoDelServicio('finalizado'),
        isNull,
      );
      expect(AccionesDeTicket.siguienteEstadoDelServicio('cancelado'), isNull);
      expect(AccionesDeTicket.etiquetaDelSiguientePaso('finalizado'), isNull);
    });

    test('la etiqueta del boton sale del estado, no se escribe al lado', () {
      expect(AccionesDeTicket.etiquetaDelSiguientePaso('pendiente'), 'Iniciar');
      expect(
        AccionesDeTicket.etiquetaDelSiguientePaso('en_proceso'),
        'Finalizar',
      );
    });

    test('la accion se ofrece justo en los estados que el ticket admite', () {
      // Iniciar pide el ticket en confirmado, en_espera o en_proceso;
      // finalizar lo pide en en_proceso. Fuera de ahi el servidor lo niega.
      for (final estado in ['confirmado', 'en_espera', 'en_proceso']) {
        expect(
          AccionesDeTicket.puedeAtenderServicios(estado),
          isTrue,
          reason: 'en $estado el servidor si deja mover los servicios',
        );
      }
    });

    test('antes de confirmar no se ofrece: seria un boton que falla', () {
      for (final estado in ['solicitado', 'cotizado', 'apartado']) {
        expect(
          AccionesDeTicket.puedeAtenderServicios(estado),
          isFalse,
          reason: 'en $estado el ticket todavia no se atiende',
        );
      }
    });

    test('un ticket ya terminado, cobrado o caido no se atiende', () {
      for (final estado in [
        'finalizado',
        'cerrado',
        'cancelado',
        'no_asistio',
      ]) {
        expect(
          AccionesDeTicket.puedeAtenderServicios(estado),
          isFalse,
          reason: 'en $estado no queda nada que atender',
        );
      }
    });

    test('«Cambiar estado» no cubria esto, y por eso hizo falta AP', () {
      // La prueba de la enfermedad: en `en_proceso` --donde se queda el
      // ticket de un estilista sin cuenta-- el boton Estado se queda sin
      // opciones. Ese vacio era el hallazgo.
      expect(AccionesDeTicket.puedeCambiarEstado('en_proceso'), isFalse);
      expect(AccionesDeTicket.puedeAtenderServicios('en_proceso'), isTrue);
    });
  });
}
