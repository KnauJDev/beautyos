import 'periodo_dashboard.dart';

/// Los indicadores de la Vista 1, con los del periodo anterior al lado
/// (tarea 2.5a, D-110; horas vendidas en 2.5b).
///
/// Llegan juntos en un solo viaje a proposito: si el numero y su comparacion
/// vinieran en dos consultas, la pantalla pintaria `$24,8M` y el `↑12,4%`
/// aparecería medio segundo despues. El parpadeo destruye justamente lo que el
/// Dashboard quiere lograr, que es entender en cinco segundos.
class DashboardOverview {
  const DashboardOverview({
    required this.ventas,
    required this.citas,
    required this.clientesAtendidos,
    required this.ticketsCobrados,
    required this.minutosVendidos,
    required this.ventasAnterior,
    required this.citasAnterior,
    required this.clientesAtendidosAnterior,
    required this.ticketsCobradosAnterior,
    required this.minutosVendidosAnterior,
    required this.hoyEnLaSede,
    required this.sedesIncluidas,
    this.primeraActividad,
  });

  /// **Dinero cobrado**, no facturado. Un servicio terminado y sin cobrar no
  /// esta aqui: vive en "por cobrar".
  final double ventas;

  /// Tickets con fecha en el periodo, **sin contar los cancelados**.
  final int citas;

  /// Clientes con al menos un cobro en el periodo. No son los registrados.
  final int clientesAtendidos;

  /// Denominador del ticket promedio.
  final int ticketsCobrados;

  /// Minutos de trabajo efectivamente vendidos: la duracion de los servicios de
  /// los tickets que se cobraron en el periodo (2.5b).
  ///
  /// **No es ocupacion y no debe presentarse como tal.** La ocupacion necesita
  /// saber cuantas horas habia disponibles, y ese dato no existe: el horario se
  /// guarda por negocio, no por profesional. Esto es solo el numerador, que si
  /// es un hecho.
  final int minutosVendidos;

  final double ventasAnterior;
  final int citasAnterior;
  final int clientesAtendidosAnterior;
  final int ticketsCobradosAnterior;
  final int minutosVendidosAnterior;

  /// Desde cuando hay historia. `null` si el negocio no tiene ni un dato:
  /// entonces no hay nada que comparar y la pantalla muestra la escalera del
  /// dia cero.
  final DateTime? primeraActividad;

  /// Que dia es **en la sede**, que no tiene por que ser el del navegador. Lo
  /// decide Postgres, que tiene la base de datos de zonas horarias completa.
  final DateTime hoyEnLaSede;

  final int sedesIncluidas;

  /// En horas, que es como lo piensa una persona. Un salon no razona en
  /// minutos.
  double get horasVendidas => minutosVendidos / 60;
  double get horasVendidasAnterior => minutosVendidosAnterior / 60;

  /// `null` cuando no se cobro nada: dividir entre cero daria infinito, y un
  /// ticket promedio infinito es justo el tipo de precision que los datos no
  /// soportan.
  double? get ticketPromedio =>
      ticketsCobrados == 0 ? null : ventas / ticketsCobrados;

  double? get ticketPromedioAnterior =>
      ticketsCobradosAnterior == 0 ? null : ventasAnterior / ticketsCobradosAnterior;

  /// Un negocio sin un solo dato todavia. La Vista 1 no dibuja indicadores:
  /// dibuja los primeros pasos.
  bool get sinHistoria => primeraActividad == null;

  Comparacion compararVentas(RangoFechas anterior) =>
      _comparar(ventas, ventasAnterior, anterior);

  Comparacion compararCitas(RangoFechas anterior) =>
      _comparar(citas, citasAnterior, anterior);

  Comparacion compararClientes(RangoFechas anterior) =>
      _comparar(clientesAtendidos, clientesAtendidosAnterior, anterior);

  /// Se compara en minutos y no en horas: el redondeo a horas haria que dos
  /// periodos distintos parecieran iguales.
  Comparacion compararHorasVendidas(RangoFechas anterior) =>
      _comparar(minutosVendidos, minutosVendidosAnterior, anterior);

  /// Sin tickets cobrados en alguno de los dos lados no hay promedio que
  /// comparar, y se trata como periodo sin movimiento en vez de forzar un cero.
  Comparacion compararTicketPromedio(RangoFechas anterior) => _comparar(
    ticketPromedio ?? 0,
    ticketPromedioAnterior ?? 0,
    anterior,
  );

  Comparacion _comparar(num actual, num previo, RangoFechas anterior) {
    return Comparacion.calcular(
      actual: actual,
      anterior: previo,
      rangoAnterior: anterior,
      primeraActividad: primeraActividad,
    );
  }

  factory DashboardOverview.fromMap(Map<String, dynamic> map) {
    return DashboardOverview(
      ventas: _double(map['sales']),
      citas: _int(map['appointments']),
      clientesAtendidos: _int(map['clients_served']),
      ticketsCobrados: _int(map['paid_tickets']),
      minutosVendidos: _int(map['minutes_sold']),
      ventasAnterior: _double(map['prev_sales']),
      citasAnterior: _int(map['prev_appointments']),
      clientesAtendidosAnterior: _int(map['prev_clients_served']),
      ticketsCobradosAnterior: _int(map['prev_paid_tickets']),
      minutosVendidosAnterior: _int(map['prev_minutes_sold']),
      primeraActividad: _fecha(map['first_activity_on']),
      hoyEnLaSede: _fecha(map['today_on']) ?? DateTime.now(),
      sedesIncluidas: _int(map['branches_included']),
    );
  }

  static double _double(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static int _int(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  /// Postgres devuelve `date` como `YYYY-MM-DD`. Se lee como fecha civil, sin
  /// hora: convertirla a instante local es lo que desplaza los dias.
  static DateTime? _fecha(dynamic valor) {
    final texto = valor?.toString();
    if (texto == null || texto.isEmpty) return null;

    final partes = texto.split('T').first.split('-');
    if (partes.length < 3) return null;

    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (ano == null || mes == null || dia == null) return null;

    return DateTime(ano, mes, dia);
  }
}
