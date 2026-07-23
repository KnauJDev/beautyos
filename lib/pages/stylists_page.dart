import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stylist_service_option.dart';
import '../models/stylist_service_summary.dart';
import '../models/stylist_summary.dart';
import '../services/stylist_services_service.dart';
import '../services/stylists_service.dart';
import '../widgets/app_widgets.dart';

class EstilistasPage extends StatefulWidget {
  const EstilistasPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<EstilistasPage> createState() => _EstilistasPageState();
}

class _EstilistasPageState extends State<EstilistasPage> {
  final StylistsService stylistsService = const StylistsService();
  final StylistServicesService stylistServicesService =
      const StylistServicesService();

  late Future<_StylistsPageData> pageDataFuture;

  @override
  void initState() {
    super.initState();
    pageDataFuture = _loadPageData();
  }

  Future<_StylistsPageData> _loadPageData() async {
    final stylists = await stylistsService.getStylistsSummary();
    final stylistServices = await stylistServicesService
        .getStylistServicesSummary();

    return _StylistsPageData(
      stylists: stylists,
      stylistServices: stylistServices,
    );
  }

  Future<void> _refreshPage() async {
    setState(() {
      pageDataFuture = _loadPageData();
    });
    await pageDataFuture;
  }

  Future<void> _openCreateStylistDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateStylistDialog(
        branchId: widget.branchId,
        stylistsService: stylistsService,
      ),
    );

    if (created == true) {
      await _refreshPage();
    }
  }

  Future<void> _manageStylistServices(StylistSummary stylist) async {
    try {
      final options = await stylistServicesService.getStylistServiceOptions(
        stylist.id,
      );

      if (!mounted) return;

      final selectedServiceIds = await showDialog<List<String>>(
        context: context,
        builder: (context) =>
            _ManageStylistServicesDialog(stylist: stylist, options: options),
      );

      if (selectedServiceIds == null) return;

      await stylistServicesService.setStylistServices(
        stylistId: stylist.id,
        serviceIds: selectedServiceIds,
      );
      await _refreshPage();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Servicios de ${stylist.name} actualizados correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron guardar los servicios: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Estilistas',
      subtitle: 'Equipo de trabajo, especialidades y servicios asignados.',
      children: [
        const InfoPanel(
          icon: Icons.badge_outlined,
          title: 'Estilistas conectados con Supabase',
          description:
              'Consulta el equipo y administra de forma segura los servicios que puede realizar cada estilista.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _openCreateStylistDialog,
            icon: const Icon(Icons.add_outlined),
            label: const Text('Agregar estilista'),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<_StylistsPageData>(
          future: pageDataFuture,
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
                      Text('Cargando estilistas desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los estilistas',
                description: snapshot.error.toString(),
              );
            }

            final data = snapshot.data;
            final stylists = data?.stylists ?? [];
            final stylistServices = data?.stylistServices ?? [];

            if (stylists.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin estilistas disponibles',
                description:
                    'No hay estilistas activos para mostrar en este momento. Usa "Agregar estilista" para crear el primero.',
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
                    const SectionTitle('Estilistas y servicios asignados'),
                    const SizedBox(height: 14),
                    ...stylists.map((stylist) {
                      final services = stylistServices
                          .where(
                            (service) => service.stylistName == stylist.name,
                          )
                          .toList();

                      return StylistCard(
                        stylist: stylist,
                        services: services,
                        onManageServices: () => _manageStylistServices(stylist),
                      );
                    }),
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

class StylistCard extends StatelessWidget {
  final StylistSummary stylist;
  final List<StylistServiceSummary> services;
  final VoidCallback onManageServices;

  const StylistCard({
    super.key,
    required this.stylist,
    required this.services,
    required this.onManageServices,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.face_retouching_natural_outlined,
            size: 30,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stylist.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stylist.specialty,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stylist.phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Registrado: ${stylist.createdDateText}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Servicios asignados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                if (services.isEmpty)
                  const Text(
                    'Sin servicios asignados.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services
                        .map((service) => StylistServiceChip(service: service))
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onManageServices,
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('Gestionar servicios'),
          ),
        ],
      ),
    );
  }
}

class StylistServiceChip extends StatelessWidget {
  final StylistServiceSummary service;

  const StylistServiceChip({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${service.serviceName} \u00b7 ${service.formattedPrice} \u00b7 ${service.durationMinutes} min',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6D28D9),
        ),
      ),
    );
  }
}

class _ManageStylistServicesDialog extends StatefulWidget {
  const _ManageStylistServicesDialog({
    required this.stylist,
    required this.options,
  });

  final StylistSummary stylist;
  final List<StylistServiceOption> options;

  @override
  State<_ManageStylistServicesDialog> createState() =>
      _ManageStylistServicesDialogState();
}

class _ManageStylistServicesDialogState
    extends State<_ManageStylistServicesDialog> {
  late final Set<String> selectedServiceIds;

  @override
  void initState() {
    super.initState();
    selectedServiceIds = widget.options
        .where((option) => option.assigned)
        .map((option) => option.serviceId)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Servicios de ${widget.stylist.name}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Marca los servicios que esta profesional puede realizar. '
              'Los cambios aplican a nuevas asignaciones y no borran el historial.',
            ),
            const SizedBox(height: 16),
            if (widget.options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('No hay servicios activos para asignar.'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.options.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = widget.options[index];
                    final selected = selectedServiceIds.contains(
                      option.serviceId,
                    );

                    return CheckboxListTile(
                      value: selected,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(option.serviceName),
                      subtitle: Text(
                        '${option.category} · ${option.formattedPrice} · '
                        '${option.durationMinutes} min',
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            selectedServiceIds.add(option.serviceId);
                          } else {
                            selectedServiceIds.remove(option.serviceId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            if (selectedServiceIds.isEmpty && widget.options.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Sin servicios seleccionados, esta profesional no aparecera '
                'como opcion al asignar nuevos servicios.',
                style: TextStyle(color: Color(0xFFB45309)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: widget.options.isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop(selectedServiceIds.toList(growable: false)),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar servicios'),
        ),
      ],
    );
  }
}

class _CreateStylistDialog extends StatefulWidget {
  const _CreateStylistDialog({
    required this.branchId,
    required this.stylistsService,
  });

  final String branchId;
  final StylistsService stylistsService;

  @override
  State<_CreateStylistDialog> createState() => _CreateStylistDialogState();
}

class _CreateStylistDialogState extends State<_CreateStylistDialog> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final specialtyController = TextEditingController();
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    specialtyController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      setState(() => errorMessage = 'El nombre es obligatorio.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.stylistsService.createStylist(
        branchId: widget.branchId,
        name: name,
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        specialty: specialtyController.text.trim().isEmpty
            ? null
            : specialtyController.text.trim(),
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
      title: const Text('Agregar estilista'),
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
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: specialtyController,
              decoration: const InputDecoration(labelText: 'Especialidad'),
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

class _StylistsPageData {
  final List<StylistSummary> stylists;
  final List<StylistServiceSummary> stylistServices;

  const _StylistsPageData({
    required this.stylists,
    required this.stylistServices,
  });
}
