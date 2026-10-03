/// Una clienta para invitar a volver, por UN servicio (D-314, paso 4B).
///
/// **Un recordatorio por servicio, a propósito.** El propietario lo explicó
/// así: si una clienta se hace un rubber (20 días) y un tinte (60 días),
/// invitarla por el rubber no puede borrar el recordatorio del tinte. Cada
/// fila de `get_return_invitations` es una pareja clienta-servicio.
///
/// Dos estados:
/// * `por_invitar`: pasó el tiempo de volver de ese servicio y nadie la ha
///   invitado desde su última visita.
/// * `invitada_sin_volver`: se la invitó y no ha vuelto a hacerse ese
///   servicio. Va en *"No volvieron"*; [tocaHoy] dice si ya pasó otra vez el
///   tiempo y conviene volver a invitarla. El salón decide.
class InvitacionAVolver {
  const InvitacionAVolver({
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.serviceId,
    required this.serviceName,
    required this.lastDoneAt,
    required this.returnDays,
    required this.estado,
    required this.tocaHoy,
    this.lastInvitedAt,
    this.timesInvited = 0,
  });

  final String clientId;
  final String clientName;
  final String clientPhone;
  final String serviceId;
  final String serviceName;
  final DateTime lastDoneAt;
  final int returnDays;
  final DateTime? lastInvitedAt;
  final int timesInvited;
  final String estado;
  final bool tocaHoy;

  bool get invitadaSinVolver => estado == 'invitada_sin_volver';

  String get primerNombre {
    final partes = clientName.trim().split(RegExp(r'\s+'));
    return partes.isEmpty || partes.first.isEmpty ? clientName : partes.first;
  }

  factory InvitacionAVolver.fromMap(Map<String, dynamic> map) {
    DateTime? fecha(Object? valor) =>
        valor == null ? null : DateTime.tryParse(valor.toString())?.toLocal();

    return InvitacionAVolver(
      clientId: map['client_id'].toString(),
      clientName: map['client_name']?.toString() ?? 'Clienta',
      clientPhone: map['client_phone']?.toString() ?? '',
      serviceId: map['service_id'].toString(),
      serviceName: map['service_name']?.toString() ?? 'Servicio',
      lastDoneAt: fecha(map['last_done_at']) ?? DateTime.now(),
      returnDays: (map['return_days'] as num?)?.toInt() ?? 45,
      lastInvitedAt: fecha(map['last_invited_at']),
      timesInvited: (map['times_invited'] as num?)?.toInt() ?? 0,
      estado: map['estado']?.toString() ?? 'por_invitar',
      tocaHoy: map['toca_hoy'] == true,
    );
  }

  /// Cómo se le cuenta al salón en qué va esta clienta con este servicio.
  String textoDeEstado(DateTime ahora) {
    final invitada = lastInvitedAt;
    if (invitadaSinVolver && invitada != null) {
      final dias = _diasEntre(invitada, ahora);
      final veces = timesInvited > 1 ? ' ($timesInvited veces)' : '';
      return 'Invitada ${_hace(dias)}$veces';
    }
    return 'Última vez ${_hace(_diasEntre(lastDoneAt, ahora))}';
  }
}

int _diasEntre(DateTime desde, DateTime hasta) {
  final a = DateTime(desde.year, desde.month, desde.day);
  final b = DateTime(hasta.year, hasta.month, hasta.day);
  final d = b.difference(a).inDays;
  return d < 0 ? 0 : d;
}

String _hace(int dias) => switch (dias) {
  0 => 'hoy',
  1 => 'ayer',
  _ => 'hace $dias días',
};

/// El WhatsApp para invitarla a volver por un servicio (D-314).
String mensajeDeInvitacionAVolver({
  required String nombre,
  required String servicio,
  String? nombreDelSalon,
  String? enlace,
}) {
  final salon = nombreDelSalon?.trim() ?? '';
  final donde = salon.isEmpty ? 'en el salón' : 'en $salon';
  final agenda = (enlace == null || enlace.isEmpty)
      ? ''
      : ' Cuando quieras, agenda aquí 👉 $enlace';
  return 'Hola $nombre, ¡te extrañamos $donde! Ya es buen momento para tu '
      '${servicio.trim().toLowerCase()}.$agenda';
}

/// Las clientas distintas de una lista (para contar en los filtros).
Set<String> clientasDe(Iterable<InvitacionAVolver> filas) =>
    {for (final f in filas) f.clientId};
