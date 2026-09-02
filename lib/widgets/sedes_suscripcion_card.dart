import 'package:flutter/material.dart';

import '../models/branch_subscription.dart';
import '../models/tenant_subscription_status.dart';
import '../services/branch_subscriptions_service.dart';
import '../services/epayco_checkout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'app_states.dart';

/// Las sedes del negocio con su estado de pago (D-193, cierra la Etapa 3b).
///
/// **Por qué esta tarjeta llega la última de toda la Etapa 3.** Se construyó
/// primero la base (D-191), luego lo que cobra (D-192) y solo ahora la
/// pantalla, porque enseñarle a un dueño *"esta sede está pendiente"* sin un
/// botón que la pueda pagar es frustración, no información.
class SedesSuscripcionCard extends StatefulWidget {
  const SedesSuscripcionCard({super.key, required this.subscription});

  /// La suscripción del negocio. La necesita el checkout para saber a nombre de
  /// quién se paga; el monto lo calcula siempre el servidor.
  final TenantSubscriptionStatus? subscription;

  @override
  State<SedesSuscripcionCard> createState() => _SedesSuscripcionCardState();
}

class _SedesSuscripcionCardState extends State<SedesSuscripcionCard> {
  final _service = const BranchSubscriptionsService();
  final _epayco = const EpaycoCheckoutService();

  late Future<List<BranchSubscription>> _sedes;

  @override
  void initState() {
    super.initState();
    _sedes = _service.getBranchSubscriptions();
  }

  void _recargar() {
    setState(() {
      _sedes = _service.getBranchSubscriptions();
    });
  }

  Future<void> _pagar(BranchSubscription sede) async {
    final sub = widget.subscription;
    if (sub == null) return;

    await _epayco.iniciarPago(
      context,
      sub,
      branchId: sede.branchId,
      branchName: sede.branchName,
      onPaymentLaunched: _recargar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, color: AppColors.brand, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tus sedes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'El plan Todo Incluido se cobra por sede. Cada una tiene su propio '
            'estado, y todas cortan el mismo día.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          FutureBuilder<List<BranchSubscription>>(
            future: _sedes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                // Aquí se habla de dinero: una lista vacía le haría creer al
                // dueño que no tiene nada que pagar.
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'No se pudo consultar el estado de tus sedes. Vuelve '
                          'a intentarlo con el botón de actualizar.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final sedes = snapshot.data ?? const <BranchSubscription>[];
              if (sedes.isEmpty) {
                return const Text(
                  'Todavía no hay sedes registradas.',
                  style: TextStyle(color: AppColors.textMuted),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < sedes.length; i++) ...[
                    if (i > 0) const Divider(height: AppSpacing.xl),
                    _FilaSede(
                      sede: sedes[i],
                      onPagar: widget.subscription == null
                          ? null
                          : () => _pagar(sedes[i]),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilaSede extends StatelessWidget {
  const _FilaSede({required this.sede, this.onPagar});

  final BranchSubscription sede;
  final VoidCallback? onPagar;

  @override
  Widget build(BuildContext context) {
    final color = sede.alDia ? AppColors.success : AppColors.warning;
    final fondo = sede.alDia ? AppColors.successTint : AppColors.warningTint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sede.branchName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (sede.isPrimary) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandTint,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Principal',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detalle(sede),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                sede.etiquetaEstado,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),

        if (!sede.alDia && onPagar != null) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onPagar,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(
                sede.nuncaActivada
                    ? 'Activar esta sede'
                    : 'Ponerla al día',
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _detalle(BranchSubscription sede) {
    final precio = '\$${_miles(sede.precioCop)} al mes';

    if (sede.alDia && sede.currentPeriodEnd != null) {
      final f = sede.currentPeriodEnd!;
      return '$precio · hasta el ${f.day}/${f.month}/${f.year}';
    }

    if (sede.nuncaActivada) {
      // Se dice el precio del mes, no el prorrateado: el importe real depende
      // del día y lo calcula el servidor (D-191). Prometer aquí una cifra que
      // luego no cuadre con ePayco es peor que no decir ninguna.
      return '$precio · se cobra solo hasta tu fecha de corte';
    }

    return precio;
  }

  String _miles(int valor) {
    final digitos = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      final restantes = digitos.length - i;
      buffer.write(digitos[i]);
      if (restantes > 1 && restantes % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }
}
