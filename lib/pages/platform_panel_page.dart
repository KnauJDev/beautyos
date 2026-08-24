import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/platform_tenant_summary.dart';
import '../models/tenant_subscription_history_entry.dart';
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
                          labelText: 'Precio especial en COP (ej. 30000 o 60000)',
                          hintText: 'Ej. 30000',
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
                          hintText: 'Ej. Tarifa acordada en WhatsApp / Amigo',
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

  Future<void> handleUpdatePricing(PlatformTenantSummary tenant) async {
    String selectedPlan = tenant.planCode ?? 'profesional';
    bool isFounder = tenant.isFounder;
    final priceController = TextEditingController(
      text: tenant.priceCop != null ? tenant.priceCop.toString() : '',
    );
    final discountController = TextEditingController(
      text: tenant.discountPercent != null && !isFounder ? tenant.discountPercent.toString() : '',
    );
    final reasonController = TextEditingController(
      text: isFounder ? 'Pionero (50% de por vida)' : '',
    );
    bool customPricing = tenant.priceCop != null || (tenant.discountPercent != null && !isFounder);

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Modificar Precio o Plan: ${tenant.tenantName}'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajusta el plan asignado o fija una tarifa especial en COP (ej. \$30.000, \$50.000, \$70.000).',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 24),
                  const Text('Plan Asignado:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    subtitle: const Text('Aplica el 50% de descuento vitalicio sobre el plan elegido.'),
                    value: isFounder,
                    onChanged: (val) {
                      setModalState(() {
                        isFounder = val;
                        if (isFounder) {
                          customPricing = false;
                          priceController.clear();
                          reasonController.text = 'Pionero (50% de por vida)';
                        }
                      });
                    },
                  ),
                  if (!isFounder) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fijar Tarifa Especial Personalizada en COP'),
                      subtitle: const Text('Para cobrarle un valor pactado (ej. \$30.000, \$50.000, \$70.000).'),
                      value: customPricing,
                      onChanged: (val) => setModalState(() => customPricing = val ?? false),
                    ),
                    if (customPricing) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio mensual exacto en COP (ej. 30000)',
                          hintText: 'Ej. 30000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Descuento en % (opcional si ya fijó precio en COP)',
                          hintText: 'Ej. 30',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo del precio especial *',
                          hintText: 'Ej. Convenio especial amigo / Acuerdo comercial',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
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
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar Tarifa'),
            ),
          ],
        ),
      ),
    );

    if (updated != true || !mounted) return;

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

      await platformService.updateTenantPricing(
        tenantId: tenant.tenantId,
        planCode: selectedPlan,
        isFounder: isFounder,
        priceCop: priceCop,
        discountPercent: discountPercent,
        priceReason: priceReason,
      );

      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Tarifa de "${tenant.tenantName}" actualizada exitosamente!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (e) {
      _showError('No se pudo actualizar la tarifa: $e');
    }
  }

  Future<void> handleUpdateContact(PlatformTenantSummary tenant) async {
    final nameController = TextEditingController(text: tenant.contactName ?? '');
    final emailController = TextEditingController(text: tenant.contactEmail);
    final whatsappController = TextEditingController(text: tenant.whatsapp ?? '');
    final businessTypeController = TextEditingController(text: tenant.businessType ?? '');
    final cityController = TextEditingController(text: tenant.city ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Contacto: ${tenant.tenantName}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de contacto titular *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo de contacto *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: businessTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de negocio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    border: OutlineInputBorder(),
                  ),
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
              if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre de contacto y el correo no pueden estar vacíos.')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar Contacto'),
          ),
        ],
      ),
    );

    if (updated != true || !mounted) return;

    try {
      await platformService.updateTenantContact(
        tenantId: tenant.tenantId,
        contactName: nameController.text.trim(),
        contactEmail: emailController.text.trim(),
        whatsapp: whatsappController.text.trim(),
        businessType: businessTypeController.text.trim(),
        city: cityController.text.trim(),
      );

      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Contacto de "${tenant.tenantName}" actualizado exitosamente!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (e) {
      _showError('No se pudo actualizar el contacto: $e');
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
        platformService: platformService,
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
        onUpdatePricing: (t) {
          Navigator.of(context).pop();
          handleUpdatePricing(t);
        },
        onUpdateContact: (t) {
          Navigator.of(context).pop();
          handleUpdateContact(t);
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
                          onUpdatePricing: handleUpdatePricing,
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
    required this.onUpdatePricing,
    required this.onViewSupportData,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final VoidCallback onTap;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onUpdatePricing;
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
                              ? 'Prueba: ${_formatDate(tenant.createdAt)} al ${_formatDate(tenant.trialEndsAt)}'
                              : 'Vence: ${_formatDate(tenant.currentPeriodEnd)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Fila 3: Botones de Acción Rápida (WhatsApp, Llamar, Modificar Tarifa, Ver Ficha)
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
                    if (isOwner) ...[
                      OutlinedButton.icon(
                        onPressed: () => onUpdatePricing(tenant),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Precio / Plan'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Ver Ficha →'),
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
    required this.platformService,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
    required this.onExtendTrial,
    required this.onUpdatePricing,
    required this.onUpdateContact,
    required this.onViewSupportData,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final PlatformService platformService;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onSuspend;
  final ValueChanged<PlatformTenantSummary> onReactivate;
  final ValueChanged<PlatformTenantSummary> onExtendTrial;
  final ValueChanged<PlatformTenantSummary> onUpdatePricing;
  final ValueChanged<PlatformTenantSummary> onUpdateContact;
  final ValueChanged<PlatformTenantSummary> onViewSupportData;

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final fecha = _formatDate(local);
    final hora = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$fecha $hora';
  }

  String _formatCop(int cop) {
    final digits = cop.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final pos = digits.length - i;
      buffer.write(digits[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write('.');
      }
    }
    return '\$$buffer COP';
  }

  String _pluralize(int count, String singular, String plural) =>
      count == 1 ? singular : plural;

  Widget _buildSubsectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
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
                        _buildSubsectionLabel('A. Contacto Administrativo'),
                        const SizedBox(height: 6),
                        _buildInfoRow('Negocio:', tenant.tenantName),
                        _buildInfoRow('Tipo de Negocio:', tenant.businessType ?? 'Peluquería / Salón'),
                        _buildInfoRow('Contacto Titular:', tenant.contactName ?? 'Sin registrar'),
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
                        _buildInfoRow('Teléfono:', tenant.contactPhone ?? 'Sin registrar'),
                        _buildInfoRow('Ciudad:', tenant.city ?? 'Sin registrar'),
                        _buildInfoRow('Instagram:', tenant.instagram ?? 'Sin registrar'),
                        _buildInfoRow('Facebook:', tenant.facebook ?? 'Sin registrar'),
                        if (isOwner) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => onUpdateContact(tenant),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text('Editar Contacto'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                        const Divider(height: 24),
                        _buildSubsectionLabel('B. Capacidad Operativa Real (en vivo)'),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Sedes Activas:',
                          '${tenant.realBranchesCount} ${_pluralize(tenant.realBranchesCount, 'sede registrada', 'sedes registradas')}',
                        ),
                        _buildInfoRow(
                          'Equipo Activo:',
                          '${tenant.realTeamCount} ${_pluralize(tenant.realTeamCount, 'colaborador activo', 'colaboradores activos')}: '
                              '${tenant.teamBreakdown ?? 'Sin colaboradores activos'}',
                        ),
                        _buildInfoRow(
                          'Origen / Registro:',
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 10),
                        if (isOwner)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => onUpdatePricing(tenant),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text('Modificar Precio o Plan'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppColors.brand,
                              ),
                            ),
                          ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          'Prueba Gratis:',
                          'Desde el ${_formatDate(tenant.createdAt)} hasta el ${_formatDate(tenant.trialEndsAt)}',
                        ),
                        _buildInfoRow(
                          'Periodo Activo:',
                          tenant.currentPeriodEnd != null
                              ? 'Válido hasta el ${_formatDate(tenant.currentPeriodEnd)}'
                              : 'Pendiente de primer pago tras finalizar prueba',
                        ),
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
                              OutlinedButton.icon(
                                onPressed: () => onUpdatePricing(tenant),
                                icon: const Icon(Icons.price_change_outlined, size: 18),
                                label: const Text('Cambiar Tarifa / Plan'),
                              ),
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

                    // TARJETA 4: HISTORIAL COMPLETO DE TRANSACCIONES Y PERÍODOS
                    _buildSectionCard(
                      title: '4. Historial de Periodos Registrados',
                      icon: Icons.history,
                      children: [
                        FutureBuilder<List<TenantSubscriptionHistoryEntry>>(
                          future: platformService.getTenantSubscriptionHistory(tenant.tenantId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text(
                                'No se pudo cargar el historial: ${snapshot.error}',
                                style: const TextStyle(fontSize: 12, color: AppColors.danger),
                              );
                            }

                            final history = snapshot.data ?? const [];
                            if (history.isEmpty) {
                              return const Text(
                                'Sin eventos registrados todavía.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              );
                            }

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(AppRadius.control),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 14,
                                  horizontalMargin: 10,
                                  headingRowHeight: 36,
                                  dataRowMinHeight: 38,
                                  dataRowMaxHeight: 48,
                                  columns: const [
                                    DataColumn(label: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                    DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                    DataColumn(label: Text('Período Comprometido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                    DataColumn(label: Text('Valor / Medio / Ref', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                  ],
                                  rows: history.map((entry) {
                                    final periodo = entry.periodStart != null && entry.periodEnd != null
                                        ? '${_formatDate(entry.periodStart)} al ${_formatDate(entry.periodEnd)}'
                                        : (entry.periodEnd != null
                                            ? 'Hasta ${_formatDate(entry.periodEnd)}'
                                            : '—');
                                    final detalle = entry.paymentDetail ?? entry.description ?? '—';
                                    final valor = entry.amountCop != null
                                        ? '${_formatCop(entry.amountCop!)} · $detalle'
                                        : detalle;
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(_formatDateTime(entry.createdAt), style: const TextStyle(fontSize: 11.5))),
                                        DataCell(Text(entry.planName ?? '—', style: const TextStyle(fontSize: 11.5))),
                                        DataCell(Text(periodo, style: const TextStyle(fontSize: 11.5))),
                                        DataCell(Text(valor, style: const TextStyle(fontSize: 11.5))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
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
