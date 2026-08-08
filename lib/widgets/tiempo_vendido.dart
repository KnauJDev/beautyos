import 'package:flutter/material.dart';

import '../models/dashboard_overview.dart';
import '../models/periodo_dashboard.dart';
import '../theme/app_theme.dart';
import 'app_states.dart';
import 'indicador_comparado.dart';

/// Las horas vendidas (tarea 2.5b, D-110).
///
/// **Va en su propio bloque y no como quinto indicador arriba**, por dos
/// motivos. El primero es que D-110 fijo *cuatro protagonistas* y meter un
/// quinto empieza el camino de vuelta hacia el tablero de catorce cifras que
/// no comunicaba nada. El segundo es que mide otra cosa: los cuatro de arriba
/// son dinero y personas; esto es **tiempo**, que en un negocio de servicios es
/// el inventario -- una silla vacia dos horas es inventario que no vuelve.
///
/// **No dice "ocupacion" en ningun sitio, y es a proposito.** La ocupacion
/// necesita saber cuantas horas habia disponibles, y ese dato no existe: el
/// horario se guarda por negocio y no por profesional. Con lo que hay, un
/// estilista de medio tiempo saldria al 40 % aunque no hubiera tenido un hueco
/// libre. Aqui solo va el numerador, que si es un hecho, comparado contra si
/// mismo.
class TiempoVendido extends StatelessWidget {
  const TiempoVendido({
    super.key,
    required this.datos,
    required this.rangoAnterior,
    required this.etiquetaPeriodoAnterior,
  });

  final DashboardOverview datos;
  final RangoFechas rangoAnterior;
  final String etiquetaPeriodoAnterior;

  @override
  Widget build(BuildContext context) {
    final comparacion = datos.compararHorasVendidas(rangoAnterior);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 18,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Tu tiempo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          IndicadorComparadoDesnudo(
            titulo: 'Horas de trabajo vendidas',
            valor: _horas(datos.horasVendidas),
            comparacion: comparacion,
            etiquetaPeriodoAnterior: etiquetaPeriodoAnterior,
          ),

          const SizedBox(height: AppSpacing.md),
          const Text(
            'Es el tiempo que de verdad se vendió, no el que estaba '
            'disponible. Cuando cada profesional tenga su horario, aquí '
            'aparecerá también cuánto de tu capacidad se usó.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// `156 h` o `7 h 30 min`. Los minutos solo aparecen cuando son pocas horas:
  /// en 156 horas, media hora arriba o abajo no le dice nada a nadie.
  static String _horas(double horas) {
    if (horas >= 20) return '${horas.round()} h';

    final enteras = horas.floor();
    final minutos = ((horas - enteras) * 60).round();

    if (enteras == 0) return '$minutos min';
    if (minutos == 0) return '$enteras h';
    return '$enteras h $minutos min';
  }
}
