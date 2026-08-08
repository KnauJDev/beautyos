import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/dashboard_serie.dart';
import '../theme/app_theme.dart';
import 'app_states.dart';

/// El gráfico protagonista del Dashboard (2.5a, D-110).
///
/// **Uno solo hace el trabajo de cuatro.** El propietario elige si mira Ventas,
/// Citas, Clientes o Ticket promedio y la línea cambia sin volver al servidor,
/// porque los cuatro llegaron en la misma consulta.
///
/// Se dibuja con el color de marca del negocio (D-109), no con un color fijo:
/// es de las pocas superficies grandes donde la marca blanca se ve de verdad.
class GraficoProtagonista extends StatefulWidget {
  const GraficoProtagonista({super.key, required this.serie});

  final SerieDashboard serie;

  @override
  State<GraficoProtagonista> createState() => _GraficoProtagonistaState();
}

class _GraficoProtagonistaState extends State<GraficoProtagonista> {
  IndicadorGrafico _indicador = IndicadorGrafico.ventas;

  @override
  Widget build(BuildContext context) {
    final serie = widget.serie;

    if (serie.vacia) {
      return const EmptyState(
        icon: Icons.show_chart,
        titulo: 'Aquí aparecerá tu tendencia',
        descripcion:
            'En cuanto cobres tus primeros tickets, este gráfico empieza a '
            'contarte cómo evoluciona tu negocio.',
      );
    }

    final valores = serie.puntos.map(_indicador.valorDe).toList();
    final todoEnCero = valores.every((v) => v == 0);
    final mejor = serie.mejor(_indicador);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _indicador.etiqueta,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
              _SelectorIndicador(
                valor: _indicador,
                onCambio: (v) => setState(() => _indicador = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            height: 200,
            child: todoEnCero
                ? const Center(
                    child: Text(
                      'Sin movimiento en este período',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : _Linea(
                    serie: serie,
                    indicador: _indicador,
                    valores: valores,
                  ),
          ),

          if (mejor != null && !todoEnCero) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tu mejor ${serie.grano.sustantivo} fue el '
              '${_fechaLarga(mejor.fecha, serie.grano)} con '
              '${_formatear(_indicador.valorDe(mejor), _indicador)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatear(double valor, IndicadorGrafico indicador) {
    if (!indicador.esDinero) return valor.round().toString();

    final entero = valor.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(entero[i]);
    }
    return '\$$buffer';
  }

  static String _fechaLarga(DateTime f, GranoSerie grano) {
    const dias = [
      'lunes', 'martes', 'miércoles', 'jueves',
      'viernes', 'sábado', 'domingo',
    ];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];

    return switch (grano) {
      // El nombre del dia dice mas que la fecha: "el sabado" le cuenta al dueno
      // algo accionable sobre su semana; "el 8 de agosto" no.
      GranoSerie.dia => '${dias[f.weekday - 1]} ${f.day} de ${meses[f.month - 1]}',
      GranoSerie.semana => 'la del ${f.day} de ${meses[f.month - 1]}',
      GranoSerie.mes => '${meses[f.month - 1]} de ${f.year}',
    };
  }
}

class _SelectorIndicador extends StatelessWidget {
  const _SelectorIndicador({required this.valor, required this.onCambio});

  final IndicadorGrafico valor;
  final ValueChanged<IndicadorGrafico> onCambio;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IndicadorGrafico>(
          value: valor,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.control),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          onChanged: (v) {
            if (v != null) onCambio(v);
          },
          items: [
            for (final indicador in IndicadorGrafico.values)
              DropdownMenuItem(
                value: indicador,
                child: Text(indicador.etiqueta),
              ),
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.serie,
    required this.indicador,
    required this.valores,
  });

  final SerieDashboard serie;
  final IndicadorGrafico indicador;
  final List<double> valores;

  @override
  Widget build(BuildContext context) {
    final maximo = valores.reduce((a, b) => a > b ? a : b);

    // Un 15 % de aire arriba: una linea que toca el borde superior parece
    // recortada y no se sabe si ahi termina o sigue.
    final techo = maximo * 1.15;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: techo == 0 ? 1 : techo,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: techo == 0 ? 1 : techo / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: techo == 0 ? 1 : techo / 3,
              getTitlesWidget: (valor, meta) => Text(
                _corto(valor, indicador),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              // Como mucho seis etiquetas abajo: mas se pisan entre si en el
              // ancho de un telefono.
              interval: (serie.puntos.length / 6).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (valor, meta) {
                final i = valor.round();
                if (i < 0 || i >= serie.puntos.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _eje(serie.puntos[i].fecha, serie.grano),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItems: (puntos) => puntos.map((p) {
              final punto = serie.puntos[p.x.round()];
              return LineTooltipItem(
                '${_eje(punto.fecha, serie.grano)}\n'
                '${_completo(p.y, indicador)}',
                const TextStyle(
                  color: AppColors.textOnBrand,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < valores.length; i++)
                FlSpot(i.toDouble(), valores[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppColors.brand,
            barWidth: 2.5,
            // Los puntos solo cuando son pocos: con sesenta se convierten en
            // una hilera de manchas que tapa la propia linea.
            dotData: FlDotData(show: valores.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              // El relleno usa el color de marca del negocio, translucido: es
              // donde la marca blanca se ve en grande (D-109).
              color: AppColors.brand.withValues(alpha: 0.13),
            ),
          ),
        ],
      ),
    );
  }

  /// Para el eje vertical: `$2,4M`, `$850k`. En un eje no cabe el numero
  /// completo y tampoco hace falta -- la cifra exacta esta en el tooltip.
  static String _corto(double valor, IndicadorGrafico indicador) {
    if (!indicador.esDinero) return valor.round().toString();

    if (valor >= 1000000) {
      return '\$${(valor / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    }
    if (valor >= 1000) return '\$${(valor / 1000).round()}k';
    return '\$${valor.round()}';
  }

  static String _completo(double valor, IndicadorGrafico indicador) {
    if (!indicador.esDinero) {
      return '${valor.round()} ${indicador.etiqueta.toLowerCase()}';
    }

    final entero = valor.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(entero[i]);
    }
    return '\$$buffer';
  }

  static String _eje(DateTime f, GranoSerie grano) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];

    return switch (grano) {
      GranoSerie.dia => '${f.day} ${meses[f.month - 1]}',
      GranoSerie.semana => '${f.day} ${meses[f.month - 1]}',
      GranoSerie.mes => '${meses[f.month - 1]} ${f.year % 100}',
    };
  }
}
