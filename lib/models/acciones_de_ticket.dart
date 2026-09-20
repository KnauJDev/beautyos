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

  // ---------------------------------------------------------------------
  // Atender los servicios del ticket (hallazgo AP)
  // ---------------------------------------------------------------------

  /// Estados del **ticket** en los que se le puede mover el estado a sus
  /// servicios.
  ///
  /// Es la lista que `public.change_ticket_service_status` exige: iniciar
  /// pide el ticket en `confirmado`, `en_espera` o `en_proceso`, y finalizar
  /// lo pide en `en_proceso` -- al que se llega solo iniciando. Ofrecerlo
  /// antes seria ensenyar un boton que el servidor rechaza.
  static const _seAtiende = {'confirmado', 'en_espera', 'en_proceso'};

  /// **Por que existe esta accion (hallazgo AP).** Un salon crea estilistas
  /// en el catalogo sin invitarlos, porque no todo el mundo quiere dar
  /// cuentas a todos. Para esos, el unico sitio de toda la aplicacion que
  /// finalizaba un servicio era **Mi agenda**, la pantalla privada del
  /// estilista -- que no existe si no tiene cuenta. El ticket se quedaba en
  /// *En proceso* para siempre: se le podia cobrar (D-163), pero **nunca
  /// cerraba y nunca pagaba comision**, porque
  /// `beautyos_close_ticket_if_fully_paid` se sale de vacio si el ticket no
  /// esta `finalizado`.
  ///
  /// **No faltaba permiso, faltaba el boton:**
  /// `change_ticket_service_status_v2` ya autoriza a `tenant_owner`, `admin`
  /// y `assistant` -- los tres unicos roles que abren Tickets & Caja.
  static bool puedeAtenderServicios(String estadoDelTicket) {
    return _seAtiende.contains(estadoDelTicket);
  }

  /// A que estado pasa un **servicio** desde el suyo. `null` cuando ya no
  /// tiene siguiente paso.
  ///
  /// **Espejo de `public.change_ticket_service_status`, que es quien decide
  /// de verdad.** Vive aqui una sola vez porque esta misma transicion estaba
  /// escrita a mano dentro de `my_stylist_agenda_page.dart`, y copiarla a
  /// Tickets & Caja habria hecho tres sitios con la misma regla: la trampa
  /// que costo D-245 y el hallazgo AY.
  ///
  /// Un servicio `cancelado` no revive por aqui, y uno `finalizado` se
  /// deshace por su via controlada (`reopen_finished_ticket_service_v2`),
  /// que ademas pide motivo y es de duenyo y admin.
  static String? siguienteEstadoDelServicio(String estadoDelServicio) {
    switch (estadoDelServicio) {
      case 'pendiente':
        return 'en_proceso';
      case 'en_proceso':
        return 'finalizado';
      default:
        return null;
    }
  }

  /// Como se llama ese paso en un boton. `null` cuando no hay paso.
  static String? etiquetaDelSiguientePaso(String estadoDelServicio) {
    switch (siguienteEstadoDelServicio(estadoDelServicio)) {
      case 'en_proceso':
        return 'Iniciar';
      case 'finalizado':
        return 'Finalizar';
      default:
        return null;
    }
  }
}
