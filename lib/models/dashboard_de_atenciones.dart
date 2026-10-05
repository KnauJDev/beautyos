/// El Dashboard de atenciones (paso 5 del plan de David, D-317).
///
/// Lo que devuelve `get_dashboard_atenciones`: la historia del negocio en
/// **citas, clientas, servicios y equipo**, sin un solo peso. Es el Dashboard
/// de los negocios con la caja apagada; el de los demás no cambia (D-311).
///
/// Todo lo que se puede probar sin pantalla vive aquí: leer la respuesta,
/// comparar contra el periodo anterior y escribir la historia en palabras.
library;

/// Los números de un tramo (el periodo elegido o el anterior).
class TramoDeAtenciones {
  const TramoDeAtenciones({
    required this.atendidas,
    required this.clientas,
    required this.nuevas,
    required this.canceladas,
    required this.noLlegaron,
    required this.enLinea,
    required this.minutos,
  });

  static const vacio = TramoDeAtenciones(
    atendidas: 0,
    clientas: 0,
    nuevas: 0,
    canceladas: 0,
    noLlegaron: 0,
    enLinea: 0,
    minutos: 0,
  );

  /// Citas en Cerrado o Finalizado: en un negocio sin caja, cerrada quiere
  /// decir atendida, no pagada (D-312).
  final int atendidas;
  final int clientas;

  /// Clientas cuya primera cita atendida en el negocio cae en el tramo.
  final int nuevas;
  final int canceladas;
  final int noLlegaron;

  /// Atendidas que nacieron en la página del salón (canal `web_publico`).
  final int enLinea;

  /// Duración de los servicios atendidos.
  final int minutos;

  int get vuelven => (clientas - nuevas).clamp(0, clientas);
  int get perdidas => canceladas + noLlegaron;

  /// Las que ya se decidieron: atendidas, canceladas o que no llegaron. Las
  /// confirmadas de más tarde no cuentan todavía.
  int get decididas => atendidas + canceladas + noLlegaron;

  /// De cada 100 citas decididas, cuántas se atendieron. `null` sin citas.
  int? get asistencia =>
      decididas == 0 ? null : (atendidas * 100 / decididas).round();

  double get horas => minutos / 60;

  factory TramoDeAtenciones.fromMap(Map<String, dynamic>? map) {
    if (map == null) return vacio;
    return TramoDeAtenciones(
      atendidas: _entero(map['atendidas']),
      clientas: _entero(map['clientas']),
      nuevas: _entero(map['nuevas']),
      canceladas: _entero(map['canceladas']),
      noLlegaron: _entero(map['no_llegaron']),
      enLinea: _entero(map['en_linea']),
      minutos: _entero(map['minutos']),
    );
  }
}

class HoyDeAtenciones {
  const HoyDeAtenciones({
    required this.citas,
    required this.cerradas,
    required this.enProceso,
    required this.porAtender,
  });

  final int citas;
  final int cerradas;
  final int enProceso;
  final int porAtender;

  factory HoyDeAtenciones.fromMap(Map<String, dynamic>? map) =>
      HoyDeAtenciones(
        citas: _entero(map?['citas']),
        cerradas: _entero(map?['cerradas']),
        enProceso: _entero(map?['en_proceso']),
        porAtender: _entero(map?['por_atender']),
      );
}

class PuntoDeSerie {
  const PuntoDeSerie(this.desde, this.atendidas);

  /// Primer día del tramo: el día, el lunes de la semana o el día 1 del mes,
  /// según la granularidad.
  final DateTime desde;
  final int atendidas;
}

class CeldaDeCalor {
  const CeldaDeCalor(this.diaSemana, this.hora, this.atendidas);

  /// 1 = lunes … 7 = domingo.
  final int diaSemana;

  /// 0 a 23, en la hora de la sede.
  final int hora;
  final int atendidas;
}

class ServicioAtendido {
  const ServicioAtendido({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.duracion,
    required this.atenciones,
    required this.minutos,
  });

  final String id;
  final String nombre;
  final String? categoria;
  final int duracion;
  final int atenciones;
  final int minutos;
}

class EstilistaAtendiendo {
  const EstilistaAtendiendo({
    required this.id,
    required this.nombre,
    required this.citas,
    required this.minutos,
    required this.nuevas,
    required this.enLinea,
    required this.calificacion,
    required this.resenas,
  });

  final String id;
  final String nombre;
  final int citas;
  final int minutos;
  final int nuevas;
  final int enLinea;

  /// Promedio de las reseñas de sus citas del periodo. `null` sin reseñas.
  final double? calificacion;
  final int resenas;
}

class SemanaDeClientas {
  const SemanaDeClientas(this.semana, this.nuevas, this.vuelven);

  final DateTime semana;
  final int nuevas;
  final int vuelven;
}

class MotivoPerdido {
  const MotivoPerdido({
    required this.cancelada,
    required this.motivo,
    required this.dia,
    required this.servicios,
    required this.estilistas,
  });

  /// `true` si se canceló; `false` si no llegó.
  final bool cancelada;

  /// Tal como se escribió: es texto libre (D-312) y no se agrupa.
  final String motivo;
  final DateTime dia;
  final String? servicios;
  final String? estilistas;
}

class DashboardDeAtenciones {
  const DashboardDeAtenciones({
    required this.hoyEnLaSede,
    required this.granularidad,
    required this.sedes,
    required this.hoy,
    required this.actual,
    required this.anterior,
    required this.serie,
    required this.serieAnterior,
    required this.calor,
    required this.servicios,
    required this.equipo,
    required this.semanas,
    required this.invitacionesEnviadas,
    required this.invitacionesAgendaron,
    required this.perdidasPorDia,
    required this.perdidasEnLinea,
    required this.motivos,
  });

  final DateTime hoyEnLaSede;

  /// `day`, `week` o `month`, como el gráfico del Dashboard de siempre.
  final String granularidad;
  final int sedes;
  final HoyDeAtenciones hoy;
  final TramoDeAtenciones actual;
  final TramoDeAtenciones anterior;
  final List<PuntoDeSerie> serie;
  final List<PuntoDeSerie> serieAnterior;
  final List<CeldaDeCalor> calor;
  final List<ServicioAtendido> servicios;
  final List<EstilistaAtendiendo> equipo;
  final List<SemanaDeClientas> semanas;
  final int invitacionesEnviadas;
  final int invitacionesAgendaron;

  /// 1 = lunes … 7 = domingo.
  final Map<int, int> perdidasPorDia;
  final int perdidasEnLinea;
  final List<MotivoPerdido> motivos;

  factory DashboardDeAtenciones.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> lista(String clave) =>
        ((map[clave] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);

    List<PuntoDeSerie> serie(String clave) => [
      for (final f in lista(clave))
        PuntoDeSerie(_fecha(f['bucket']) ?? DateTime(2000), _entero(f['atendidas'])),
    ];

    final invitaciones = map['invitaciones'] is Map
        ? Map<String, dynamic>.from(map['invitaciones'] as Map)
        : const <String, dynamic>{};

    return DashboardDeAtenciones(
      hoyEnLaSede: _fecha(map['hoy_en_la_sede']) ?? DateTime.now(),
      granularidad: map['granularidad']?.toString() ?? 'day',
      sedes: _entero(map['sedes']),
      hoy: HoyDeAtenciones.fromMap(_mapa(map['hoy'])),
      actual: TramoDeAtenciones.fromMap(_mapa(map['actual'])),
      anterior: TramoDeAtenciones.fromMap(_mapa(map['anterior'])),
      serie: serie('serie'),
      serieAnterior: serie('serie_anterior'),
      calor: [
        for (final f in lista('calor'))
          CeldaDeCalor(
            _entero(f['dia_semana']),
            _entero(f['hora']),
            _entero(f['atendidas']),
          ),
      ],
      servicios: [
        for (final f in lista('servicios'))
          ServicioAtendido(
            id: f['service_id'].toString(),
            nombre: f['nombre']?.toString() ?? '',
            categoria: f['categoria']?.toString(),
            duracion: _entero(f['duracion']),
            atenciones: _entero(f['atenciones']),
            minutos: _entero(f['minutos']),
          ),
      ],
      equipo: [
        for (final f in lista('equipo'))
          EstilistaAtendiendo(
            id: f['stylist_id'].toString(),
            nombre: f['nombre']?.toString() ?? '',
            citas: _entero(f['citas']),
            minutos: _entero(f['minutos']),
            nuevas: _entero(f['nuevas']),
            enLinea: _entero(f['en_linea']),
            calificacion: f['calificacion'] == null
                ? null
                : double.tryParse(f['calificacion'].toString()),
            resenas: _entero(f['resenas']),
          ),
      ],
      semanas: [
        for (final f in lista('semanas'))
          SemanaDeClientas(
            _fecha(f['semana']) ?? DateTime(2000),
            _entero(f['nuevas']),
            _entero(f['vuelven']),
          ),
      ],
      invitacionesEnviadas: _entero(invitaciones['enviadas']),
      invitacionesAgendaron: _entero(invitaciones['agendaron']),
      perdidasPorDia: {
        for (final f in lista('perdidas_por_dia'))
          _entero(f['dia_semana']): _entero(f['n']),
      },
      perdidasEnLinea: _entero(map['perdidas_en_linea']),
      motivos: [
        for (final f in lista('motivos'))
          MotivoPerdido(
            cancelada: f['estado']?.toString() == 'cancelado',
            motivo: f['motivo']?.toString() ?? '',
            dia: _fecha(f['dia']) ?? DateTime(2000),
            servicios: f['servicios']?.toString(),
            estilistas: f['estilistas']?.toString(),
          ),
      ],
    );
  }

  /// Promedio de citas atendidas por día de la semana (1 = lunes), contando
  /// cuántas veces aparece cada día en el periodo. Un periodo con cuatro
  /// sábados y cinco lunes no puede comparar los totales a secas.
  Map<int, double> promedioPorDiaDeLaSemana(DateTime desde, DateTime hasta) {
    final veces = <int, int>{};
    for (var d = desde; !d.isAfter(hasta); d = d.add(const Duration(days: 1))) {
      veces[d.weekday] = (veces[d.weekday] ?? 0) + 1;
    }
    final total = <int, int>{};
    for (final c in calor) {
      total[c.diaSemana] = (total[c.diaSemana] ?? 0) + c.atendidas;
    }
    return {
      for (final dia in veces.keys) dia: (total[dia] ?? 0) / veces[dia]!,
    };
  }

  /// La celda con más citas. `null` si no hay ninguna.
  CeldaDeCalor? get horaPico {
    CeldaDeCalor? mejor;
    for (final c in calor) {
      if (c.atendidas > 0 && (mejor == null || c.atendidas > mejor.atendidas)) {
        mejor = c;
      }
    }
    return mejor;
  }
}

// ---------------------------------------------------------------------------
// Las palabras
// ---------------------------------------------------------------------------

const diasDeLaSemana = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
const diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// `10 a. m.`, `12 m.`, `3 p. m.`: como se dice la hora en Colombia.
String horaHablada(int hora) {
  if (hora == 0) return '12 a. m.';
  if (hora < 12) return '$hora a. m.';
  if (hora == 12) return '12 m.';
  return '${hora - 12} p. m.';
}

/// `1.234` con el punto de miles de Colombia.
String miles(num n) {
  final texto = n.round().abs().toString();
  final grupos = <String>[];
  for (var i = texto.length; i > 0; i -= 3) {
    grupos.insert(0, texto.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${n < 0 ? '-' : ''}${grupos.join('.')}';
}

/// De cada 100, cuántos: `porcentaje(1, 3)` es 33. Cero si no hay total.
int porcentaje(num parte, num total) =>
    total == 0 ? 0 : (parte * 100 / total).round();

/// Cuánto cambió contra el periodo anterior, en por ciento redondeado.
/// `null` cuando antes fue cero: un "+∞ %" no le dice nada a nadie, y es la
/// regla de oro de D-110 (no mostrar una precisión que el dato no tiene).
int? variacion(num actual, num anterior) {
  if (anterior == 0) return null;
  return ((actual - anterior) * 100 / anterior).round();
}

/// Un trozo de la historia: texto, y si va resaltado.
typedef TrozoDeHistoria = ({String texto, bool resaltado});

/// La historia del periodo, en frases cortas, con los números resaltados.
///
/// Es lo primero del tablero: lo que el dueño leería si solo leyera una
/// cosa. Solo dice lo que los números sostienen: sin citas atendidas no
/// inventa un día fuerte, y si hay un filtro puesto no habla de "el salón".
List<TrozoDeHistoria> historiaDelPeriodo(
  DashboardDeAtenciones d, {
  required String periodo,
  required DateTime desde,
  required DateTime hasta,
  String? estilista,
  String? servicio,
}) {
  final t = <TrozoDeHistoria>[];
  void dice(String s) => t.add((texto: s, resaltado: false));
  void resalta(String s) => t.add((texto: s, resaltado: true));

  final a = d.actual;
  final quien = estilista ?? 'tu salón';
  dice('En $periodo, $quien atendió ');
  resalta('${miles(a.atendidas)} ${a.atendidas == 1 ? 'cita' : 'citas'}');
  final v = variacion(a.atendidas, d.anterior.atendidas);
  if (v != null && v != 0) {
    dice(', ');
    resalta('${v.abs()} % ${v > 0 ? 'más' : 'menos'}');
    dice(' que en el periodo anterior');
  }
  dice('. ');

  if (a.atendidas == 0) return t;

  final promedios = d.promedioPorDiaDeLaSemana(desde, hasta);
  final conCitas = promedios.entries.where((e) => e.value > 0).toList();
  if (conCitas.length > 1) {
    conCitas.sort((x, y) => y.value.compareTo(x.value));
    dice('Tu día más fuerte es el ');
    resalta(diasDeLaSemana[conCitas.first.key - 1]);
    dice('. ');
  }

  if (servicio == null && d.servicios.isNotEmpty) {
    final s = d.servicios.first;
    dice('Lo más pedido: ');
    resalta(s.nombre);
    dice(' (${miles(s.atenciones)}). ');
  }

  if (estilista == null && d.equipo.length > 1) {
    final e = d.equipo.first;
    resalta(e.nombre);
    dice(' atendió más que nadie (${miles(e.citas)}). ');
  }

  if (a.enLinea > 0) {
    resalta('${porcentaje(a.enLinea, a.atendidas)} %');
    dice(' llegó por tu enlace en línea. ');
  }

  if (a.nuevas > 0) {
    dice(a.nuevas == 1 ? 'Vino ' : 'Vinieron ');
    resalta('${miles(a.nuevas)} ${a.nuevas == 1 ? 'clienta nueva' : 'clientas nuevas'}');
    if (estilista == null && servicio == null && d.invitacionesAgendaron > 0) {
      dice(', y ');
      resalta(miles(d.invitacionesAgendaron));
      dice(d.invitacionesAgendaron == 1
          ? ' agendó otra vez después de invitarla'
          : ' agendaron otra vez después de invitarlas');
    }
    dice('. ');
  }

  if (a.perdidas > 0) {
    dice('Se perdieron ${miles(a.perdidas)}: '
        '${miles(a.canceladas)} ${a.canceladas == 1 ? 'cancelada' : 'canceladas'} y '
        '${miles(a.noLlegaron)} que no ${a.noLlegaron == 1 ? 'llegó' : 'llegaron'}.');
  }

  return t;
}

/// El día más fuerte y el más flojo de la semana, en palabras. El flojo solo
/// se nombra si es uno: si varios empatan (lo normal en un periodo corto, con
/// días en cero), nombrar a uno sería arbitrario (visto en el espejo, 04-oct).
List<TrozoDeHistoria> diasFuerteYFlojo(Map<int, double> promedios) {
  final t = <TrozoDeHistoria>[];
  if (promedios.length < 2) return t;
  final orden = promedios.entries.toList()
    ..sort((x, y) => y.value.compareTo(x.value));
  final fuerte = orden.first;
  if (fuerte.value <= 0) return t;
  t.add((texto: 'El ', resaltado: false));
  t.add((texto: diasDeLaSemana[fuerte.key - 1], resaltado: true));
  t.add((
    texto: ' es tu día más fuerte (unas ${fuerte.value.round()} '
        '${fuerte.value.round() == 1 ? 'cita' : 'citas'})',
    resaltado: false,
  ));
  final minimo = orden.last.value;
  final empatados = orden.where((e) => e.value == minimo).length;
  if (empatados == 1) {
    t.add((texto: '; el ', resaltado: false));
    t.add((texto: diasDeLaSemana[orden.last.key - 1], resaltado: true));
    t.add((texto: ', el más flojo.', resaltado: false));
  } else if (minimo == 0) {
    t.add((texto: '; los demás días, sin citas.', resaltado: false));
  } else {
    t.add((texto: '.', resaltado: false));
  }
  return t;
}

/// "de 2 p. m. a 3 p. m." sin que la frase termine en punto doble.
String franjaHoraria(int hora) => 'de ${horaHablada(hora)} a ${horaHablada(hora + 1)}';

/// El titular de la historia: `86 citas atendidas, 70 clientas`.
String titularDelPeriodo(TramoDeAtenciones a) {
  if (a.atendidas == 0) return 'Todavía no hay citas atendidas en este periodo';
  return '${miles(a.atendidas)} ${a.atendidas == 1 ? 'cita atendida' : 'citas atendidas'}, '
      '${miles(a.clientas)} ${a.clientas == 1 ? 'clienta' : 'clientas'}';
}

// ---------------------------------------------------------------------------

int _entero(dynamic v) => v is int
    ? v
    : (v is num ? v.round() : int.tryParse(v?.toString() ?? '') ?? 0);

Map<String, dynamic>? _mapa(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

DateTime? _fecha(dynamic v) {
  final texto = v?.toString();
  if (texto == null || texto.isEmpty) return null;
  final p = texto.split('T').first.split('-');
  if (p.length < 3) return null;
  final a = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (a == null || m == null || d == null) return null;
  return DateTime(a, m, d);
}
