/// Un punto del gráfico: un día, una semana o un mes, según el rango.
class PuntoSerie {
  const PuntoSerie({
    required this.fecha,
    required this.ventas,
    required this.citas,
    required this.clientesAtendidos,
    required this.ticketsCobrados,
    required this.minutosVendidos,
  });

  final DateTime fecha;
  final double ventas;
  final int citas;
  final int clientesAtendidos;
  final int ticketsCobrados;

  /// Duracion de los servicios de los tickets cobrados en este tramo (2.5b).
  final int minutosVendidos;

  /// `null` cuando no se cobró nada en el período: dividir entre cero daría
  /// infinito, y en un gráfico eso rompe la escala entera.
  double? get ticketPromedio =>
      ticketsCobrados == 0 ? null : ventas / ticketsCobrados;

  factory PuntoSerie.fromMap(Map<String, dynamic> map) {
    return PuntoSerie(
      fecha: _fecha(map['bucket_on']) ?? DateTime.now(),
      ventas: _double(map['sales']),
      citas: _int(map['appointments']),
      clientesAtendidos: _int(map['clients_served']),
      ticketsCobrados: _int(map['paid_tickets']),
      minutosVendidos: _int(map['minutes_sold']),
    );
  }

  static double _double(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);

  static DateTime? _fecha(dynamic v) {
    final texto = v?.toString();
    if (texto == null || texto.isEmpty) return null;
    final p = texto.split('T').first.split('-');
    if (p.length < 3) return null;
    final a = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (a == null || m == null || d == null) return null;
    return DateTime(a, m, d);
  }
}

/// Cada cuánto agrupa el gráfico. Lo decide el servidor según el largo del
/// rango: un año en días son 365 puntos ilegibles en un teléfono.
enum GranoSerie {
  dia,
  semana,
  mes;

  static GranoSerie desde(String? valor) => switch (valor) {
    'week' => GranoSerie.semana,
    'month' => GranoSerie.mes,
    _ => GranoSerie.dia,
  };

  /// Cómo se le nombra a un punto al señalarlo. "El mejor **día**" o "la mejor
  /// **semana**" cuentan cosas distintas y confundirlas desorienta.
  String get sustantivo => switch (this) {
    GranoSerie.dia => 'día',
    GranoSerie.semana => 'semana',
    GranoSerie.mes => 'mes',
  };
}

/// Cuál de los indicadores está dibujando el gráfico.
///
/// **Un solo gráfico hace el trabajo de cinco** (D-110): cambiar de indicador
/// no vuelve al servidor porque todos llegaron juntos.
enum IndicadorGrafico {
  ventas('Ventas'),
  citas('Citas'),
  clientes('Clientes atendidos'),
  ticketPromedio('Ticket promedio'),
  horasVendidas('Horas vendidas');

  const IndicadorGrafico(this.etiqueta);

  final String etiqueta;

  bool get esDinero =>
      this == IndicadorGrafico.ventas || this == IndicadorGrafico.ticketPromedio;

  double valorDe(PuntoSerie punto) => switch (this) {
    IndicadorGrafico.ventas => punto.ventas,
    IndicadorGrafico.citas => punto.citas.toDouble(),
    IndicadorGrafico.clientes => punto.clientesAtendidos.toDouble(),
    IndicadorGrafico.ticketPromedio => punto.ticketPromedio ?? 0,
    IndicadorGrafico.horasVendidas => punto.minutosVendidos / 60,
  };
}

class SerieDashboard {
  const SerieDashboard({required this.puntos, required this.grano});

  final List<PuntoSerie> puntos;
  final GranoSerie grano;

  bool get vacia => puntos.isEmpty;

  /// El punto más alto del indicador elegido. Es lo que sostiene la frase
  /// "tu mejor día fue el sábado con $2.450.000", que convierte un gráfico en
  /// una historia.
  ///
  /// Devuelve `null` si todo está en cero: destacar "tu mejor día" cuando no se
  /// vendió nada sería una burla.
  PuntoSerie? mejor(IndicadorGrafico indicador) {
    PuntoSerie? mejor;
    var mayor = 0.0;

    for (final punto in puntos) {
      final valor = indicador.valorDe(punto);
      if (valor > mayor) {
        mayor = valor;
        mejor = punto;
      }
    }

    return mejor;
  }

  factory SerieDashboard.fromRows(List<Map<String, dynamic>> filas) {
    return SerieDashboard(
      puntos: filas.map(PuntoSerie.fromMap).toList(growable: false),
      grano: GranoSerie.desde(
        filas.isEmpty ? null : filas.first['granularity']?.toString(),
      ),
    );
  }
}
