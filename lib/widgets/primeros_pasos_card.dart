import 'package:flutter/material.dart';

import '../models/onboarding_progress.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'app_states.dart';

/// La lista de "Primeros pasos" del salón nuevo, en el Dashboard
/// (paso 8.8, D-186).
///
/// **Qué reemplaza.** Antes había una tarjeta `_DiaCero` que enumeraba tres
/// cosas por hacer, pero era **texto**: no sabía cuáles estaban hechas y no
/// llevaba a ninguna parte. El dueño la leía, asentía, y seguía sin saber por
/// dónde empezar.
///
/// **Las tres cosas que la hacen distinta:** sabe qué está hecho, cada paso
/// lleva de un toque a la pantalla donde se hace, y **tiene un final** — cuando
/// los cuatro están listos deja de aparecer sola, sin que nadie la cierre.
class PrimerosPasosCard extends StatelessWidget {
  const PrimerosPasosCard({
    super.key,
    required this.progreso,
    required this.onIrAServicios,
    required this.onIrAEstilistas,
    required this.onIrAConfiguracion,
    required this.onIrAAgenda,
    required this.onDescartar,
  });

  final OnboardingProgress progreso;

  final VoidCallback onIrAServicios;
  final VoidCallback onIrAEstilistas;
  final VoidCallback onIrAConfiguracion;
  final VoidCallback onIrAAgenda;

  /// "Ya lo tengo listo": para el salón que trajo su negocio ya montado y no
  /// quiere una lista de tareas encima del tablero.
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final restantes = progreso.pasosTotales - progreso.pasosCompletos;

    return AppCard(
      accent: AppColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primeros pasos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      restantes == 1
                          ? 'Te falta uno para poder cobrar tu primera cita.'
                          : 'Te faltan $restantes para poder cobrar tu primera cita.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _Contador(
                completos: progreso.pasosCompletos,
                totales: progreso.pasosTotales,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progreso.pasosTotales == 0
                  ? 0
                  : progreso.pasosCompletos / progreso.pasosTotales,
              minHeight: 6,
              backgroundColor: AppColors.brandTint,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _PasoInteractivo(
            icono: Icons.content_cut_outlined,
            titulo: 'Crea tus servicios y sus precios',
            ayuda: 'Lo que ofreces, cuánto cuesta y cuánto dura.',
            hecho: progreso.tieneServicios,
            onIr: onIrAServicios,
          ),
          _PasoInteractivo(
            icono: Icons.badge_outlined,
            titulo: 'Suma a tu equipo',
            ayuda: 'Quién atiende, y qué servicios hace cada quien.',
            hecho: progreso.tieneEquipo,
            onIr: onIrAEstilistas,
          ),
          _PasoInteractivo(
            icono: Icons.schedule_outlined,
            titulo: 'Configura tu horario',
            ayuda: 'Sin horario no hay horas disponibles que ofrecer.',
            hecho: progreso.tieneHorario,
            onIr: onIrAConfiguracion,
          ),
          _PasoInteractivo(
            icono: Icons.event_available_outlined,
            titulo: 'Agenda tu primera cita',
            ayuda: 'Puede ser de prueba: así ves el recorrido completo.',
            hecho: progreso.tienePrimeraCita,
            onIr: onIrAAgenda,
            esUltimo: true,
          ),

          const SizedBox(height: AppSpacing.sm),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDescartar,
              child: const Text(
                'Ya lo tengo listo, ocultar',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.completos, required this.totales});

  final int completos;
  final int totales;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$completos de $totales',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.brandDark,
        ),
      ),
    );
  }
}

class _PasoInteractivo extends StatelessWidget {
  const _PasoInteractivo({
    required this.icono,
    required this.titulo,
    required this.ayuda,
    required this.hecho,
    required this.onIr,
    this.esUltimo = false,
  });

  final IconData icono;
  final String titulo;
  final String ayuda;
  final bool hecho;
  final VoidCallback onIr;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: esUltimo ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hecho ? AppColors.successTint : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(
              hecho ? Icons.check_rounded : icono,
              size: 18,
              color: hecho ? AppColors.success : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: hecho ? FontWeight.w500 : FontWeight.w600,
                    color: hecho
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    // Tachado suave: el paso hecho se ve hecho de un vistazo,
                    // sin desaparecer -- que se vea lo que ya se logró es la
                    // mitad de para qué sirve una lista así.
                    decoration: hecho ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
                if (!hecho) ...[
                  const SizedBox(height: 2),
                  Text(
                    ayuda,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (!hecho)
            FilledButton.tonal(
              onPressed: onIr,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Empezar', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
