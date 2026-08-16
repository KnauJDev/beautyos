import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../models/platform_tenant_summary.dart';
import '../services/platform_service.dart';
import '../widgets/security_settings_dialog.dart';
import '../widgets/update_banner.dart';
import 'platform_tenant_detail_page.dart';

class PlatformPanelPage extends StatefulWidget {
  const PlatformPanelPage({super.key, required this.platformRole});

  final String platformRole;

  @override
  State<PlatformPanelPage> createState() => _PlatformPanelPageState();
}

class _PlatformPanelPageState extends State<PlatformPanelPage> {
  final platformService = const PlatformService();

  late Future<List<PlatformTenantSummary>> tenantsFuture;
  String selectedFilter = 'todos'; // 'todos', 'pendientes', 'activos', 'demo'

  bool get isOwner => widget.platformRole == 'platform_owner';

  @override
  void initState() {
    super.initState();
    tenantsFuture = platformService.listTenants();
  }

  void reload() {
    setState(() {
      tenantsFuture = platformService.listTenants();
    });
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<String?> askReason(String title, {String hint = 'Motivo (obligatorio)'}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> handleApprove(PlatformTenantSummary tenant) async {
    String selectedPlan = 'profesional';
    bool isFounder = true;
    int trialDays = 21;
    final priceController = TextEditingController();
    final discountController = TextEditingController();
    final reasonController = TextEditingController();
    bool customPricing = false;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Aprobar solicitud: ${tenant.tenantName}'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contacto: ${tenant.contactEmail} · ${tenant.whatsapp ?? "Sin WhatsApp"}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (tenant.city != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ciudad: ${tenant.city} · Sedes: ${tenant.estimatedBranches} · Equipo: ${tenant.estimatedTeamSize}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                  const Divider(height: 24),
                  const Text('Plan a asignar:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlan,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'basico', child: Text('Básico — \$160.000/mes (1 sede, 5 cuentas)')),
                      DropdownMenuItem(value: 'business', child: Text('Business — \$200.000/mes (3 sedes, 15 cuentas)')),
                      DropdownMenuItem(value: 'profesional', child: Text('Profesional — \$240.000/mes (Ilimitado + IA)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedPlan = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Precio Pionero (50% de por vida)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Aplica el 50% de descuento vitalicio para los 25 primeros salones.'),
                    value: isFounder,
                    onChanged: (val) {
                      setModalState(() {
                        isFounder = val;
                        if (isFounder) customPricing = false;
                      });
                    },
                  ),
                  if (!isFounder) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tarifa especial personalizada'),
                      value: customPricing,
                      onChanged: (val) => setModalState(() => customPricing = val ?? false),
                    ),
                    if (customPricing) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio especial en COP (opcional)',
                          hintText: 'Ej. 120000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Descuento en % (opcional)',
                          hintText: 'Ej. 30',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo del precio especial *',
                          hintText: 'Ej. Convenio gremial',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  const Text('Días de prueba gratis:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: trialDays,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 días')),
                      DropdownMenuItem(value: 14, child: Text('14 días')),
                      DropdownMenuItem(value: 21, child: Text('21 días (Estándar)')),
                      DropdownMenuItem(value: 30, child: Text('30 días')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => trialDays = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ La prueba gratis arranca en este momento exacto.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (customPricing && !isFounder) {
                  final price = priceController.text.trim();
                  final discount = discountController.text.trim();
                  final reason = reasonController.text.trim();
                  if ((price.isNotEmpty || discount.isNotEmpty) && reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Debes ingresar un motivo para el precio especial.')),
                    );
                    return;
                  }
                }
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.check_circle_outlined),
              label: const Text('Aprobar y Activar'),
            ),
          ],
        ),
      ),
    );

    if (approved != true || !mounted) return;

    try {
      int? priceCop;
      double? discountPercent;
      String? priceReason;

      if (isFounder) {
        discountPercent = 50.0;
        priceReason = 'Pionero (50% de por vida)';
      } else if (customPricing) {
        priceCop = int.tryParse(priceController.text.trim());
        discountPercent = double.tryParse(discountController.text.trim());
        priceReason = reasonController.text.trim();
      }

      await platformService.approveTenant(
        tenantId: tenant.tenantId,
        planCode: selectedPlan,
        isFounder: isFounder,
        priceCop: priceCop,
        discountPercent: discountPercent,
        priceReason: priceReason,
        trialDays: trialDays,
      );

      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡"${tenant.tenantName}" ha sido aprobado y su prueba de $trialDays días está activa!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleReject(PlatformTenantSummary tenant) async {
    final reason = await askReason(
      'Rechazar solicitud: "${tenant.tenantName}"',
      hint: 'Motivo del rechazo (ej. No cumple requisitos del piloto)',
    );
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.rejectTenant(
        tenantId: tenant.tenantId,
        reason: reason,
      );
      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud de "${tenant.tenantName}" rechazada.')),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleSuspend(PlatformTenantSummary tenant) async {
    final reason = await askReason('Suspender "${tenant.tenantName}"');
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.suspendTenant(
        tenantId: tenant.tenantId,
        reason: reason,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleReactivate(PlatformTenantSummary tenant) async {
    final reason = await askReason('Reactivar "${tenant.tenantName}"');
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.reactivateTenant(
        tenantId: tenant.tenantId,
        reason: reason,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleExtendTrial(PlatformTenantSummary tenant) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 21)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Nueva fecha de fin de prueba',
    );
    if (newDate == null || !mounted) {
      return;
    }

    final reason = await askReason('Extender prueba de "${tenant.tenantName}"');
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.extendTrial(
        tenantId: tenant.tenantId,
        newTrialEndsAt: newDate,
        reason: reason,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        title: const Text(
          'Panel de plataforma Salón y Más',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.brandDeep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: reload,
            icon: const Icon(Icons.refresh_outlined),
          ),
          IconButton(
            tooltip: 'Seguridad de tu cuenta',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SecuritySettingsDialog(),
            ),
            icon: const Icon(Icons.security_outlined),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          _buildFilterBar(),
          Expanded(child: _buildTenantList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Text('Filtrar por: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Todos'),
            selected: selectedFilter == 'todos',
            onSelected: (val) {
              if (val) setState(() => selectedFilter = 'todos');
            },
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Pendientes de Aprobación'),
            selected: selectedFilter == 'pendientes',
            selectedColor: Colors.amber.shade100,
            onSelected: (val) {
              if (val) setState(() => selectedFilter = 'pendientes');
            },
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Clientes Activos'),
            selected: selectedFilter == 'activos',
            onSelected: (val) {
              if (val) setState(() => selectedFilter = 'activos');
            },
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('De prueba'),
            selected: selectedFilter == 'demo',
            onSelected: (val) {
              if (val) setState(() => selectedFilter = 'demo');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTenantList() {
    return FutureBuilder<List<PlatformTenantSummary>>(
      future: tenantsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('No pudimos cargar los negocios.\n${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: reload, child: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }

        var tenants = snapshot.data ?? const <PlatformTenantSummary>[];

        // Aplicar filtro
        if (selectedFilter == 'pendientes') {
          tenants = tenants.where((t) => t.isPending).toList();
        } else if (selectedFilter == 'activos') {
          tenants = tenants.where((t) => !t.isDemo && !t.isPending).toList();
        } else if (selectedFilter == 'demo') {
          tenants = tenants.where((t) => t.isDemo).toList();
        }

        if (tenants.isEmpty) {
          return Center(
            child: Text(
              selectedFilter == 'pendientes'
                  ? 'No hay solicitudes pendientes de aprobación.'
                  : 'No hay negocios registrados en esta categoría.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tenants.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _TenantCard(
            tenant: tenants[index],
            isOwner: isOwner,
            onApprove: handleApprove,
            onReject: handleReject,
            onSuspend: handleSuspend,
            onReactivate: handleReactivate,
            onExtendTrial: handleExtendTrial,
            onViewData: (tenant) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PlatformTenantDetailPage(
                    tenantId: tenant.tenantId,
                    tenantName: tenant.tenantName,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.isOwner,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
    required this.onExtendTrial,
    required this.onViewData,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onSuspend;
  final ValueChanged<PlatformTenantSummary> onReactivate;
  final ValueChanged<PlatformTenantSummary> onExtendTrial;
  final ValueChanged<PlatformTenantSummary> onViewData;

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.amber.shade800;
      case 'trialing':
        return AppColors.info;
      case 'active':
        return AppColors.success;
      case 'past_due':
        return AppColors.warning;
      case 'grace':
        return AppColors.warning;
      case 'suspended':
        return AppColors.danger;
      case 'rejected':
        return Colors.red.shade800;
      case 'cancelled':
        return AppColors.textStrong;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'PENDIENTE DE APROBACIÓN';
      case 'trialing':
        return 'EN PRUEBA';
      case 'active':
        return 'ACTIVO';
      case 'past_due':
        return 'PAGO PENDIENTE';
      case 'grace':
        return 'EN GRACIA';
      case 'suspended':
        return 'SUSPENDIDO';
      case 'rejected':
        return 'RECHAZADO';
      case 'cancelled':
        return 'CANCELADO';
      default:
        return status ?? 'SIN ESTADO';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = tenant.subscriptionStatus;
    final isPending = tenant.isPending;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending ? Colors.amber.shade400 : Colors.grey.withValues(alpha: 0.2),
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      color: isPending ? Colors.amber.shade50.withValues(alpha: 0.3) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tenant.tenantName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (tenant.isDemo) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'PRUEBA',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (tenant.isFounder) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple.shade300),
                    ),
                    child: Text(
                      '★ PIONERO 50%',
                      style: TextStyle(
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${tenant.contactEmail}${tenant.whatsapp != null ? " · ${tenant.whatsapp}" : ""}'
              '${tenant.city != null ? " · ${tenant.city}" : ""}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (tenant.businessType != null || tenant.referralSource != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tipo: ${tenant.businessType ?? "General"} · Sedes: ${tenant.estimatedBranches} · Equipo: ${tenant.estimatedTeamSize}'
                '${tenant.referralSource != null ? " · Conoció por: ${tenant.referralSource}" : ""}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              status == 'pending'
                  ? 'Solicitado el: ${_formatDate(tenant.createdAt)}'
                  : status == 'trialing'
                      ? 'Prueba hasta: ${_formatDate(tenant.trialEndsAt)}'
                      : 'Periodo hasta: ${_formatDate(tenant.currentPeriodEnd)}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),

            if (tenant.isRejected && tenant.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Motivo de rechazo: ${tenant.rejectionReason}',
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Acciones principales
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPending && isOwner) ...[
                  FilledButton.icon(
                    onPressed: () => onApprove(tenant),
                    icon: const Icon(Icons.check_circle_outlined, size: 18),
                    label: const Text('Aprobar negocio'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onReject(tenant),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Rechazar solicitud'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () => onViewData(tenant),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver datos (soporte)'),
                ),
                if (!isPending && isOwner) ...[
                  if (status == 'rejected')
                    FilledButton.icon(
                      onPressed: () => onApprove(tenant),
                      icon: const Icon(Icons.restart_alt_outlined, size: 18),
                      label: const Text('Reconsiderar / Aprobar'),
                    ),
                  if (status != 'suspended' && status != 'cancelled' && status != 'rejected')
                    OutlinedButton.icon(
                      onPressed: () => onSuspend(tenant),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('Suspender'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    ),
                  if (status == 'suspended')
                    OutlinedButton.icon(
                      onPressed: () => onReactivate(tenant),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Reactivar'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                    ),
                  if (status == 'trialing')
                    OutlinedButton.icon(
                      onPressed: () => onExtendTrial(tenant),
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: const Text('Extender prueba'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
