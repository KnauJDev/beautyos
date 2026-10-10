// Cerrar una sede sin borrar nada (paso 9.65, D-328, hallazgo CQ).
//
// Una sede que se cierra deja de verse, de recibir citas y de cobrarse, pero
// conserva su historial y sus pagos, y se puede volver a abrir. Las clientas
// son del negocio: siguen en las otras sedes. Prototipo aprobado:
// https://claude.ai/artifact/FKNnRij9kGtaNWPknX6HZB

/// Los estados de pago de una sede, en español y con lo que significan.
/// Hasta el 10-oct el Panel los enseñaba en inglés (`past_due`, `cancelled`…).
const estadosDeSede = <String, ({String etiqueta, String explicacion})>{
  'pending': (etiqueta: 'Pendiente de pago', explicacion: 'Se creó y espera su primer pago.'),
  'trialing': (etiqueta: 'En prueba', explicacion: 'Días de prueba, sin cobro.'),
  'active': (etiqueta: 'Activa · al día', explicacion: 'Pagada y funcionando.'),
  'past_due': (etiqueta: 'Vencida', explicacion: 'Se pasó la fecha de pago; sigue funcionando unos días.'),
  'grace': (etiqueta: 'En gracia', explicacion: 'Últimos días antes de suspenderse.'),
  'suspended': (etiqueta: 'Suspendida', explicacion: 'No recibe citas nuevas hasta que pague.'),
  'cancelled': (etiqueta: 'Cancelada', explicacion: 'Sin cobro. Para cerrarla del todo, "Cerrar sede".'),
};

String etiquetaDelEstadoDeSede(String estado) =>
    estadosDeSede[estado]?.etiqueta ?? estado;

/// Una cita que impide cerrar la sede.
class CitaProxima {
  const CitaProxima({
    required this.scheduledAt,
    required this.clientName,
    required this.serviceNames,
  });

  final DateTime scheduledAt;

  /// `null` cuando la pide la plataforma: no ve las clientas de un salón.
  final String? clientName;
  final String serviceNames;

  factory CitaProxima.fromMap(Map<String, dynamic> m) => CitaProxima(
    scheduledAt: DateTime.parse(m['scheduled_at'].toString()).toLocal(),
    clientName: (m['client_name']?.toString().trim().isEmpty ?? true)
        ? null
        : m['client_name'].toString().trim(),
    serviceNames: m['service_names']?.toString() ?? '',
  );

  /// "Vie 10 oct · 3:00 p. m. · Ana · Tinte".
  String get texto {
    final partes = [
      '${_dias[scheduledAt.weekday - 1]} ${scheduledAt.day} ${_meses[scheduledAt.month - 1]}',
      _hora(scheduledAt),
      if (clientName != null) clientName!.split(RegExp(r'\s+')).first,
      if (serviceNames.isNotEmpty) serviceNames,
    ];
    return partes.join(' · ');
  }
}

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _hora(DateTime f) {
  final h12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final mm = f.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}
