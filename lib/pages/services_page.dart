import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/service_management_item.dart';
import '../services/services_service.dart';
import '../widgets/app_widgets.dart';

class ServiciosPage extends StatefulWidget {
  const ServiciosPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<ServiciosPage> createState() => _ServiciosPageState();
}

class _ServiciosPageState extends State<ServiciosPage> {
  final ServicesService servicesService = const ServicesService();
  late Future<List<ServiceManagementItem>> servicesFuture;

  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    servicesFuture = servicesService.getServicesForManagement(
      widget.branchId,
    );
  }

  void reload() {
    setState(() {
      servicesFuture = servicesService.getServicesForManagement(
        widget.branchId,
      );
    });
  }

  Future<void> openCreateServiceDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServiceFormDialog(
        branchId: widget.branchId,
        servicesService: servicesService,
        existing: null,
      ),
    );

    if (saved == true) reload();
  }

  Future<void> openEditServiceDialog(ServiceManagementItem service) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServiceFormDialog(
        branchId: widget.branchId,
        servicesService: servicesService,
        existing: service,
      ),
    );

    if (saved == true) reload();
  }

  Future<void> toggleActive(ServiceManagementItem service) async {
    try {
      await servicesService.setServiceActive(
        branchId: widget.branchId,
        serviceId: service.id,
        active: !service.active,
      );
      reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    }
  }

  List<ServiceManagementItem> _filterServices(List<ServiceManagementItem> services) {
    return services.where((s) {
      // 1. Filtro por categoría o inactivo
      if (_selectedCategory == 'inactive') {
        if (s.active) return false;
      } else if (_selectedCategory != 'all') {
        if (!s.active || s.category != _selectedCategory) return false;
      } else {
        if (!s.active && _selectedCategory != 'inactive') return false;
      }

      // 2. Filtro por texto
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = s.name.toLowerCase().contains(query);
        final categoryMatch = s.category.toLowerCase().contains(query);
        if (!nameMatch && !categoryMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Servicios',
      subtitle: 'Catálogo de servicios y precios del negocio.',
      children: [
        const InfoPanel(
          icon: Icons.spa_outlined,
          title: 'Catálogo de servicios conectado a Supabase',
          description:
              'Crea, edita o desactiva los servicios de tu centro de estética. Los servicios activos se ofrecen en la agenda y reservas públicas.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: openCreateServiceDialog,
            icon: const Icon(Icons.add_outlined),
            label: const Text('Agregar servicio'),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ServiceManagementItem>>(
          future: servicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                color: AppColors.surface,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los servicios',
                description: snapshot.error.toString(),
              );
            }

            final allServices = snapshot.data ?? [];
            final activeServices = allServices.where((s) => s.active).toList();
            final inactiveCount = allServices.where((s) => !s.active).length;

            final categories = activeServices
                .map((s) => s.category)
                .where((c) => c.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            final filteredServices = _filterServices(allServices);

            // Métricas
            final avgPrice = activeServices.isNotEmpty
                ? activeServices.fold<num>(0, (sum, s) => sum + s.price) /
                    activeServices.length
                : 0;
            final avgDuration = activeServices.isNotEmpty
                ? (activeServices.fold<int>(0, (sum, s) => sum + s.durationMinutes) /
                        activeServices.length)
                    .round()
                : 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(
                      title: 'Servicios',
                      value: '${activeServices.length}',
                      description: 'Servicios activos',
                      icon: Icons.content_cut_outlined,
                    ),
                    MetricCard(
                      title: 'Categorías',
                      value: '${categories.length}',
                      description: 'Áreas de atención',
                      icon: Icons.category_outlined,
                    ),
                    MetricCard(
                      title: 'Precio medio',
                      value: '\$${avgPrice.toStringAsFixed(0)}',
                      description: 'Promedio por servicio',
                      icon: Icons.attach_money,
                    ),
                    MetricCard(
                      title: 'Duración media',
                      value: '$avgDuration min',
                      description: 'Tiempo estándar',
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buscador y Filtros
                Card(
                  elevation: 1,
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por servicio o categoría...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildChip('all', 'Todos (${activeServices.length})'),
                              for (final cat in categories) ...[
                                const SizedBox(width: 8),
                                _buildChip(cat, cat),
                              ],
                              if (inactiveCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildChip('inactive', '⚪ Inactivos ($inactiveCount)'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Listado de Servicios
                Card(
                  elevation: 1,
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SectionTitle('Catálogo de servicios'),
                            const Spacer(),
                            Text(
                              '${filteredServices.length} servicio(s)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (filteredServices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.spa_outlined, size: 40, color: AppColors.textMuted),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No hay servicios que coincidan con la búsqueda.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedCategory = 'all';
                                      });
                                    },
                                    child: const Text('Limpiar filtros'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filteredServices.map(
                            (service) => ServiceRow(
                              service: service,
                              onEdit: () => openEditServiceDialog(service),
                              onToggleActive: () => toggleActive(service),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTint,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = key);
      },
    );
  }
}

class ServiceRow extends StatelessWidget {
  final ServiceManagementItem service;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const ServiceRow({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: service.active ? AppColors.brandTint : AppColors.surface,
            child: Icon(
              Icons.content_cut_outlined,
              size: 18,
              color: service.active ? AppColors.brandDeep : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: service.active
                              ? AppColors.brandDeep
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      service.formattedPrice,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: service.active
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        service.category,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.schedule_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      '${service.durationMinutes} min',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (!service.visibleToCustomer) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '· Solo interno',
                        style: TextStyle(fontSize: 12, color: AppColors.statePending),
                      ),
                    ],
                    if (!service.active) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '· Inactivo',
                        style: TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: service.active ? 'Desactivar' : 'Reactivar',
            onPressed: onToggleActive,
            icon: Icon(
              service.active
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 20,
              color: service.active ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceFormDialog extends StatefulWidget {
  const _ServiceFormDialog({
    required this.branchId,
    required this.servicesService,
    required this.existing,
  });

  final String branchId;
  final ServicesService servicesService;
  final ServiceManagementItem? existing;

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  late final nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final categoryController = TextEditingController(
    text: widget.existing?.category ?? '',
  );
  late final durationController = TextEditingController(
    text: (widget.existing?.durationMinutes ?? 30).toString(),
  );
  late final priceController = TextEditingController(
    text: widget.existing?.price.toString() ?? '',
  );
  late bool visibleToCustomer = widget.existing?.visibleToCustomer ?? true;
  bool isSaving = false;
  String? errorMessage;

  bool get isEditing => widget.existing != null;

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    durationController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    final category = categoryController.text.trim();
    final duration = int.tryParse(durationController.text.trim());
    final price = num.tryParse(priceController.text.trim());

    if (name.isEmpty) {
      setState(() => errorMessage = 'El nombre es obligatorio.');
      return;
    }
    if (duration == null || duration <= 0) {
      setState(
        () => errorMessage = 'La duración debe ser un número mayor a cero.',
      );
      return;
    }
    if (price == null || price < 0) {
      setState(() => errorMessage = 'El precio debe ser un número válido.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      if (isEditing) {
        await widget.servicesService.updateService(
          branchId: widget.branchId,
          serviceId: widget.existing!.id,
          name: name,
          category: category,
          durationMinutes: duration,
          price: price,
          visibleToCustomer: visibleToCustomer,
        );
      } else {
        await widget.servicesService.createService(
          branchId: widget.branchId,
          name: name,
          category: category,
          durationMinutes: duration,
          price: price,
          visibleToCustomer: visibleToCustomer,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Editar servicio' : 'Agregar servicio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duración (minutos)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio (COP)'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible para reservas públicas'),
              value: visibleToCustomer,
              onChanged: (value) => setState(() => visibleToCustomer = value),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
