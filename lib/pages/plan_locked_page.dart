import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Lo que ve un salón cuando entra a un módulo que su plan no cubre (TL-19,
/// D-184).
///
/// **Lo que había antes:** el módulo se mostraba igual, el dueño entraba,
/// pulsaba "Guardar" y le salía en pantalla
/// `PostgrestException: beautyos_require_entitlement: Plan no autorizado`.
///
/// **Por qué el módulo se sigue viendo, en vez de esconderlo.** Esconderlo
/// arreglaría el error y de paso mataría la venta: la escalera de planes de
/// D-124 solo funciona si el dueño ve lo que se está perdiendo. Un candado
/// explica; un módulo ausente no dice nada.
class PlanLockedPage extends StatelessWidget {
  const PlanLockedPage({
    super.key,
    required this.moduleTitle,
    required this.moduleIcon,
    required this.explicacion,
    required this.planSugerido,
    this.onIrAConfiguracion,
  });

  /// El módulo al que se intentó entrar, con su mismo nombre e icono del menú:
  /// el dueño tiene que reconocer dónde está.
  final String moduleTitle;
  final IconData moduleIcon;

  /// Qué hace ese módulo, en una frase y en el idioma del salón — no "gestión
  /// de inventario" sino "saber qué productos tienes y cuáles se están
  /// acabando".
  final String explicacion;

  /// El plan más barato que lo incluye (Plan Maestro, apartado 3).
  final String planSugerido;

  /// Lleva a Configuración, donde vive la tarjeta de Suscripción (D-158).
  final VoidCallback? onIrAConfiguracion;

  /// Número de soporte de Salón y Más (Colombia +57), el mismo de
  /// `tenant_approval_status_page`, `public_plans_page` y `settings_page`.
  static const _whatsappSoporte = '573159780158';

  Future<void> _escribirASoporte() async {
    final mensaje = Uri.encodeComponent(
      'Hola equipo de Salón y Más 👋, me gustaría mejorar mi plan para '
      'activar el módulo de $moduleTitle.',
    );

    final url = Uri.parse('https://wa.me/$_whatsappSoporte?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    // Mismo respaldo que en la pantalla de estado de solicitud: si no hay
    // WhatsApp, queda el correo de soporte (D-180).
    await launchUrl(
      Uri.parse(
        'mailto:hola@salonymas.com'
        '?subject=Quiero activar el módulo de $moduleTitle',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.brandTint,
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                        child: Icon(
                          moduleIcon,
                          color: AppColors.brandDark,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              moduleTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandDeep,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Tu plan actual no lo incluye',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    explicacion,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.brandTintSoft,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 18,
                          color: AppColors.brandDark,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Se activa con el plan $planSugerido.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  if (onIrAConfiguracion != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onIrAConfiguracion,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Ver planes y mejorar'),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.sm),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _escribirASoporte,
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: AppColors.whatsapp,
                      ),
                      label: const Text(
                        'Escríbenos por WhatsApp',
                        style: TextStyle(color: AppColors.textStrong),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    'Si crees que tu plan sí debería incluir este módulo, '
                    'cuéntanos y lo revisamos contigo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
