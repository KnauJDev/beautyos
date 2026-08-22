import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/platform_tenant_summary.dart';
import '../services/platform_service.dart';
import '../widgets/security_settings_dialog.dart';
import '../widgets/update_banner.dart';
import 'agenda_page.dart' show buildWhatsAppUri;
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String selectedFilter = 'todos'; // 'todos', 'pendientes', 'activos', 'trialing', 'demo', 'suspendidos'

  bool get isOwner => widget.platformRole == 'platform_owner';

  @override
  void initState() {
    super.initState();
    tenantsFuture = platformService.listTenants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    String selectedPlan = tenant.planCode ?? 'profesional';
    bool isFounder = tenant.isFounder;
    int trialDays = 21;
    final priceController = TextEditingController(
      text: tenant.priceCop != null ? tenant.priceCop.toString() : '',
    );
    final discountController = TextEditingController(
      text: tenant.discountPercent != null ? tenant.discountPercent.toString() : '',
    );
    final reasonController = TextEditingController();
    bool customPricing = tenant.priceCop != null || (tenant.discountPercent != null && !isFounder);

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Aprobar solicitud: ${tenant.tenantName}'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
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
                    subtitle: const Text('Aplica el 50% de descuento vitalicio para los primeros salones.'),
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
                          labelText: 'Precio especial en COP (ej. 60000)',
                          hintText: 'Ej. 60000',
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
                          hintText: 'Ej. Tarifa acordada en WhatsApp',
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
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _openTenantDetail(PlatformTenantSummary tenant) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TenantDetailSheet(
        tenant: tenant,
        isOwner: isOwner,
        onApprove: (t) {
          Navigator.of(context).pop();
          handleApprove(t);
        },
        onReject: (t) {
          Navigator.of(context).pop();
          handleReject(t);
        },
        onSuspend: (t) {
          Navigator.of(context).pop();
          handleSuspend(t);
        },
        onReactivate: (t) {
          Navigator.of(context).pop();
          handleReactivate(t);
        },
        onExtendTrial: (t) {
          Navigator.of(context).pop();
          handleExtendTrial(t);
        },
        onViewSupportData: (t) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlatformTenantDetailPage(
                tenantId: t.tenantId,
                tenantName: t.tenantName,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.brand, AppColors.brandDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Panel de Plataforma',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'BeautyOS SaaS Global',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Actualizar listado',
                onPressed: reload,
                icon: const Icon(Icons.refresh_outlined, color: AppColors.textSecondary),
              ),
              IconButton(
                tooltip: 'Seguridad de tu cuenta',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const SecuritySettingsDialog(),
                ),
                icon: const Icon(Icons.security_outlined, color: AppColors.textSecondary),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: signOut,
                icon: const Icon(Icons.logout_outlined, color: AppColors.danger),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
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
                    const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(
                      'No pudimos cargar los negocios.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: reload, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final allTenants = snapshot.data ?? const <PlatformTenantSummary>[];

          // Métricas globales
          final totalCount = allTenants.length;
          final pendingCount = allTenants.where((t) => t.isPending).length;
          final activeCount = allTenants.where((t) => t.isActive && !t.isDemo).length;
          final trialCount = allTenants.where((t) => t.isTrialing).length;
          final graceCount = allTenants.where((t) => t.isGrace || t.isPastDue || t.isSuspended).length;

          // Filtrar por texto
          var filtered = allTenants.where((t) {
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase().trim();
              final name = t.tenantName.toLowerCase();
              final email = t.contactEmail.toLowerCase();
              final city = (t.city ?? '').toLowerCase();
              final phone = (t.whatsapp ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              final qPhone = q.replaceAll(RegExp(r'[^0-9]'), '');

              final matches = name.contains(q) ||
                  email.contains(q) ||
                  city.contains(q) ||
                  (qPhone.isNotEmpty && phone.contains(qPhone));

              if (!matches) return false;
            }

            // Filtrar por categoría
            if (selectedFilter == 'pendientes') return t.isPending;
            if (selectedFilter == 'activos') return t.isActive && !t.isDemo;
            if (selectedFilter == 'trialing') return t.isTrialing;
            if (selectedFilter == 'demo') return t.isDemo;
            if (selectedFilter == 'suspendidos') return t.isSuspended;

            return true;
          }).toList();

          return Column(
            children: [
              const UpdateBanner(),
              // 1. KPI Banner Superior
              _PlatformKPIBanner(
                totalCount: totalCount,
                pendingCount: pendingCount,
                activeCount: activeCount,
                trialCount: trialCount,
                graceCount: graceCount,
                selectedFilter: selectedFilter,
                onFilterSelected: (filter) => setState(() => selectedFilter = filter),
              ),
              // 2. Buscador y Filtros
              _buildSearchAndFilters(pendingCount, activeCount, trialCount),
              // 3. Listado de Tarjetas
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          selectedFilter == 'pendientes'
                              ? 'No hay solicitudes pendientes de aprobación.'
                              : 'No hay negocios que coincidan con la búsqueda.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => _TenantCard(
                          tenant: filtered[index],
                          isOwner: isOwner,
                          onTap: () => _openTenantDetail(filtered[index]),
                          onApprove: handleApprove,
                          onReject: handleReject,
                          onViewSupportData: (t) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlatformTenantDetailPage(
                                  tenantId: t.tenantId,
                                  tenantName: t.tenantName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(int pending, int active, int trialing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar por salón, titular, correo, WhatsApp o ciudad...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: selectedFilter == 'todos',
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'todos');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: Text('🟡 Por Aprobar ($pending)'),
                  selected: selectedFilter == 'pendientes',
                  selectedColor: AppColors.statePendingTint,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'pendientes');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: Text('🟢 Activos ($active)'),
                  selected: selectedFilter == 'activos',
                  selectedColor: AppColors.successTint,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'activos');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: Text('⏱️ En Prueba ($trialing)'),
                  selected: selectedFilter == 'trialing',
                  selectedColor: AppColors.brandTintSoft,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'trialing');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: const Text('🧪 Demos'),
                  selected: selectedFilter == 'demo',
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'demo');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: const Text('⏸️ Suspendidos'),
                  selected: selectedFilter == 'suspendidos',
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'suspendidos');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// KPI BANNER SUPERIOR
// ============================================================================
class _PlatformKPIBanner extends StatelessWidget {
  const _PlatformKPIBanner({
    required this.totalCount,
    required this.pendingCount,
    required this.activeCount,
    required this.trialCount,
    required this.graceCount,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final int totalCount;
  final int pendingCount;
  final int activeCount;
  final int trialCount;
  final int graceCount;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _KPICard(
              title: 'Total Salones',
              count: totalCount,
              icon: Icons.storefront_outlined,
              isSelected: selectedFilter == 'todos',
              color: AppColors.textPrimary,
              onTap: () => onFilterSelected('todos'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _KPICard(
              title: 'Por Aprobar',
              count: pendingCount,
              icon: Icons.hourglass_top_outlined,
              isSelected: selectedFilter == 'pendientes',
              color: AppColors.statePending,
              onTap: () => onFilterSelected('pendientes'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _KPICard(
              title: 'Activos',
              count: activeCount,
              icon: Icons.check_circle_outline,
              isSelected: selectedFilter == 'activos',
              color: AppColors.success,
              onTap: () => onFilterSelected('activos'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _KPICard(
              title: 'En Prueba',
              count: trialCount,
              icon: Icons.schedule,
              isSelected: selectedFilter == 'trialing',
              color: AppColors.brand,
              onTap: () => onFilterSelected('trialing'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _KPICard(
              title: 'Gracia / Mora',
              count: graceCount,
              icon: Icons.warning_amber_rounded,
              isSelected: selectedFilter == 'suspendidos',
              color: AppColors.danger,
              onTap: () => onFilterSelected('suspendidos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  const _KPICard({
    required this.title,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandTintSoft : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TARJETA DE NEGOCIO / SALÓN
// ============================================================================
class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.isOwner,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onViewSupportData,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final VoidCallback onTap;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onViewSupportData;

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.statePending;
      case 'trialing':
        return AppColors.info;
      case 'active':
        return AppColors.success;
      case 'past_due':
      case 'grace':
        return AppColors.warning;
      case 'suspended':
        return AppColors.danger;
      case 'rejected':
        return AppColors.danger;
      case 'cancelled':
        return AppColors.textStrong;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'POR APROBAR';
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
        return status?.toUpperCase() ?? 'SIN ESTADO';
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: isPending ? AppColors.statePending : AppColors.border,
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      color: isPending ? AppColors.statePendingTint.withValues(alpha: 0.35) : AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Nombre del negocio y Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.tenantName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tenant.contactEmail} ${tenant.city != null ? "· 📍 ${tenant.city}" : ""}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (tenant.isDemo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'DEMO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (tenant.isFounder) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.brandTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '★ PIONERO 50%',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Fila 2: Plan, Tarifa y Vigencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sell_outlined, size: 15, color: AppColors.brand),
                    const SizedBox(width: 6),
                    Text(
                      'Plan ${tenant.planNameFormatted} (${tenant.formattedEffectivePrice})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      status == 'pending'
                          ? 'Solicitado: ${_formatDate(tenant.createdAt)}'
                          : status == 'trialing'
                              ? 'Prueba hasta: ${_formatDate(tenant.trialEndsAt)}'
                              : 'Vence: ${_formatDate(tenant.currentPeriodEnd)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Fila 3: Botones de Acción Rápida (WhatsApp, Llamar, Ver Ficha)
              Row(
                children: [
                  if (tenant.whatsapp != null && tenant.whatsapp!.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        final uri = buildWhatsAppUri(tenant.whatsapp!);
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.chat_outlined, size: 15, color: AppColors.success),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: () {
                        final uri = Uri.parse('tel:${tenant.whatsapp}');
                        launchUrl(uri);
                      },
                      icon: const Icon(Icons.phone_outlined, size: 15, color: AppColors.textSecondary),
                      label: const Text('Llamar'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isPending && isOwner) ...[
                    FilledButton.icon(
                      onPressed: () => onApprove(tenant),
                      icon: const Icon(Icons.check_circle_outlined, size: 16),
                      label: const Text('Aprobar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: () => onReject(tenant),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                  ] else ...[
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Ver Ficha y Gestión →'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FICHA COMPLETA DEL NEGOCIO / TENANT (NIVEL 3 - SEGÚN BOSQUEJO A MANO)
// ============================================================================
class _TenantDetailSheet extends StatelessWidget {
  const _TenantDetailSheet({
    required this.tenant,
    required this.isOwner,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
    required this.onExtendTrial,
    required this.onViewSupportData,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onSuspend;
  final ValueChanged<PlatformTenantSummary> onReactivate;
  final ValueChanged<PlatformTenantSummary> onExtendTrial;
  final ValueChanged<PlatformTenantSummary> onViewSupportData;

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = tenant.subscriptionStatus;
    final isPending = tenant.isPending;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            children: [
              // Header del Sheet
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tenant.tenantName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              if (tenant.isFounder)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandTint,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '★ PIONERO 50%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.brandDeep,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            'Estado: ${status?.toUpperCase() ?? "SIN ESTADO"} · Creado el ${_formatDate(tenant.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Contenido con Scroll
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // TARJETA 1: DATOS DEL NEGOCIO (IDENTIFICACIÓN Y CONTACTO)
                    _buildSectionCard(
                      title: '1. Datos de Identificación y Contacto',
                      icon: Icons.badge_outlined,
                      children: [
                        _buildInfoRow('Negocio:', tenant.tenantName),
                        _buildInfoRow('Contacto Titular:', tenant.contactEmail.split('@').first),
                        _buildInfoRow(
                          'WhatsApp:',
                          tenant.whatsapp ?? 'Sin registrar',
                          action: tenant.whatsapp != null
                              ? OutlinedButton.icon(
                                  onPressed: () {
                                    final uri = buildWhatsAppUri(tenant.whatsapp!);
                                    launchUrl(uri, mode: LaunchMode.externalApplication);
                                  },
                                  icon: const Icon(Icons.chat_outlined, size: 14, color: AppColors.success),
                                  label: const Text('Abrir WhatsApp'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    foregroundColor: AppColors.success,
                                  ),
                                )
                              : null,
                        ),
                        _buildInfoRow('Correo:', tenant.contactEmail),
                        _buildInfoRow('Tipo de Negocio:', tenant.businessType ?? 'Peluquería / Salón'),
                        _buildInfoRow('Sedes Estimadas:', tenant.estimatedBranches.toString()),
                        _buildInfoRow('Equipo Estimado:', '${tenant.estimatedTeamSize} colaboradores'),
                        _buildInfoRow(
                          'Recomendado por / Origen:',
                          tenant.referralSource ?? 'Registro directo web',
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 2: PLAN Y TARIFA MENSUAL ACTUAL (SEGÚN BOSQUEJO)
                    _buildSectionCard(
                      title: '2. Plan y Tarifa Mensual Fijada',
                      icon: Icons.sell_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Plan Asignado:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(
                                    'Plan ${tenant.planNameFormatted}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.brandTintSoft,
                                borderRadius: BorderRadius.circular(AppRadius.control),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Precio Mensual Fijado:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  Text(
                                    tenant.formattedEffectivePrice,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.brandDeep,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildInfoRow('Prueba Gratis:', 'Hasta el ${_formatDate(tenant.trialEndsAt)}'),
                        _buildInfoRow('Periodo Activo:', 'Válido hasta el ${_formatDate(tenant.currentPeriodEnd)}'),
                        if (tenant.graceEndsAt != null)
                          _buildInfoRow('Periodo de Gracia:', 'Hasta el ${_formatDate(tenant.graceEndsAt)}'),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 3: BOTONERA DE GESTIÓN Y ACCIONES
                    _buildSectionCard(
                      title: '3. Acciones de Gestión de Plataforma',
                      icon: Icons.settings_suggest_outlined,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            if (isPending && isOwner) ...[
                              FilledButton.icon(
                                onPressed: () => onApprove(tenant),
                                icon: const Icon(Icons.check_circle_outlined, size: 18),
                                label: const Text('Aprobar Negocio'),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => onReject(tenant),
                                icon: const Icon(Icons.cancel_outlined, size: 18),
                                label: const Text('Rechazar Solicitud'),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                              ),
                            ],
                            OutlinedButton.icon(
                              onPressed: () => onViewSupportData(tenant),
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              label: const Text('Ver Datos (Soporte)'),
                            ),
                            if (!isPending && isOwner) ...[
                              if (status == 'rejected')
                                FilledButton.icon(
                                  onPressed: () => onApprove(tenant),
                                  icon: const Icon(Icons.restart_alt_outlined, size: 18),
                                  label: const Text('Reconsiderar / Aprobar'),
                                ),
                              if (status == 'trialing')
                                OutlinedButton.icon(
                                  onPressed: () => onExtendTrial(tenant),
                                  icon: const Icon(Icons.schedule_outlined, size: 18),
                                  label: const Text('Extender Prueba'),
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
                            ],
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 4: HISTORIAL DE PERIODOS Y PAGOS (SEGÚN BOSQUEJO)
                    _buildSectionCard(
                      title: '4. Historial de Periodos Registrados',
                      icon: Icons.history,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.control),
                          ),
                          child: DataTable(
                            columnSpacing: 16,
                            horizontalMargin: 12,
                            headingRowHeight: 36,
                            dataRowMinHeight: 38,
                            dataRowMaxHeight: 44,
                            columns: const [
                              DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Válido Hasta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: [
                              DataRow(
                                cells: [
                                  DataCell(Text(_formatDate(tenant.createdAt), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(tenant.planNameFormatted, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(_formatDate(tenant.currentPeriodEnd ?? tenant.trialEndsAt), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(tenant.formattedEffectivePrice, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }
}
