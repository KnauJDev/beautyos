import 'package:flutter/material.dart';

import '../models/periodo_dashboard.dart';
import '../theme/app_theme.dart';

/// El filtro de fechas del Dashboard (tarea 2.5a, D-110).
///
/// Ofrece los atajos que pidió el propietario —un día, una semana, de dos a
/// doce meses, un año— y además **un rango libre**, porque ninguna lista cubre
/// todos los casos.
///
/// Cada atajo declara si mide por **calendario** ("cómo voy este mes") o de
/// forma **rodante** ("cómo vengo últimamente"). No es un detalle técnico: son
/// dos preguntas distintas y el propietario tiene que saber cuál está haciendo,
/// así que se dice debajo con todas sus letras.
class FiltroPeriodo extends StatelessWidget {
  const FiltroPeriodo({
    super.key,
    required this.periodo,
    required this.onCambio,
    required this.hoy,
    this.habilitado = true,
  });

  final PeriodoDashboard periodo;
  final ValueChanged<PeriodoDashboard> onCambio;

  /// Hoy **en la sede**, no en el navegador. Decide qué rango cubre cada atajo.
  final DateTime hoy;

  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final rango = periodo.rango(hoy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `Wrap` y no `Row`: en un telefono en vertical los dos controles no
        // caben uno al lado del otro y "Otras fechas" se salia de la pantalla
        // (hallazgo del propietario, 08-ago). Asi baja a la linea siguiente en
        // vez de cortarse.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Desplegable(
              periodo: periodo,
              onCambio: onCambio,
              habilitado: habilitado,
            ),
            OutlinedButton.icon(
              onPressed: habilitado ? () => _elegirRango(context) : null,
              icon: const Icon(Icons.date_range_outlined, size: 17),
              label: const Text('Otras fechas'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_fecha(rango.desde)} a ${_fecha(rango.hasta)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _elegirRango(BuildContext context) async {
    final elegido = await showDateRangePicker(
      context: context,
      // Nada de fechas futuras: el Dashboard cuenta lo que ya pasó.
      firstDate: DateTime(2020),
      lastDate: hoy,
      currentDate: hoy,
      helpText: 'Elige las dos fechas',
      saveText: 'Aplicar',
    );

    if (elegido == null) return;

    onCambio(
      PeriodoDashboard.personalizado(
        RangoFechas(
          DateTime(elegido.start.year, elegido.start.month, elegido.start.day),
          DateTime(elegido.end.year, elegido.end.month, elegido.end.day),
        ),
      ),
    );
  }

  static String _fecha(DateTime d) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }
}

class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.periodo,
    required this.onCambio,
    required this.habilitado,
  });

  final PeriodoDashboard periodo;
  final ValueChanged<PeriodoDashboard> onCambio;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final atajos = PeriodoDashboard.atajos;
    final esPersonalizado = periodo.clave == 'personalizado';

    return Container(
      // Acotado para que un nombre largo no empuje el control fuera de la
      // pantalla de un telefono. Con `isExpanded`, lo que sobra se recorta con
      // puntos suspensivos en vez de desbordarse.
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.control),
        color: AppColors.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: esPersonalizado ? null : periodo.clave,
          hint: const Text('Rango elegido'),
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.control),
          onChanged: habilitado
              ? (clave) {
                  if (clave == null) return;
                  onCambio(atajos.firstWhere((a) => a.clave == clave));
                }
              : null,
          items: [
            for (final atajo in atajos)
              DropdownMenuItem<String>(
                value: atajo.clave,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        atajo.etiqueta,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      atajo.modo == ModoComparacion.calendario
                          ? 'del calendario'
                          : 'hacia atrás',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cómo se le explica al propietario contra qué se está comparando.
///
/// Se escribe entero —"vs 1 a 8 de julio"— en vez de "vs período anterior",
/// porque la regla de comparar contra **el mismo tramo** del mes anterior no es
/// obvia y merece verse.
String etiquetaComparacion(PeriodoDashboard periodo, DateTime hoy) {
  final anterior = periodo.rangoAnterior(hoy);

  if (periodo.clave == 'hoy') return 'vs ayer';

  final mismoAno = anterior.desde.year == anterior.hasta.year;
  final mismoMes = mismoAno && anterior.desde.month == anterior.hasta.month;

  if (mismoMes) {
    return 'vs ${anterior.desde.day} a ${anterior.hasta.day} de '
        '${_mesLargo(anterior.hasta.month)}';
  }

  return 'vs ${anterior.desde.day} ${_mesCorto(anterior.desde.month)} a '
      '${anterior.hasta.day} ${_mesCorto(anterior.hasta.month)}';
}

String _mesLargo(int mes) => const [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
][mes - 1];

String _mesCorto(int mes) => const [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
][mes - 1];
