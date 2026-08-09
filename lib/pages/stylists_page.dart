import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/stylist_management_item.dart';
import '../models/stylist_service_option.dart';
import '../models/stylist_service_summary.dart';
import '../services/stylist_photo_upload_service.dart';
import '../services/stylist_services_service.dart';
import '../services/stylists_service.dart';
import '../widgets/app_widgets.dart';

class EstilistasPage extends StatefulWidget {
  const EstilistasPage({
    super.key,
    required this.branchId,
    required this.tenantId,
  });

  final String branchId;
  final String tenantId;

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
    final stylists = await stylistsService.getStylistsForManagement(
      widget.branchId,
    );
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StylistFormDialog(
        branchId: widget.branchId,
        tenantId: widget.tenantId,
        stylistsService: stylistsService,
        existing: null,
      ),
    );

    if (saved == true) {
      await _refreshPage();
    }
  }

  Future<void> _openEditStylistDialog(StylistManagementItem stylist) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StylistFormDialog(
        branchId: widget.branchId,
        tenantId: widget.tenantId,
        stylistsService: stylistsService,
        existing: stylist,
      ),
    );

    if (saved == true) {
      await _refreshPage();
    }
  }

  Future<void> _toggleActive(StylistManagementItem stylist) async {
    try {
      await stylistsService.setStylistActive(
        branchId: widget.branchId,
        stylistId: stylist.id,
        active: !stylist.active,
      );
      await _refreshPage();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    }
  }

  Future<void> _manageStylistServices(StylistManagementItem stylist) async {
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
              'Crea, edita o desactiva estilistas y administra los servicios que puede realizar cada uno.',
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
                    'No hay estilistas para mostrar. Usa "Agregar estilista" para crear el primero.',
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
                        onEdit: () => _openEditStylistDialog(stylist),
                        onToggleActive: () => _toggleActive(stylist),
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
  final StylistManagementItem stylist;
  final List<StylistServiceSummary> services;
  final VoidCallback onManageServices;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const StylistCard({
    super.key,
    required this.stylist,
    required this.services,
    required this.onManageServices,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StylistAvatar(photoUrl: stylist.photoUrl, active: stylist.active),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stylist.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: stylist.active
                            ? AppColors.brandDeep
                            : AppColors.textMuted,
                      ),
                    ),
                    if (!stylist.active) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '· inactivo',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  stylist.specialty,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stylist.phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (stylist.bio != null && stylist.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    stylist.bio!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Servicios asignados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDeep,
                  ),
                ),
                const SizedBox(height: 8),
                if (services.isEmpty)
                  const Text(
                    'Sin servicios asignados.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onManageServices,
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Gestionar servicios'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: stylist.active ? 'Desactivar' : 'Reactivar',
                    onPressed: onToggleActive,
                    icon: Icon(
                      stylist.active
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 20,
                      color: stylist.active
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StylistAvatar extends StatelessWidget {
  const _StylistAvatar({required this.photoUrl, required this.active});

  final String? photoUrl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final color = active ? AppColors.brand : AppColors.textMuted;

    if (url == null || url.trim().isEmpty) {
      return Icon(
        Icons.face_retouching_natural_outlined,
        size: 30,
        color: color,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.face_retouching_natural_outlined, size: 30, color: color),
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
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${service.serviceName} · ${service.formattedPrice} · ${service.durationMinutes} min',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.brandDark,
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

  final StylistManagementItem stylist;
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
                style: TextStyle(color: AppColors.warning),
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

class _StylistFormDialog extends StatefulWidget {
  const _StylistFormDialog({
    required this.branchId,
    required this.tenantId,
    required this.stylistsService,
    required this.existing,
  });

  final String branchId;
  final String tenantId;
  final StylistsService stylistsService;
  final StylistManagementItem? existing;

  @override
  State<_StylistFormDialog> createState() => _StylistFormDialogState();
}

class _StylistFormDialogState extends State<_StylistFormDialog> {
  final _photoUploadService = const StylistPhotoUploadService();

  late final nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final phoneController = TextEditingController(
    text: widget.existing != null && widget.existing!.phone != 'Sin teléfono'
        ? widget.existing!.phone
        : '',
  );
  late final specialtyController = TextEditingController(
    text:
        widget.existing != null && widget.existing!.specialty != 'Sin especialidad'
        ? widget.existing!.specialty
        : '',
  );
  late final bioController = TextEditingController(
    text: widget.existing?.bio ?? '',
  );
  late String? photoUrl = widget.existing?.photoUrl;
  bool isSaving = false;
  bool isUploadingPhoto = false;
  String? errorMessage;

  bool get isEditing => widget.existing != null;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    specialtyController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final XFile? image = await _photoUploadService.pickImage();
    if (image == null) return;

    setState(() {
      isUploadingPhoto = true;
      errorMessage = null;
    });

    try {
      final uploadedUrl = await _photoUploadService.uploadStylistPhoto(
        tenantId: widget.tenantId,
        stylistId: widget.existing!.id,
        image: image,
        previousUrl: photoUrl,
      );

      if (!mounted) return;
      setState(() => photoUrl = uploadedUrl);
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : 'No se pudo subir la foto: $error';
      setState(() => errorMessage = message);
    } finally {
      if (mounted) {
        setState(() => isUploadingPhoto = false);
      }
    }
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
      final phone = phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim();
      final specialty = specialtyController.text.trim().isEmpty
          ? null
          : specialtyController.text.trim();
      final bio = bioController.text.trim().isEmpty
          ? null
          : bioController.text.trim();

      if (isEditing) {
        await widget.stylistsService.updateStylist(
          branchId: widget.branchId,
          stylistId: widget.existing!.id,
          name: name,
          phone: phone,
          specialty: specialty,
          photoUrl: photoUrl,
          bio: bio,
        );
      } else {
        await widget.stylistsService.createStylist(
          branchId: widget.branchId,
          name: name,
          phone: phone,
          specialty: specialty,
          bio: bio,
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
      title: Text(isEditing ? 'Editar estilista' : 'Agregar estilista'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing) ...[
              _StylistAvatar(photoUrl: photoUrl, active: true),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isUploadingPhoto ? null : _pickAndUploadPhoto,
                icon: isUploadingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  isUploadingPhoto
                      ? 'Subiendo...'
                      : (photoUrl == null ? 'Subir foto' : 'Cambiar foto'),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
            const SizedBox(height: 12),
            TextField(
              controller: bioController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Biografía (visible en la reserva pública)',
              ),
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
  final List<StylistManagementItem> stylists;
  final List<StylistServiceSummary> stylistServices;

  const _StylistsPageData({
    required this.stylists,
    required this.stylistServices,
  });
}
