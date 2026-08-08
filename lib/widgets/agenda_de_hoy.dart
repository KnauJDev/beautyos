import 'package:flutter/material.dart';

import '../models/dashboard_hoy.dart';
import '../theme/app_theme.dart';
import 'app_states.dart';

/// El bloque "Agenda de hoy" (2.5a, D-110).
///
/// Es el unico trozo del Dashboard que responde a **"¿qué está pasando ahora
/// mismo?"** en vez de "¿cómo me fue?". Por eso no cambia cuando el propietario
/// mueve el filtro de fechas: hoy es hoy.
class AgendaDeHoy extends StatelessWidget {
  const AgendaDeHoy({super.key, required this.hoy});

  final DashboardHoy hoy;

  @override
  Widget build(BuildContext context) {
    if (hoy.sinCitasHoy) {
      return const AppCard(
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.textMuted,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Hoy no tienes citas agendadas.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agenda de hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Cuenta(numero: hoy.citas, etiqueta: 'citas'),
              _Cuenta(
                numero: hoy.atendidas,
                etiqueta: 'atendidas',
                color: AppColors.stateConfirmed,
              ),
              _Cuenta(
                numero: hoy.pendientes,
                etiqueta: 'pendientes',
                color: hoy.pendientes > 0
                    ? AppColors.statePending
                    : AppColors.textSecondary,
              ),
            ],
          ),

          if (hoy.citas > 0) ...[
            const SizedBox(height: AppSpacing.md),
            // Una barra y no un porcentaje: cuanto del dia ya esta resuelto se
            // entiende de un vistazo, y no pretende ser una medida de
            // ocupacion, que es justo lo que D-110 dejo fuera por no tener
            // horarios por profesional.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: hoy.atendidas / hoy.citas,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.stateConfirmed,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hoy.pendientes == 0
                  ? 'Ya atendiste todo lo de hoy.'
                  : hoy.sinConfirmar > 0
                  ? '${hoy.sinConfirmar} ${hoy.sinConfirmar == 1 ? "cita está" : "citas están"} sin confirmar.'
                  : 'Te quedan ${hoy.pendientes} por atender.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cuenta extends StatelessWidget {
  const _Cuenta({
    required this.numero,
    required this.etiqueta,
    this.color = AppColors.textPrimary,
  });

  final int numero;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$numero',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// "Lo que deberías mirar": el tablero dejando de ser estadística y empezando
/// a hablar.
///
/// Es la semilla de BeautyOS Intelligence (Etapa 4). Hoy llega hasta
/// **dato → interpretación**; el paso a **oportunidad → acción** —el botón de
/// "enviar campaña de reactivación"— necesita WhatsApp o correo, y los dos
/// están pendientes.
class AvisosDelDia extends StatelessWidget {
  const AvisosDelDia({super.key, required this.avisos});

  final List<Aviso> avisos;

  @override
  Widget build(BuildContext context) {
    if (avisos.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lo que deberías mirar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final aviso in avisos)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: _color(aviso.tono), width: 3),
                  ),
                ),
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Text(
                  aviso.texto,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _color(TonoAviso tono) => switch (tono) {
    TonoAviso.bueno => AppColors.stateConfirmed,
    // Coral y no rojo: nada de esto es una emergencia, y el rojo hay que
    // reservarlo para el peligro de verdad.
    TonoAviso.atencion => AppColors.stateToCollect,
    TonoAviso.neutro => AppColors.textMuted,
  };
}
