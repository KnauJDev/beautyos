/// Qué se le dice al dueño cuando vuelve de pagar en ePayco (D-200).
///
/// **Por qué existe.** Al volver de la pasarela, `main.dart` llamaba a
/// `verify-epayco-transaction` y **se tragaba el resultado entero**: ni el
/// éxito ni el fallo llegaban a la pantalla. El dueño acababa de pagar
/// $150.000 y volvía a una aplicación que no le decía absolutamente nada.
///
/// **Por qué un fallo aquí NO es un pago fallido.** La vía autoritativa de
/// activación es el webhook servidor-a-servidor (D-141), no esta llamada.
/// `verify-epayco-transaction` es un atajo para que el dueño vea la
/// confirmación sin esperar. Si falla —se cayó la red, el token venció, la
/// función devolvió 500— **el pago sigue su curso y el webhook activa igual**.
/// Por eso el caso de error dice "estamos validando", no "hubo un error": la
/// auditoría del 01-sep ya corrigió esa severidad, y asustar a alguien que
/// acaba de pagar bien sería peor que el silencio que había antes.
///
/// **Por qué vive aquí y no dentro de `main.dart`.** Misma razón que
/// `AccionesDeTicket` (H-03): metida en un método privado de un `State` no
/// hay forma de comprobarla sin abrir un navegador y pagar de verdad.
library;

/// El color con el que se enseña el aviso. La traducción a un color concreta
/// la hace la interfaz, no este archivo: los colores viven en `lib/theme/`.
enum TonoDeAviso { exito, advertencia, informacion }

class AvisoDePago {
  const AvisoDePago({required this.mensaje, required this.tono});

  final String mensaje;
  final TonoDeAviso tono;

  /// Lo que se enseña cuando no se pudo saber en qué quedó la transacción.
  ///
  /// Cubre **todos** los caminos de fallo de la llamada: excepción de red,
  /// 401 por sesión vencida, 403 porque el pago no es de este negocio, 409
  /// porque no se pudo atribuir la factura, 500 del servidor. En los cinco la
  /// respuesta correcta es la misma, porque en los cinco **el webhook sigue
  /// vivo** y va a activar la suscripción por su cuenta.
  factory AvisoDePago.enValidacion() {
    return const AvisoDePago(
      mensaje:
          'Estamos validando tu pago con ePayco. Tu suscripción se activará '
          'en cuanto la pasarela lo confirme, sin que tengas que hacer nada.',
      tono: TonoDeAviso.informacion,
    );
  }

  /// Traduce el cuerpo que devuelve `verify-epayco-transaction` con 200.
  ///
  /// **Los estados se leen igual que en la base de datos, a propósito.** La
  /// clasificación de aceptada/rechazada/reversada está copiada de
  /// `beautyos_procesar_evento_epayco` (migración
  /// `20260823150000_ciclo_facturacion_ancla_y_plan_pactado.sql`), que es
  /// quien de verdad decide qué le pasa a la suscripción. Si esa lista cambia
  /// allí y no aquí, el salón vería un mensaje que no corresponde con lo que
  /// hizo la base — hay una prueba que fija los dos juegos de valores.
  ///
  /// Ante cualquier cuerpo que no se entienda devuelve [AvisoDePago.enValidacion]:
  /// preferimos no afirmar nada antes que afirmar algo falso sobre dinero.
  factory AvisoDePago.desdeLaPasarela(Object? cuerpo) {
    if (cuerpo is! Map) {
      return AvisoDePago.enValidacion();
    }

    final estado = (cuerpo['transactionState'] as Object?)
        ?.toString()
        .trim()
        .toLowerCase();
    final codigo = (cuerpo['codResponse'] as Object?)?.toString().trim();
    final estadoNuevo = (cuerpo['newStatus'] as Object?)
        ?.toString()
        .trim()
        .toLowerCase();

    if (_aceptadas.contains(estado) || codigo == '1') {
      // Que ePayco la acepte no significa que la suscripción quedara activa:
      // el negocio puede estar en revisión (D-125/D-138) o suspendido a mano
      // por la plataforma, y entonces la base registra el pago pero no
      // reactiva. Solo se promete "activa" cuando la base dice que lo está.
      if (estadoNuevo == 'active') {
        return const AvisoDePago(
          mensaje: '¡Listo! Tu pago quedó confirmado y tu suscripción está al día.',
          tono: TonoDeAviso.exito,
        );
      }

      return const AvisoDePago(
        mensaje:
            'ePayco aprobó tu pago. Lo estamos registrando; si tu negocio '
            'sigue en revisión, se activará al aprobarlo.',
        tono: TonoDeAviso.informacion,
      );
    }

    if (_rechazadas.contains(estado) || codigo == '2' || codigo == '4') {
      return const AvisoDePago(
        mensaje:
            'ePayco no aprobó el pago. Puedes intentarlo de nuevo o con otro '
            'medio de pago.',
        tono: TonoDeAviso.advertencia,
      );
    }

    if (_reversadas.contains(estado) || codigo == '6') {
      return const AvisoDePago(
        mensaje:
            'ePayco reversó este pago. Si crees que es un error, escríbenos '
            'y lo revisamos contigo.',
        tono: TonoDeAviso.advertencia,
      );
    }

    // Pendiente, o un estado que ePayco añada más adelante.
    return AvisoDePago.enValidacion();
  }

  static const _aceptadas = {'aceptada', 'aprobada', 'approved', 'success'};
  static const _rechazadas = {'rechazada', 'fallida', 'rejected', 'failed'};
  static const _reversadas = {'reversada', 'reversed'};

  /// Los mismos juegos de valores que usa la base, expuestos para que una
  /// prueba pueda fijarlos contra la migración.
  static Set<String> get estadosAceptados => _aceptadas;
  static Set<String> get estadosRechazados => _rechazadas;
  static Set<String> get estadosReversados => _reversadas;
}
