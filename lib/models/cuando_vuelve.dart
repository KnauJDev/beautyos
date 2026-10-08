// Cuándo vuelve cada clienta (paso 9.63, D-323).
//
// Cada clienta puede tener su propio tiempo de volver para cada servicio. Si
// no lo tiene, manda el del servicio (D-314) y, si tampoco, el del salón
// (45 días por defecto). Prototipo aprobado:
// https://claude.ai/artifact/N48aApd2qmN17Fxc5kHTne

/// Los atajos de la hoja: los mismos del prototipo.
const opcionesDeDias = [15, 21, 30, 45, 60, 90];

/// De dónde sale el número que viene lleno.
enum OrigenDelNumero { suyo, delServicio, delSalon }

int _entero(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _enteroONulo(Object? v) => v == null ? null : _entero(v);

/// Un servicio de la cita que se acaba de cerrar, con lo que viene lleno.
class VueltaAlCerrar {
  const VueltaAlCerrar({
    required this.ticketServiceId,
    required this.serviceId,
    required this.serviceName,
    required this.serviceStatus,
    required this.clientDays,
    required this.serviceDays,
    required this.defaultDays,
  });

  final String ticketServiceId;
  final String serviceId;
  final String serviceName;
  final String serviceStatus;

  /// El de la clienta; `null` si no tiene.
  final int? clientDays;

  /// El del servicio; `null` si no tiene (manda el del salón).
  final int? serviceDays;
  final int defaultDays;

  factory VueltaAlCerrar.fromMap(Map<String, dynamic> m) => VueltaAlCerrar(
    ticketServiceId: m['ticket_service_id'].toString(),
    serviceId: m['service_id'].toString(),
    serviceName: m['service_name']?.toString() ?? 'Servicio',
    serviceStatus: m['service_status']?.toString() ?? '',
    clientDays: _enteroONulo(m['client_days']),
    serviceDays: _enteroONulo(m['service_days']),
    defaultDays: _enteroONulo(m['default_days']) ?? 45,
  );

  bool get terminado => serviceStatus == 'finalizado';

  /// Sin el de la clienta: el del servicio, o el del salón.
  int get diasSinElSuyo => serviceDays ?? defaultDays;

  /// Lo que viene lleno.
  int get dias => clientDays ?? diasSinElSuyo;

  OrigenDelNumero get origen => clientDays != null
      ? OrigenDelNumero.suyo
      : serviceDays != null
      ? OrigenDelNumero.delServicio
      : OrigenDelNumero.delSalon;

  /// Lo que se guarda al tocar *Listo*. Si la clienta no tenía número propio
  /// y se deja el que venía, se guarda vacío: así sigue al del servicio si el
  /// salón lo cambia. Si ya tenía el suyo, se guarda lo elegido.
  int? diasParaGuardar(int elegido) =>
      clientDays == null && elegido == diasSinElSuyo ? null : elegido;
}

/// Un servicio en la ficha de la clienta.
class VueltaDeLaClienta {
  const VueltaDeLaClienta({
    required this.serviceId,
    required this.serviceName,
    required this.clientDays,
    required this.serviceDays,
    required this.defaultDays,
    required this.lastDoneAt,
    required this.skipped,
  });

  final String serviceId;
  final String serviceName;
  final int? clientDays;
  final int? serviceDays;
  final int defaultDays;
  final DateTime? lastDoneAt;

  /// Al cerrar la última vez se dijo "esta vez no".
  final bool skipped;

  factory VueltaDeLaClienta.fromMap(Map<String, dynamic> m) =>
      VueltaDeLaClienta(
        serviceId: m['service_id'].toString(),
        serviceName: m['service_name']?.toString() ?? 'Servicio',
        clientDays: _enteroONulo(m['client_days']),
        serviceDays: _enteroONulo(m['service_days']),
        defaultDays: _enteroONulo(m['default_days']) ?? 45,
        lastDoneAt: m['last_done_at'] == null
            ? null
            : DateTime.tryParse(m['last_done_at'].toString())?.toLocal(),
        skipped: m['skipped'] == true,
      );

  int get diasSinElSuyo => serviceDays ?? defaultDays;
  int get dias => clientDays ?? diasSinElSuyo;

  /// "Cada 30 días · suyo", "Cada 45 días · el del servicio".
  String get cadaCuanto {
    final de = clientDays != null
        ? 'suyo'
        : serviceDays != null
        ? 'el del servicio'
        : 'el del salón';
    return 'Cada $dias días · $de';
  }

  /// "Última vez hace 25 días · le toca en 5 días".
  String cuando(DateTime ahora) {
    final ultima = lastDoneAt;
    if (ultima == null) return 'Todavía no se lo ha hecho';
    final hace = _diasEntre(ultima, ahora);
    final primera = hace <= 0
        ? 'Última vez hoy'
        : hace == 1
        ? 'Última vez ayer'
        : 'Última vez hace $hace días';
    if (skipped) return '$primera · esta vez no se invita';
    final falta = dias - hace;
    final segunda = falta > 1
        ? 'le toca en $falta días'
        : falta == 1
        ? 'le toca mañana'
        : falta == 0
        ? 'le toca hoy'
        : 'ya le toca volver';
    return '$primera · $segunda';
  }
}

int _diasEntre(DateTime desde, DateTime hasta) => DateTime(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime(desde.year, desde.month, desde.day)).inDays;

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "7 de noviembre".
String fechaDeVolver(DateTime hoy, int dias) {
  final f = DateTime(hoy.year, hoy.month, hoy.day + dias);
  return '${f.day} de ${_meses[f.month - 1]}';
}

/// El primer nombre: "Ana Torres" → "Ana". Vacío si no hay nombre.
String primerNombre(String? nombre) {
  final partes = (nombre ?? '').trim().split(RegExp(r'\s+'));
  return partes.isEmpty ? '' : partes.first;
}

/// El aviso al tocar *Listo*: lo que se invita y lo que esta vez no.
String resumenDeLaVuelta({
  required String nombre,
  required List<({String servicio, int dias, bool invitar})> respuestas,
  required DateTime hoy,
}) {
  final si = [
    for (final r in respuestas)
      if (r.invitar) '${r.servicio} en ${r.dias} días (${fechaDeVolver(hoy, r.dias)})',
  ];
  final no = [
    for (final r in respuestas)
      if (!r.invitar) r.servicio,
  ];
  final quien = nombre.isEmpty ? 'la clienta' : nombre;
  if (si.isEmpty) {
    return 'Esta vez no invitaremos a $quien. Cuando vuelva, te preguntamos otra vez.';
  }
  final noTexto = no.isEmpty ? '' : ' Por ${no.join(' y ')}, esta vez no.';
  return 'Listo. Invitaremos a $quien a volver: ${si.join(', ')}.$noTexto';
}
