import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Servicios',
      subtitle: 'Catálogo de servicios leído desde Supabase.',
      children: [
        const InfoPanel(
          icon: Icons.cloud_done_outlined,
          title: 'Conexión activa con Supabase',
          description:
              'Crea, edita o desactiva los servicios de tu negocio. Los inactivos desaparecen de la agenda pero quedan aquí para reactivarlos.',
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
              return const Card(
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Cargando servicios desde Supabase...'),
                    ],
                  ),
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

            final services = snapshot.data ?? [];

            if (services.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin servicios disponibles',
                description:
                    'No hay servicios para mostrar. Usa "Agregar servicio" para crear el primero.',
              );
            }

            return Card(
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Servicios desde Supabase'),
                    const SizedBox(height: 14),
                    ...services.map(
                      (service) => ServiceRow(
                        service: service,
                        onEdit: () => openEditServiceDialog(service),
                        onToggleActive: () => toggleActive(service),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
              title: const Text('Visible para el cliente'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            service.active ? Icons.check_circle_outline : Icons.pause_circle_outline,
            size: 22,
            color: service.active
                ? const Color(0xFF7C3AED)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: service.active
                        ? const Color(0xFF2D1B69)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${service.category} · ${service.durationMinutes} min · ${service.formattedPrice}'
                  '${service.active ? '' : ' · inactivo'}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
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
              color: service.active ? const Color(0xFFB91C1C) : const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}
