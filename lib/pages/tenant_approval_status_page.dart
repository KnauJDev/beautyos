import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../models/tenant_subscription_status.dart';

/// Pantalla que se le muestra al dueño de un salón cuando su solicitud
/// de registro está en estado 'pending' (en revisión) o 'rejected' (rechazada).
class TenantApprovalStatusPage extends StatefulWidget {
  const TenantApprovalStatusPage({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  final TenantSubscriptionStatus status;
  final Future<void> Function() onRefresh;

  @override
  State<TenantApprovalStatusPage> createState() =>
      _TenantApprovalStatusPageState();
}

class _TenantApprovalStatusPageState extends State<TenantApprovalStatusPage> {
  bool isChecking = false;

  Future<void> _checkStatus() async {
    setState(() => isChecking = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _contactSupport() async {
    const contactInfo = 'WhatsApp Soporte Salón y Más: +57 (300) 000-0000 · Correo: hola@salonymas.com';
    await Clipboard.setData(const ClipboardData(text: contactInfo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Datos de contacto de soporte copiados al portapapeles: hola@salonymas.com'),
        backgroundColor: AppColors.brand,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.status.isPending;

    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        title: const Text('Salón y Más'),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono principal de estado
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isPending ? Colors.amber.shade50 : Colors.red.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPending ? Colors.amber.shade300 : Colors.red.shade300,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isPending ? Icons.hourglass_top_outlined : Icons.cancel_outlined,
                        color: isPending ? Colors.amber.shade800 : Colors.red.shade700,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Título y etiqueta
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.amber.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        isPending ? 'SOLICITUD EN REVISIÓN' : 'SOLICITUD NO APROBADA',
                        style: TextStyle(
                          color: isPending ? Colors.amber.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      isPending ? '¡Solicitud recibida!' : 'Estado de tu cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      isPending
                          ? 'Estamos revisando los datos de "${widget.status.tenantName}" para activar tu prueba gratis de 21 días con atención personalizada.'
                          : 'Revisamos tu solicitud para "${widget.status.tenantName}" y no fue posible habilitar tu cuenta en este momento.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isPending) ...[
                      // Tarjeta de pasos
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.brandSurface,
                          borderRadius: BorderRadius.circular(AppRadius.control),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: const [
                            _StepRow(
                              number: '1',
                              title: 'Revisión y contacto',
                              subtitle: 'Validamos tu ciudad y tipo de negocio.',
                            ),
                            SizedBox(height: 12),
                            _StepRow(
                              number: '2',
                              title: 'Activación de tu prueba',
                              subtitle: 'Tus 21 días de prueba inician al momento de aprobar.',
                            ),
                            SizedBox(height: 12),
                            _StepRow(
                              number: '3',
                              title: 'Acompañamiento inicial',
                              subtitle: 'Te ayudamos a cargar tus servicios y tu agenda.',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Motivo del rechazo
                      if (widget.status.rejectionReason != null &&
                          widget.status.rejectionReason!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(AppRadius.control),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Motivo registrado:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.status.rejectionReason!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 28),

                    // Botones de acción
                    if (isPending) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: isChecking ? null : _checkStatus,
                          icon: isChecking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_outlined),
                          label: Text(
                            isChecking
                                ? 'Consultando...'
                                : 'Verificar si ya fui aprobado',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _contactSupport,
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Contactar al equipo de soporte'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
