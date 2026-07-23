import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/beauty_service.dart';
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
  late Future<List<BeautyService>> servicesFuture;

  @override
  void initState() {
    super.initState();
    servicesFuture = servicesService.getActiveVisibleServices();
  }

  void reload() {
    setState(() {
      servicesFuture = servicesService.getActiveVisibleServices();
    });
  }

  Future<void> openCreateServiceDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateServiceDialog(
        branchId: widget.branchId,
        servicesService: servicesService,
      ),
    );

    if (created == true) {
      reload();
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
              'Este módulo ya consulta la tabla services y muestra los servicios activos y visibles para el cliente.',
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
        FutureBuilder<List<BeautyService>>(
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
                    'No hay servicios activos y visibles para mostrar en este momento. Usa "Agregar servicio" para crear el primero.',
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
                    ...services.map((service) => ServiceRow(service: service)),
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

class _CreateServiceDialog extends StatefulWidget {
  const _CreateServiceDialog({
    required this.branchId,
    required this.servicesService,
  });

  final String branchId;
  final ServicesService servicesService;

  @override
  State<_CreateServiceDialog> createState() => _CreateServiceDialogState();
}

class _CreateServiceDialogState extends State<_CreateServiceDialog> {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final durationController = TextEditingController(text: '30');
  final priceController = TextEditingController();
  bool visibleToCustomer = true;
  bool isSaving = false;
  String? errorMessage;

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
      await widget.servicesService.createService(
        branchId: widget.branchId,
        name: name,
        category: category,
        durationMinutes: duration,
        price: price,
        visibleToCustomer: visibleToCustomer,
      );

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
      title: const Text('Agregar servicio'),
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
  final BeautyService service;

  const ServiceRow({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 22,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${service.category} · ${service.durationMinutes} min · ${service.formattedPrice}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
