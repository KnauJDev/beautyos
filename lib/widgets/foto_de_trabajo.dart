import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pinta la miniatura de una foto de trabajo, venga de donde venga (H-09).
///
/// La direccion puede ser de dos clases y la pantalla no tiene por que
/// distinguirlas: **permanente** si la foto ya esta publicada en el
/// portafolio, o **temporal firmada** si todavia espera aprobacion. Puede
/// ademas ser nula, y ese caso importa: significa que la foto existe pero no
/// se pudo conseguir permiso para verla ahora mismo.
///
/// Se dice con palabras en vez de dejar un cuadro roto, porque un cuadro roto
/// no distingue "no tienes permiso" de "el archivo se perdio".
class FotoDeTrabajo extends StatelessWidget {
  const FotoDeTrabajo({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const _Marco(
        icono: Icons.lock_outline,
        texto: 'Vista no disponible',
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const _Marco(
          icono: Icons.broken_image_outlined,
          texto: 'No se pudo cargar',
        );
      },
    );
  }
}

class _Marco extends StatelessWidget {
  const _Marco({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
