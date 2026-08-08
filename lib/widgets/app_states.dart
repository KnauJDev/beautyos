import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tarjeta base de la aplicacion (D-107).
///
/// Sustituye a las **153 `Card(` sueltas** que habia en `lib/pages/`, cada una
/// con sus propios margenes y esquinas. La barra de color de la izquierda es
/// el elemento de identidad decidido en D-097: muestra a la vez la marca del
/// negocio y el estado, sin gastar altura.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;

  /// Color de la barra izquierda. Sin color, no se dibuja.
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(padding: padding, child: child);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: accent == null
              ? contenido
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: AppRadius.accentBarWidth,
                        color: accent,
                      ),
                      Expanded(child: contenido),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Estado de carga.
///
/// Sustituye a los **56 sitios** que repetian a mano la misma tarjeta con un
/// circulo girando dentro.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              if (mensaje != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  mensaje!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuando no hay nada que mostrar todavia.
///
/// **No es un error y no debe parecerlo.** Un negocio recien creado no tiene
/// clientes ni tickets, y eso es normal: la pantalla invita a crear el primero
/// en vez de disculparse.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.titulo,
    required this.descripcion,
    this.accion,
  });

  final IconData icon;
  final String titulo;
  final String descripcion;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.brand),
          const SizedBox(height: AppSpacing.md),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (accion != null) ...[
            const SizedBox(height: AppSpacing.lg),
            accion!,
          ],
        ],
      ),
    );
  }
}

/// Cuando algo fallo de verdad.
///
/// A diferencia de [EmptyState], aqui **si** hay un problema, y la pantalla lo
/// dice con el color de peligro y ofrece reintentar. Hoy las dos situaciones
/// se pintan igual y no hay forma de distinguir "todavia no hay datos" de "no
/// se pudieron cargar".
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.titulo,
    this.detalle,
    this.onReintentar,
  });

  final String titulo;
  final String? detalle;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 22,
                color: AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          if (detalle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detalle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (onReintentar != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
