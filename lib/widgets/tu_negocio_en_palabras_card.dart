import 'package:flutter/material.dart';

import '../models/dashboard_hoy.dart';
import '../models/dashboard_overview.dart';
import '../models/periodo_dashboard.dart';
import '../models/ticket_board.dart' show formatCOP;
import '../theme/app_theme.dart';

/// El saludo y el párrafo narrativo de "Tu negocio en palabras" (paso 6.1,
/// D-168), ya redactados y listos para pintar.
class NarrativaNegocio {
  const NarrativaNegocio({required this.saludo, required this.mensaje});

  /// Ej. "🌅 Buenos días, Juan".
  final String saludo;

  /// El párrafo de frases, sin el saludo -- así el widget puede darle una
  /// jerarquía tipográfica distinta.
  final String mensaje;
}

/// Motor narrativo determinista del Dashboard: convierte [DashboardHoy] y
/// [DashboardOverview] en un párrafo en español colombiano, sin IA, sin
/// costo ni latencia de red -- todo lo que dice ya viaja en los datos que el
/// Dashboard carga de todas formas (paso 6.1, D-168).
///
/// Vive separado del widget a propósito, igual que [PeriodoDashboard]: es
/// lógica pura que recibe [ahora] por parámetro en vez de mirar el reloj,
/// para poder probarla sin levantar un widget ni depender de la hora real
/// de quien corre la prueba.
class NarrativaNegocioBuilder {
  const NarrativaNegocioBuilder._();

  /// 05:00–11:59 mañana, 12:00–18:29 tarde, 18:30–04:59 noche (cruza la
  /// medianoche, por eso se compara en minutos desde las 00:00 y no con un
  /// rango simple).
  static String saludo(DateTime ahora) {
    final minutos = ahora.hour * 60 + ahora.minute;
    if (minutos >= 5 * 60 && minutos < 12 * 60) return '🌅 Buenos días';
    if (minutos >= 12 * 60 && minutos < 18 * 60 + 30) return '☀️ Buenas tardes';
    return '🌙 Buenas noches';
  }

  static bool _esNoche(DateTime ahora) => saludo(ahora) == '🌙 Buenas noches';

  static String _primerNombre(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return 'por aquí';
    return limpio.split(RegExp(r'\s+')).first;
  }

  /// Arma el párrafo completo. [rangoAnterior] es opcional: sin él (o sin
  /// [overview], o en día cero) simplemente no se menciona la tendencia del
  /// período -- no es un dato obligatorio para que el resto de la historia
  /// tenga sentido.
  static NarrativaNegocio generar({
    required DashboardHoy hoy,
    DashboardOverview? overview,
    RangoFechas? rangoAnterior,
    required String nombre,
    required DateTime ahora,
  }) {
    final esNoche = _esNoche(ahora);
    final frases = <String>[
      _fraseRitmoDeCitas(hoy, esNoche),
      if (hoy.sinConfirmar > 0) _fraseSinConfirmar(hoy),
      if (hoy.porCobrarMonto > 0) _fraseParaCobrar(hoy),
      if (hoy.clientesEnRiesgo > 0) _fraseClientesEnRiesgo(hoy),
      if (overview != null && rangoAnterior != null)
        ..._fraseTendencia(overview, rangoAnterior),
    ];

    return NarrativaNegocio(
      saludo: '${saludo(ahora)}, ${_primerNombre(nombre)}',
      mensaje: frases.join(' '),
    );
  }

  static String _fraseRitmoDeCitas(DashboardHoy hoy, bool esNoche) {
    if (hoy.sinCitasHoy) {
      return esNoche
          ? 'Hoy no tuviste citas agendadas -- buen momento para poner al '
                'día tu catálogo de servicios o preparar tu portafolio de '
                'fotos para atraer nuevas clientas.'
          : 'Hoy no tienes citas agendadas todavía -- buen momento para '
                'poner al día tu catálogo de servicios o preparar tu '
                'portafolio de fotos para atraer nuevas clientas.';
    }

    final citasTexto = hoy.citas == 1 ? '1 cita' : '${hoy.citas} citas';
    final todasAtendidas = hoy.atendidas > 0 && hoy.atendidas == hoy.citas;

    if (esNoche) {
      if (hoy.atendidas == 0) return 'Hoy tuviste $citasTexto programadas.';
      return todasAtendidas
          ? 'Hoy tuviste $citasTexto programadas y las atendiste todas.'
          : 'Hoy tuviste $citasTexto programadas y atendiste ${hoy.atendidas}.';
    }

    if (hoy.atendidas == 0) return 'Hoy tienes $citasTexto programadas.';
    return todasAtendidas
        ? 'Hoy tienes $citasTexto programadas y ya las atendiste todas.'
        : 'Hoy tienes $citasTexto programadas, de las cuales ya atendiste '
              '${hoy.atendidas}.';
  }

  static String _fraseSinConfirmar(DashboardHoy hoy) {
    return hoy.sinConfirmar == 1
        ? 'Tienes 1 cita sin confirmar: escríbele por WhatsApp antes de que '
              'se te complique el día.'
        : 'Tienes ${hoy.sinConfirmar} citas sin confirmar: escríbeles por '
              'WhatsApp antes de que se te complique el día.';
  }

  static String _fraseParaCobrar(DashboardHoy hoy) {
    final monto = formatCOP(hoy.porCobrarMonto);
    return hoy.porCobrarTickets == 1
        ? 'Tienes $monto pendientes por cobrar en 1 ticket.'
        : 'Tienes $monto pendientes por cobrar en ${hoy.porCobrarTickets} '
              'tickets.';
  }

  static String _fraseClientesEnRiesgo(DashboardHoy hoy) {
    return hoy.clientesEnRiesgo == 1
        ? 'Hay 1 clienta que solía venir seguido y no ha vuelto: es buen '
              'momento para reactivarla.'
        : 'Hay ${hoy.clientesEnRiesgo} clientas que solían venir seguido y '
              'no han vuelto: es buen momento para reactivarlas.';
  }

  /// Lista de 0 o 1 frase: sin historia suficiente, o con un movimiento tan
  /// chico que no es noticia (menos del 1 %), no se dice nada -- la regla de
  /// oro de D-110 es no mostrar una precisión que el dato no soporta.
  static List<String> _fraseTendencia(
    DashboardOverview overview,
    RangoFechas rangoAnterior,
  ) {
    if (overview.sinHistoria) return const [];

    final comparacion = overview.compararVentas(rangoAnterior);
    if (comparacion.estado != EstadoComparacion.disponible) return const [];

    final variacion = comparacion.variacion;
    if (variacion == null || variacion.abs() < 0.01) return const [];

    final pct = (variacion * 100).abs().toStringAsFixed(0);
    return [
      comparacion.subio
          ? 'Este período las ventas van $pct % arriba comparado con el '
                'período anterior.'
          : 'Este período las ventas van $pct % abajo comparado con el '
                'período anterior.',
    ];
  }
}

/// Tarjeta "Tu negocio en palabras" (paso 6.1, D-168): el Dashboard contado
/// en un párrafo, con acciones rápidas para lo que pide atención hoy.
class TuNegocioEnPalabrasCard extends StatelessWidget {
  const TuNegocioEnPalabrasCard({
    super.key,
    required this.hoy,
    this.overview,
    this.rangoAnterior,
    required this.nombre,
    this.ahora,
    this.onIrAAgenda,
    this.onIrATickets,
    this.onIrAClientes,
  });

  final DashboardHoy hoy;
  final DashboardOverview? overview;
  final RangoFechas? rangoAnterior;
  final String nombre;

  /// Para pruebas. `null` usa el reloj real del dispositivo.
  final DateTime? ahora;

  final VoidCallback? onIrAAgenda;
  final VoidCallback? onIrATickets;
  final VoidCallback? onIrAClientes;

  @override
  Widget build(BuildContext context) {
    final narrativa = NarrativaNegocioBuilder.generar(
      hoy: hoy,
      overview: overview,
      rangoAnterior: rangoAnterior,
      nombre: nombre,
      ahora: ahora ?? DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandTint.withValues(alpha: 0.35),
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Tu negocio en palabras',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            narrativa.saludo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            narrativa.mensaje,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textStrong,
            ),
          ),
          if (hoy.sinConfirmar > 0 ||
              hoy.porCobrarMonto > 0 ||
              hoy.clientesEnRiesgo > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (hoy.sinConfirmar > 0)
                  ActionChip(
                    avatar: const Text('📅', style: TextStyle(fontSize: 14)),
                    label: Text('${hoy.sinConfirmar} por confirmar'),
                    onPressed: onIrAAgenda,
                    backgroundColor: AppColors.surface,
                  ),
                if (hoy.porCobrarMonto > 0)
                  ActionChip(
                    avatar: const Text('💵', style: TextStyle(fontSize: 14)),
                    label: Text('Cobrar ${formatCOP(hoy.porCobrarMonto)}'),
                    onPressed: onIrATickets,
                    backgroundColor: AppColors.surface,
                  ),
                if (hoy.clientesEnRiesgo > 0)
                  ActionChip(
                    avatar: const Text('👥', style: TextStyle(fontSize: 14)),
                    label: Text('${hoy.clientesEnRiesgo} en riesgo'),
                    onPressed: onIrAClientes,
                    backgroundColor: AppColors.surface,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
