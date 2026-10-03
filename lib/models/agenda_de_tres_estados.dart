import '../widgets/ticket_status.dart';

/// La agenda de tres estados de un negocio con la caja apagada (D-312, paso 2
/// del plan del primer cliente real, D-308).
///
/// **Por que existe.** A David la plataforma le apago la caja (D-310), y con
/// ella desaparecio *Tickets & Caja*, que era el unico sitio donde se
/// confirmaba, se iniciaba, se terminaba o se cancelaba una cita. Su agenda
/// solo mostraba. El propietario decidio que para un negocio asi:
///
/// * toda cita nace confirmada (eso lo hace el servidor);
/// * la agenda tiene tres estados: **Confirmado -> En proceso -> Cerrado**;
/// * *Cancelar* y *No asistio* son botones, no columnas.
///
/// **"Cerrado" aqui significa ATENDIDA, no cobrada.** Por dentro es el estado
/// `finalizado`: el ticket llega solo cuando se terminan todos sus servicios.
/// El cierre con dinero (`cerrado`) exige que los pagos cubran el total, y
/// este negocio no cobra en la app: no nace ningun pago, ni comision, ni
/// numero de venta. Lo prueba el control 240.
///
/// Todo lo de aqui son **funciones puras** a proposito, como
/// `AccionesDeTicket`: las reglas de que boton sale y que pasos da cada uno
/// se comprueban sin sesion de Supabase (H-03).
enum AccionDeTresEstados {
  iniciar('Iniciar'),
  cerrar('Cerrar'),
  cancelar('Cancelar'),
  noAsistio('No asistió');

  const AccionDeTresEstados(this.etiqueta);
  final String etiqueta;

  /// Cancelar y No asistio piden motivo: el servidor lo exige
  /// (`change_ticket_status`) y queda en el historial de la cita.
  bool get pideMotivo =>
      this == AccionDeTresEstados.cancelar ||
      this == AccionDeTresEstados.noAsistio;
}

/// Un paso de servidor. O cambia el estado del ticket, o el de uno de sus
/// servicios; nunca los dos.
class PasoDeCita {
  const PasoDeCita.ticket(this.nuevoEstado, {this.motivo}) : servicioId = null;
  const PasoDeCita.servicio(this.servicioId, this.nuevoEstado) : motivo = null;

  /// `null` si el paso es del ticket.
  final String? servicioId;
  final String nuevoEstado;
  final String? motivo;

  bool get esDelTicket => servicioId == null;

  @override
  String toString() => esDelTicket
      ? 'ticket->$nuevoEstado'
      : 'servicio $servicioId->$nuevoEstado';
}

/// Un servicio de la cita, tal como lo devuelve
/// `get_ticket_services_for_management_v2`.
typedef ServicioDeCita = ({String id, String estado});

abstract final class AgendaDeTresEstados {
  /// Lo que antes era "Por confirmar". En esta agenda no existe: una cita
  /// que nacio asi, antes de apagar la caja, se ve como confirmada y la app
  /// la confirma por dentro antes de moverla.
  static const _sinConfirmar = {'solicitado', 'cotizado', 'apartado'};

  static const estadosConfirmado = [
    'solicitado',
    'cotizado',
    'apartado',
    'confirmado',
    'en_espera',
  ];
  static const estadosEnProceso = ['en_proceso'];
  static const estadosCerrado = ['finalizado', 'cerrado'];

  /// Como se le muestra el estado a quien tiene esta agenda.
  static TicketStatus comoSeMuestra(String estado) {
    final e = estado.toLowerCase().trim();
    if (estadosConfirmado.contains(e)) return TicketStatus.confirmado;
    if (estadosCerrado.contains(e)) return TicketStatus.cerrado;
    return TicketStatus.desde(e);
  }

  /// Los botones que lleva una cita segun su estado.
  ///
  /// * Antes de empezar: Iniciar, Cerrar (la cita ocurrio y nadie toco
  ///   Iniciar), Cancelar y No asistio.
  /// * En proceso: solo Cerrar. El servidor no deja cancelar algo que ya
  ///   empezo.
  /// * Cerrada, cancelada o no asistio: nada.
  static List<AccionDeTresEstados> acciones(String estado) {
    final e = estado.toLowerCase().trim();
    if (estadosConfirmado.contains(e)) {
      return AccionDeTresEstados.values;
    }
    if (estadosEnProceso.contains(e)) {
      return const [AccionDeTresEstados.cerrar];
    }
    return const [];
  }

  /// Los pasos de servidor que da cada boton, en orden.
  ///
  /// Se arman con las funciones que ya existen y ya autorizan a duenyo,
  /// admin y recepcion (`change_ticket_status_v2`,
  /// `change_ticket_service_status_v2`), cada una con su historial. Ninguna
  /// toca dinero.
  ///
  /// Si un paso falla a mitad, la cita queda en un estado valido (por
  /// ejemplo, En proceso) y el boton se puede volver a pulsar: los pasos ya
  /// dados no se repiten porque se calculan desde el estado actual.
  static List<PasoDeCita> pasos(
    AccionDeTresEstados accion, {
    required String estadoDelTicket,
    required List<ServicioDeCita> servicios,
    String? motivo,
  }) {
    final e = estadoDelTicket.toLowerCase().trim();
    final confirmarPrimero = _sinConfirmar.contains(e)
        ? const [PasoDeCita.ticket('confirmado')]
        : const <PasoDeCita>[];

    switch (accion) {
      case AccionDeTresEstados.iniciar:
        return [
          ...confirmarPrimero,
          for (final s in servicios)
            if (s.estado == 'pendiente')
              PasoDeCita.servicio(s.id, 'en_proceso'),
        ];
      case AccionDeTresEstados.cerrar:
        // Primero se inician todos los pendientes y despues se terminan
        // todos: terminar un servicio exige que el ticket este en proceso, y
        // el ticket pasa solo a "finalizado" cuando no queda ninguno abierto.
        return [
          ...confirmarPrimero,
          for (final s in servicios)
            if (s.estado == 'pendiente')
              PasoDeCita.servicio(s.id, 'en_proceso'),
          for (final s in servicios)
            if (s.estado == 'pendiente' || s.estado == 'en_proceso')
              PasoDeCita.servicio(s.id, 'finalizado'),
        ];
      case AccionDeTresEstados.cancelar:
        // El servidor deja cancelar desde cualquier estado previo a empezar.
        return [PasoDeCita.ticket('cancelado', motivo: motivo)];
      case AccionDeTresEstados.noAsistio:
        // "No asistio" solo se acepta desde confirmado o en espera.
        return [
          ...confirmarPrimero,
          PasoDeCita.ticket('no_asistio', motivo: motivo),
        ];
    }
  }

  /// Las citas que aun piden algo al final del dia: todo lo que no esta
  /// cerrado ni quedo sin efecto.
  static bool pendienteAlFinalDelDia(String estado) {
    final e = estado.toLowerCase().trim();
    return estadosConfirmado.contains(e) || estadosEnProceso.contains(e);
  }
}
