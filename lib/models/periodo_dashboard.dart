/// Motor de períodos y comparación del Dashboard (tarea 2.5a, D-110).
///
/// **Esto es el cimiento, no una pieza más.** La tesis del Dashboard es que un
/// número solo no comunica y un número comparado sí: `$1.280.000` no dice nada,
/// `$1.280.000 ↑18,4%` es una historia. Todo lo demás se apoya aquí.
///
/// Se construyó como lógica pura y sin dependencias justamente para poder
/// probarlo: las reglas de fechas son donde viven los errores que nadie ve
/// hasta que un cierre de caja no cuadra.
///
/// **Sobre la zona horaria.** Aquí solo hay *fechas civiles* — año, mes y día —,
/// nunca instantes. Quién es "hoy" lo decide la sede, y esa conversión la hace
/// Postgres, que tiene la base de datos de zonas horarias completa. Por eso
/// todos los métodos reciben [hoy] en vez de mirar el reloj: mirar el reloj del
/// navegador daría el día equivocado a partir de las 7 de la noche.
library;

/// Cómo se busca el período con el que comparar.
enum ModoComparacion {
  /// "¿Cómo voy este mes?" — contra **el mismo tramo** del período calendario
  /// anterior: del 1 al 8 de agosto contra del 1 al 8 de julio.
  ///
  /// Nunca contra el mes anterior completo, o todo negocio parecería hundirse
  /// los primeros veinte días de cada mes.
  calendario,

  /// "¿Cómo vengo últimamente?" — contra la ventana inmediatamente anterior
  /// del mismo largo.
  rodante,
}

/// Un rango de fechas civiles, con los dos extremos incluidos.
class RangoFechas {
  const RangoFechas(this.desde, this.hasta);

  /// Primer día del rango, incluido.
  final DateTime desde;

  /// Último día del rango, incluido.
  final DateTime hasta;

  /// Días que abarca. Un rango de un solo día mide 1, no 0.
  int get dias => hasta.difference(desde).inDays + 1;

  bool contiene(DateTime dia) =>
      !dia.isBefore(desde) && !dia.isAfter(hasta);

  @override
  bool operator ==(Object other) =>
      other is RangoFechas && other.desde == desde && other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);

  @override
  String toString() => '${_texto(desde)}..${_texto(hasta)}';

  static String _texto(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Un período que el propietario puede elegir en el filtro.
class PeriodoDashboard {
  const PeriodoDashboard({
    required this.clave,
    required this.etiqueta,
    required this.modo,
    this.meses,
    this.dias,
    this.rangoFijo,
  });

  /// Identificador estable. Es lo que se guarda si algún día recordamos la
  /// última selección del usuario.
  final String clave;

  final String etiqueta;
  final ModoComparacion modo;

  /// Para los atajos rodantes de N meses.
  final int? meses;

  /// Para los atajos rodantes de N días.
  final int? dias;

  /// Para el rango libre que elige el propietario en el calendario.
  final RangoFechas? rangoFijo;

  // ---------------------------------------------------------------------
  // Atajos de calendario. Responden "cómo voy este mes".
  // ---------------------------------------------------------------------

  static const hoy = PeriodoDashboard(
    clave: 'hoy',
    etiqueta: 'Hoy',
    modo: ModoComparacion.calendario,
  );

  static const estaSemana = PeriodoDashboard(
    clave: 'esta_semana',
    etiqueta: 'Esta semana',
    modo: ModoComparacion.calendario,
  );

  static const esteMes = PeriodoDashboard(
    clave: 'este_mes',
    etiqueta: 'Este mes',
    modo: ModoComparacion.calendario,
  );

  static const esteAno = PeriodoDashboard(
    clave: 'este_ano',
    etiqueta: 'Este año',
    modo: ModoComparacion.calendario,
  );

  // ---------------------------------------------------------------------
  // Atajos rodantes. Responden "cómo vengo últimamente".
  // ---------------------------------------------------------------------

  static const ultimos7Dias = PeriodoDashboard(
    clave: 'ultimos_7_dias',
    etiqueta: 'Últimos 7 días',
    modo: ModoComparacion.rodante,
    dias: 7,
  );

  static const ultimos30Dias = PeriodoDashboard(
    clave: 'ultimos_30_dias',
    etiqueta: 'Últimos 30 días',
    modo: ModoComparacion.rodante,
    dias: 30,
  );

  /// De 2 a 12 meses hacia atrás. El propietario los pidió uno por uno
  /// —bimestre, trimestre, cuatrimestre y así hasta el año—, y salen todos de
  /// la misma regla en vez de una lista de casos especiales.
  static PeriodoDashboard ultimosMeses(int meses) {
    assert(meses >= 2 && meses <= 12);
    return PeriodoDashboard(
      clave: 'ultimos_${meses}_meses',
      etiqueta: meses == 12 ? 'Último año' : 'Últimos $meses meses',
      modo: ModoComparacion.rodante,
      meses: meses,
    );
  }

  /// Dos fechas cualesquiera elegidas en el calendario. Cubre todo lo que no
  /// esté en la lista de atajos.
  static PeriodoDashboard personalizado(RangoFechas rango) {
    return PeriodoDashboard(
      clave: 'personalizado',
      etiqueta: 'Rango elegido',
      modo: ModoComparacion.rodante,
      rangoFijo: rango,
    );
  }

  /// Los atajos que se ofrecen en el filtro, en orden.
  static List<PeriodoDashboard> get atajos => <PeriodoDashboard>[
    hoy,
    estaSemana,
    esteMes,
    ultimos7Dias,
    ultimos30Dias,
    for (var m = 2; m <= 12; m++) ultimosMeses(m),
    esteAno,
  ];

  // ---------------------------------------------------------------------
  // Cálculo de rangos.
  // ---------------------------------------------------------------------

  /// El rango que se está mirando. [hoy] es la fecha civil **en la sede**.
  RangoFechas rango(DateTime hoy) {
    final fin = _soloFecha(hoy);

    if (rangoFijo != null) return rangoFijo!;

    switch (clave) {
      case 'hoy':
        return RangoFechas(fin, fin);
      case 'esta_semana':
        // La semana arranca en lunes: es el día que un salón entiende como
        // comienzo, no el domingo.
        return RangoFechas(fin.subtract(Duration(days: fin.weekday - 1)), fin);
      case 'este_mes':
        return RangoFechas(DateTime(fin.year, fin.month, 1), fin);
      case 'este_ano':
        return RangoFechas(DateTime(fin.year, 1, 1), fin);
    }

    if (dias != null) {
      return RangoFechas(fin.subtract(Duration(days: dias! - 1)), fin);
    }

    if (meses != null) {
      return RangoFechas(_restarMeses(fin, meses!), fin);
    }

    return RangoFechas(fin, fin);
  }

  /// El rango contra el que se compara. Devuelve `null` solo si el período no
  /// admite comparación, cosa que hoy no ocurre con ninguno.
  RangoFechas rangoAnterior(DateTime hoy) {
    final actual = rango(hoy);

    if (modo == ModoComparacion.rodante) {
      // La ventana pegada justo antes, del mismo largo exacto.
      final fin = actual.desde.subtract(const Duration(days: 1));
      return RangoFechas(fin.subtract(Duration(days: actual.dias - 1)), fin);
    }

    // Calendario: el **mismo tramo** del período anterior.
    switch (clave) {
      case 'hoy':
        final ayer = actual.desde.subtract(const Duration(days: 1));
        return RangoFechas(ayer, ayer);

      case 'esta_semana':
        return RangoFechas(
          actual.desde.subtract(const Duration(days: 7)),
          actual.hasta.subtract(const Duration(days: 7)),
        );

      case 'este_mes':
        final inicio = _restarMeses(actual.desde, 1);
        return RangoFechas(inicio, _mismoDiaMesAnterior(actual.hasta));

      case 'este_ano':
        return RangoFechas(
          DateTime(actual.desde.year - 1, 1, 1),
          _mismoDiaAnoAnterior(actual.hasta),
        );
    }

    final fin = actual.desde.subtract(const Duration(days: 1));
    return RangoFechas(fin.subtract(Duration(days: actual.dias - 1)), fin);
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Resta meses conservando el día, y si ese día no existe en el mes destino
  /// —el caso del 31 de marzo contra "31 de febrero"— usa el último día de ese
  /// mes. Sin esto, `DateTime` desbordaría al 3 de marzo y la comparación
  /// saldría de un mes equivocado.
  static DateTime _restarMeses(DateTime fecha, int meses) {
    final totalMeses = fecha.year * 12 + (fecha.month - 1) - meses;
    final ano = totalMeses ~/ 12;
    final mes = totalMeses % 12 + 1;
    return DateTime(ano, mes, _diaValido(ano, mes, fecha.day));
  }

  static DateTime _mismoDiaMesAnterior(DateTime fecha) =>
      _restarMeses(fecha, 1);

  static DateTime _mismoDiaAnoAnterior(DateTime fecha) {
    final ano = fecha.year - 1;
    return DateTime(ano, fecha.month, _diaValido(ano, fecha.month, fecha.day));
  }

  static int _diaValido(int ano, int mes, int dia) {
    final ultimo = DateTime(ano, mes + 1, 0).day;
    return dia > ultimo ? ultimo : dia;
  }
}

/// Por qué una comparación se puede mostrar, o por qué no.
enum EstadoComparacion {
  /// Hay historia y hubo movimiento: se puede mostrar el porcentaje.
  disponible,

  /// El rango anterior empieza antes de que el negocio existiera. Dice
  /// **"espera"**, no "vas mal".
  historiaInsuficiente,

  /// El negocio ya existía pero no hubo movimiento. Dice **"mejoraste"**, pero
  /// no como porcentaje: pasar de 0 a algo no es "↑∞%".
  sinMovimientoAnterior,
}

/// El resultado de comparar un valor con su período anterior.
///
/// La regla de oro de D-110 vive aquí: **nunca se muestra una precisión que los
/// datos no soportan**. Si no hay con qué comparar, no hay porcentaje — ni cero,
/// ni infinito, ni un guion que el propietario interprete como "no cambió".
class Comparacion {
  const Comparacion._({
    required this.estado,
    required this.actual,
    required this.anterior,
    this.variacion,
    this.mesesDeHistoriaQueFaltan,
  });

  final EstadoComparacion estado;
  final num actual;
  final num anterior;

  /// Fracción, no porcentaje: `0.124` es un 12,4 % de subida. Solo tiene valor
  /// cuando [estado] es [EstadoComparacion.disponible].
  final double? variacion;

  /// Cuánta historia le falta al negocio para poder comparar este rango. Sirve
  /// para el aviso que dice *cuánto falta* en vez de disculparse.
  final int? mesesDeHistoriaQueFaltan;

  bool get subio => (variacion ?? 0) > 0;
  bool get bajo => (variacion ?? 0) < 0;

  /// Compara [actual] contra [anterior] decidiendo antes si tiene sentido.
  ///
  /// [rangoAnterior] es el tramo con el que se compara y [primeraActividad] la
  /// fecha del primer dato real del negocio. Si el negocio no existía durante
  /// todo ese tramo, no se compara: se avisa.
  static Comparacion calcular({
    required num actual,
    required num anterior,
    required RangoFechas rangoAnterior,
    required DateTime? primeraActividad,
  }) {
    if (primeraActividad == null ||
        rangoAnterior.desde.isBefore(
          DateTime(
            primeraActividad.year,
            primeraActividad.month,
            primeraActividad.day,
          ),
        )) {
      return Comparacion._(
        estado: EstadoComparacion.historiaInsuficiente,
        actual: actual,
        anterior: anterior,
        mesesDeHistoriaQueFaltan: _mesesQueFaltan(
          rangoAnterior,
          primeraActividad,
        ),
      );
    }

    if (anterior == 0) {
      return Comparacion._(
        estado: EstadoComparacion.sinMovimientoAnterior,
        actual: actual,
        anterior: anterior,
      );
    }

    return Comparacion._(
      estado: EstadoComparacion.disponible,
      actual: actual,
      anterior: anterior,
      variacion: (actual - anterior) / anterior.abs(),
    );
  }

  static int _mesesQueFaltan(RangoFechas anterior, DateTime? primeraActividad) {
    if (primeraActividad == null) return 0;

    final diasQueFaltan = primeraActividad.difference(anterior.desde).inDays;
    if (diasQueFaltan <= 0) return 0;

    // Se redondea hacia arriba: decir "te falta 1 mes" cuando faltan 40 días
    // sería otra precisión que el dato no soporta.
    return (diasQueFaltan / 30).ceil();
  }
}
