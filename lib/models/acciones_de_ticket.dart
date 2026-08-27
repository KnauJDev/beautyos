/// Que se puede hacer con un ticket, segun su estado y quien lo mira.
///
/// **Por que esto vive aqui y no dentro de la pantalla (H-03, accion A6).**
/// Estas reglas estaban escritas dentro de `TicketsPage`, en metodos privados
/// que ninguna prueba podia alcanzar. Y son exactamente las que fallaron dos
/// veces en un mismo dia:
///
/// * **D-094:** al dar pantallas al asistente se autorizaron las funciones de
///   accion pero no las de lectura, y el rol entraba a un menu que no cargaba.
/// * **D-095:** el asistente veia botones de anular pago y reabrir servicios
///   que el servidor le negaba. Se ocultaron pasando `isOwnerOrAdmin` a la
///   pantalla.
///
/// Las tres regresiones de aquel dia las encontro el propietario probando en
/// produccion, no las pruebas. Sacarlas aqui es lo que permite comprobarlas
/// sin abrir un navegador.
///
/// **Esto NO sustituye la autorizacion del servidor.** La base de datos sigue
/// siendo la unica que decide de verdad; esto solo evita ofrecer un boton que
/// va a fallar. Ocultar un boton nunca fue control de acceso (D-012).
class AccionesDeTicket {
  const AccionesDeTicket._();

  /// Estados en los que el ticket todavia no ha empezado a atenderse, asi que
  /// se le pueden cambiar los servicios y la hora.
  static const _antesDeAtender = {
    'solicitado',
    'cotizado',
    'apartado',
    'confirmado',
    'en_espera',
  };

  /// Estados en los que ya hay dinero de por medio.
  static const _conDinero = {'finalizado', 'cerrado'};

  static bool puedeAgregarServicios(String estado) {
    return _antesDeAtender.contains(estado);
  }

  static bool puedeGestionarServicios(String estado, int duracionTotal) {
    // Sin servicios no hay nada que gestionar: el boton abriria una lista
    // vacia.
    return puedeAgregarServicios(estado) && duracionTotal > 0;
  }

  static bool puedeReprogramar(String estado, {required bool tieneFecha}) {
    return tieneFecha && _antesDeAtender.contains(estado);
  }

  static bool puedeCambiarEstado(String estado) {
    return siguientesEstados(estado).isNotEmpty;
  }

  /// Corregir una finalizacion toca **comisiones ya calculadas**, asi que es
  /// de dueno y administrador. Mismo criterio de caja de D-095: recepcion
  /// cobra, el dueno deshace.
  static bool puedeCorregirFinalizacion(
    String estado, {
    required bool esDuenoOAdmin,
  }) {
    if (!esDuenoOAdmin) return false;
    return {'en_proceso', 'finalizado'}.contains(estado);
  }

  /// El salon cobra abonos/anticipos desde que la cita se solicita, no solo
  /// cuando ya se atendio (D-163): lo unico que de verdad no admite cobro es
  /// una cita cancelada o a la que no se asistio. El servidor aplica la
  /// misma regla en `register_ticket_payment` (D-163).
  static bool puedeGestionarPagos(String estado) {
    return !{'cancelado', 'no_asistio'}.contains(estado);
  }

  static bool puedeCopiarEnlaceResena(String estado) {
    return _conDinero.contains(estado);
  }

  /// A un ticket cancelado o no asistido no se le agregan fotos: no hubo
  /// trabajo que fotografiar.
  static bool puedeAgregarFoto(String estado) {
    return !{'cancelado', 'no_asistio'}.contains(estado);
  }

  /// A que estados se puede pasar desde el actual.
  ///
  /// Los estados finales -- `finalizado`, `cerrado`, `cancelado`,
  /// `no_asistio` -- no devuelven ninguno **a proposito**: de ahi no se sale
  /// cambiando el estado a mano. Finalizar se hace por servicio y cerrar lo
  /// hace el cobro; deshacerlos tiene su propia via controlada
  /// (`reopen_finished_ticket_service_v2`), que ademas es de dueno y admin.
  static List<String> siguientesEstados(String estadoActual) {
    switch (estadoActual) {
      case 'solicitado':
        return ['cotizado', 'apartado', 'confirmado', 'cancelado'];
      case 'cotizado':
        return ['apartado', 'confirmado', 'cancelado'];
      case 'apartado':
        return ['confirmado', 'cancelado'];
      case 'confirmado':
        return ['en_espera', 'en_proceso', 'cancelado', 'no_asistio'];
      case 'en_espera':
        return ['en_proceso', 'cancelado', 'no_asistio'];
      default:
        return [];
    }
  }
}
