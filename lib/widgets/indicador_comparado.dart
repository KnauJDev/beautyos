import 'package:flutter/material.dart';

import '../models/periodo_dashboard.dart';
import '../theme/app_theme.dart';
import 'app_states.dart';

/// Un indicador con su comparación (tarea 2.5a, D-110).
///
/// **Es la pieza que justifica todo el Dashboard.** `$24.800.000` no dice nada;
/// `$24.800.000 ↑12,4%` es una historia. Por eso el número y su comparación
/// viven en el mismo widget y llegan en la misma consulta: separarlos produce
/// un parpadeo en el que primero se lee el número desnudo.
///
/// Y por eso mismo esta tarjeta **nunca inventa un porcentaje**. Cuando no hay
/// con qué comparar lo dice con palabras, que es la regla de oro de D-110:
/// nunca mostrar una precisión que los datos no soportan.
class IndicadorComparado extends StatelessWidget {
  const IndicadorComparado({
    super.key,
    required this.titulo,
    required this.valor,
    required this.comparacion,
    required this.etiquetaPeriodoAnterior,
    this.origenDelDato,
  });

  final String titulo;

  /// Ya formateado. La tarjeta no sabe de pesos ni de decimales: eso lo decide
  /// quien la usa, porque no es lo mismo un ticket promedio que un conteo.
  final String valor;

  final Comparacion comparacion;

  /// "vs mes anterior", "vs los 30 días anteriores". Se escribe entero para
  /// que nadie tenga que adivinar contra qué se está comparando.
  final String etiquetaPeriodoAnterior;

  /// De dónde sale el número, en lenguaje de persona. La segunda regla de oro
  /// de D-110: todo número importante puede decir cómo se calculó.
  final String? origenDelDato;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: IndicadorComparadoDesnudo(
        titulo: titulo,
        valor: valor,
        comparacion: comparacion,
        etiquetaPeriodoAnterior: etiquetaPeriodoAnterior,
        origenDelDato: origenDelDato,
      ),
    );
  }
}

/// El mismo indicador, **sin tarjeta alrededor**.
///
/// Existe para poder meterlo dentro de otro bloque que ya tiene su propia
/// tarjeta -- como "Tu tiempo" de 2.5b -- sin anidar tarjeta dentro de tarjeta,
/// que se ve como un error de maquetacion.
class IndicadorComparadoDesnudo extends StatelessWidget {
  const IndicadorComparadoDesnudo({
    super.key,
    required this.titulo,
    required this.valor,
    required this.comparacion,
    required this.etiquetaPeriodoAnterior,
    this.origenDelDato,
  });

  final String titulo;
  final String valor;
  final Comparacion comparacion;
  final String etiquetaPeriodoAnterior;
  final String? origenDelDato;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (origenDelDato != null)
              Tooltip(
                message: origenDelDato!,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 8),
                child: const Icon(
                  Icons.info_outline,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.brandDeep,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Comparacion(
          comparacion: comparacion,
          etiquetaPeriodoAnterior: etiquetaPeriodoAnterior,
        ),
      ],
    );
  }
}

/// La línea de abajo. Tiene tres formas y ninguna es un porcentaje falso.
class _Comparacion extends StatelessWidget {
  const _Comparacion({
    required this.comparacion,
    required this.etiquetaPeriodoAnterior,
  });

  final Comparacion comparacion;
  final String etiquetaPeriodoAnterior;

  @override
  Widget build(BuildContext context) {
    switch (comparacion.estado) {
      case EstadoComparacion.disponible:
        final subio = comparacion.subio;
        final plano = comparacion.variacion == 0;

        // Verde y coral, no verde y rojo: el rojo es peligro -- eliminar,
        // cancelar -- y una bajada de ventas no es una alarma, es una noticia
        // (mismo criterio que "por cobrar" en D-101).
        final color = plano
            ? AppColors.textSecondary
            : subio
            ? AppColors.success
            : AppColors.stateToCollect;

        return Row(
          children: [
            Icon(
              plano
                  ? Icons.remove
                  : subio
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              _porcentaje(comparacion.variacion!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                etiquetaPeriodoAnterior,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        );

      case EstadoComparacion.sinMovimientoAnterior:
        // Dice "mejoraste", pero sin numero: pasar de cero a algo no se puede
        // expresar como porcentaje.
        return const Text(
          'Antes no hubo movimiento',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        );

      case EstadoComparacion.historiaInsuficiente:
        // Dice "espera", y **cuanto falta**. Este es el estado normal del
        // primer ano de cualquier negocio, asi que no puede ser una disculpa
        // gris: tiene que informar.
        final faltan = comparacion.mesesDeHistoriaQueFaltan ?? 0;
        return Text(
          faltan > 0
              ? faltan == 1
                    ? 'Falta 1 mes de historia para comparar'
                    : 'Faltan $faltan meses de historia para comparar'
              : 'Todavía no hay con qué comparar',
          maxLines: 2,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        );
    }
  }

  static String _porcentaje(double variacion) {
    final pct = variacion * 100;
    final signo = pct > 0 ? '+' : '';

    // Un decimal y no dos: la tercera cifra de un porcentaje de ventas es
    // ruido, y da una sensacion de exactitud que el dato no tiene.
    return '$signo${pct.toStringAsFixed(1).replaceAll('.', ',')}%';
  }
}
