/// El bloque "Agenda de hoy" y los avisos (2.5a, D-110).
///
/// **No depende del rango elegido arriba a propósito:** hoy es hoy, mire el
/// propietario el mes o el año. Y "por cobrar" y "clientes en riesgo" se miran
/// sobre todo el historial, porque una cuenta de hace tres meses sigue sin
/// cobrarse aunque el filtro diga "esta semana".
class DashboardHoy {
  const DashboardHoy({
    required this.hoy,
    required this.citas,
    required this.atendidas,
    required this.pendientes,
    required this.sinConfirmar,
    required this.porCobrarMonto,
    required this.porCobrarTickets,
    required this.clientesEnRiesgo,
  });

  final DateTime hoy;

  /// Citas de hoy, sin contar las canceladas.
  final int citas;

  /// Finalizadas o cerradas.
  final int atendidas;

  /// Todo lo que todavía exige algo: desde solicitado hasta en proceso.
  final int pendientes;

  /// Las que ni siquiera están confirmadas. Son las que piden una llamada.
  final int sinConfirmar;

  /// Dinero ya trabajado que nadie cobró.
  final double porCobrarMonto;
  final int porCobrarTickets;

  /// Clientes que venían dos veces o más y llevan más de 45 días sin aparecer.
  final int clientesEnRiesgo;

  bool get sinCitasHoy => citas == 0;

  factory DashboardHoy.fromMap(Map<String, dynamic> map) {
    return DashboardHoy(
      hoy: _fecha(map['today_on']) ?? DateTime.now(),
      citas: _int(map['appointments_today']),
      atendidas: _int(map['attended_today']),
      pendientes: _int(map['pending_today']),
      sinConfirmar: _int(map['unconfirmed_today']),
      porCobrarMonto: _double(map['receivable_amount']),
      porCobrarTickets: _int(map['receivable_tickets']),
      clientesEnRiesgo: _int(map['clients_at_risk']),
    );
  }

  static double _double(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static int _int(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);

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

/// El tono de un aviso. **No hay rojo**: el rojo es peligro —eliminar,
/// cancelar— y ningún aviso del Dashboard es una emergencia. Lo que pide
/// atención va en coral, igual que "por cobrar" en D-101.
enum TonoAviso { bueno, atencion, neutro }

/// Un aviso de "lo que deberías mirar".
///
/// Son la semilla de lo que en la Etapa 4 será BeautyOS Intelligence: hoy
/// **dato → interpretación**; entonces será **dato → interpretación →
/// oportunidad → acción**. El botón de "enviar campaña" no está porque depende
/// de WhatsApp o del correo, todavía en sandbox.
class Aviso {
  const Aviso({required this.texto, required this.tono});

  final String texto;
  final TonoAviso tono;
}
