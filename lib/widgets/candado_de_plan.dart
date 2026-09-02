import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// El aviso que sale al tocar una acción que el plan del negocio no cubre
/// (paso 8.14, D-187).
///
/// **Por qué existe aparte de `PlanLockedPage` (D-184).** Aquella bloquea
/// módulos enteros, y sirve donde el backend impide **todo** el módulo. Pero
/// hay dos acciones sueltas que el plan tampoco cubre y cuyo módulo sí
/// funciona:
///
///   - **Subir una foto de trabajo** (`create_work_photo` exige `portfolio`).
///     La galería se ve, y bloquear el módulo entero le escondería a un salón
///     las fotos que ya tiene.
///   - **Copiar el enlace de reseña** (`public_create_review` exige `reviews`).
///     Y este es el peor de los dos: el salón copia el enlace, se lo manda a la
///     clienta por WhatsApp, y **es la clienta** quien se estrella contra el
///     error. El daño no lo recibe quien tiene el plan.
///
/// Se muestra el botón y se explica, en vez de esconderlo: mismo criterio que
/// D-184, porque la escalera de planes solo funciona si el dueño ve lo que se
/// está perdiendo.
Future<void> mostrarCandadoDePlan(
  BuildContext context, {
  required String titulo,
  required String explicacion,
  required String planSugerido,
  bool puedeMejorarElPlan = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(titulo)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explicacion,
            style: const TextStyle(height: 1.45, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.brandTintSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Text(
              puedeMejorarElPlan
                  // Al dueño se le dice qué hacer.
                  ? 'Se activa con el plan $planSugerido. Puedes verlo en '
                        'Configuración → Suscripción.'
                  // Al estilista no: no es su decisión, y mandarlo a una
                  // pantalla que no puede tocar solo lo frustra.
                  : 'Se activa con el plan $planSugerido. Coméntaselo a quien '
                        'lleva el salón.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandDark,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
