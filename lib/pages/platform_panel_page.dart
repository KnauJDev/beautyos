import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_tenant_summary.dart';
import '../services/platform_service.dart';
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

  Future<String?> askReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (obligatorio)',
            border: OutlineInputBorder(),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text(
          'Panel de plataforma Salón y Más',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2D1B69),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: reload,
            icon: const Icon(Icons.refresh_outlined),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<PlatformTenantSummary>>(
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
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No pudimos cargar los tenants.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tenants = snapshot.data ?? const <PlatformTenantSummary>[];

          if (tenants.isEmpty) {
            return const Center(
              child: Text('Todavía no hay negocios registrados.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tenants.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _TenantCard(
                  tenant: tenants[index],
                  isOwner: isOwner,
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
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.isOwner,
    required this.onSuspend,
    required this.onReactivate,
    required this.onExtendTrial,
    required this.onViewData,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final ValueChanged<PlatformTenantSummary> onSuspend;
  final ValueChanged<PlatformTenantSummary> onReactivate;
  final ValueChanged<PlatformTenantSummary> onExtendTrial;
  final ValueChanged<PlatformTenantSummary> onViewData;

  Color _statusColor(String? status) {
    switch (status) {
      case 'trialing':
        return const Color(0xFF0288D1);
      case 'active':
        return const Color(0xFF2E7D32);
      case 'past_due':
        return const Color(0xFFF9A825);
      case 'grace':
        return const Color(0xFFEF6C00);
      case 'suspended':
        return const Color(0xFFC62828);
      case 'cancelled':
        return const Color(0xFF616161);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '—';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = tenant.subscriptionStatus;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status ?? 'sin_suscripcion',
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
              'Plan ${tenant.planCode ?? "sin plan"} · ${tenant.contactEmail}'
              '${tenant.whatsapp != null ? " · ${tenant.whatsapp}" : ""}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              status == 'trialing'
                  ? 'Prueba hasta: ${_formatDate(tenant.trialEndsAt)}'
                  : 'Periodo hasta: ${_formatDate(tenant.currentPeriodEnd)}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onViewData(tenant),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver datos (soporte)'),
                ),
              ],
            ),
            if (isOwner) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status != 'suspended' && status != 'cancelled')
                    OutlinedButton.icon(
                      onPressed: () => onSuspend(tenant),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('Suspender'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                      ),
                    ),
                  if (status == 'suspended')
                    OutlinedButton.icon(
                      onPressed: () => onReactivate(tenant),
                      icon: const Icon(
                        Icons.play_circle_outline,
                        size: 18,
                      ),
                      label: const Text('Reactivar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                      ),
                    ),
                  if (status == 'trialing')
                    OutlinedButton.icon(
                      onPressed: () => onExtendTrial(tenant),
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: const Text('Extender prueba'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
