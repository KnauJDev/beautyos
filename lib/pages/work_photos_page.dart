import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/work_photo_summary.dart';
import '../services/work_photos_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/foto_de_trabajo.dart';

class FotosTrabajosPage extends StatefulWidget {
  const FotosTrabajosPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<FotosTrabajosPage> createState() => _FotosTrabajosPageState();
}

class _FotosTrabajosPageState extends State<FotosTrabajosPage> {
  late final WorkPhotosService _workPhotosService;

  late Future<List<WorkPhotoSummary>> _workPhotosFuture;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _workPhotosService = WorkPhotosService(branchId: widget.branchId);
    _workPhotosFuture = _workPhotosService.getWorkPhotosSummary();
  }

  List<WorkPhotoSummary> _filterPhotos(List<WorkPhotoSummary> photos) {
    switch (_selectedFilter) {
      case 'visible':
        return photos.where((photo) => photo.visibleToCustomer).toList();
      case 'portfolio':
        return photos.where((photo) => photo.approvedForPortfolio).toList();
      case 'pending_ai':
        return photos.where((photo) => photo.aiStatus == 'pending').toList();
      default:
        return photos;
    }
  }

  void _refreshPhotos() {
    setState(() {
      _workPhotosFuture = _workPhotosService.getWorkPhotosSummary();
    });
  }

  Future<void> _setCustomerVisibility(
    WorkPhotoSummary photo,
    bool visible,
  ) async {
    try {
      await _workPhotosService.setCustomerVisibility(
        photoId: photo.id,
        visible: visible,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visible ? 'Foto visible al cliente.' : 'Foto ocultada al cliente.',
          ),
        ),
      );
      _refreshPhotos();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar la visibilidad: $message')),
      );
    }
  }

  Future<void> _setPortfolioApproval(
    WorkPhotoSummary photo,
    bool approved,
  ) async {
    try {
      if (photo.storagePath == null) {
        throw StateError(
          'Esta foto no tiene ruta de archivo y no se puede publicar. '
          'Vuelve a subirla.',
        );
      }

      await _workPhotosService.setPortfolioApproval(
        photoId: photo.id,
        approved: approved,
        storagePath: photo.storagePath!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Foto aprobada para portafolio.'
                : 'Foto retirada del portafolio.',
          ),
        ),
      );
      _refreshPhotos();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aprobar la foto: $message')),
      );
    }
  }

  /// Borrar una foto **no se puede deshacer**, y hay que decirlo con esas
  /// palabras: el respaldo del proyecto guarda la lista de archivos, no los
  /// archivos, asi que una imagen borrada no esta en ningun respaldo (H-09).
  Future<void> _deletePhoto(WorkPhotoSummary photo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta foto?'),
        content: const Text(
          'La imagen se borra definitivamente y no se puede recuperar: las '
          'fotos no se guardan en los respaldos.\n\n'
          'Si la foto está publicada, dejará de verse en internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final ruta = photo.storagePath;

    if (ruta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta foto ya no tiene archivo asociado.'),
        ),
      );
      return;
    }

    try {
      await _workPhotosService.deleteWorkPhoto(
        photoId: photo.id,
        bucket: photo.storageBucket,
        storagePath: ruta,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto eliminada.')),
      );
      _refreshPhotos();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la foto: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkPhotoSummary>>(
      future: _workPhotosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar fotos',
            description: snapshot.error.toString(),
          );
        }

        final allPhotos = snapshot.data ?? [];
        final filteredPhotos = _filterPhotos(allPhotos);

        return _WorkPhotosContent(
          allPhotos: allPhotos,
          photos: filteredPhotos,
          selectedFilter: _selectedFilter,
          onFilterChanged: (filter) {
            setState(() {
              _selectedFilter = filter;
            });
          },
          onRefresh: _refreshPhotos,
          onSetCustomerVisibility: _setCustomerVisibility,
          onSetPortfolioApproval: _setPortfolioApproval,
          onDelete: _deletePhoto,
        );
      },
    );
  }
}

class _WorkPhotosContent extends StatelessWidget {
  final List<WorkPhotoSummary> allPhotos;
  final List<WorkPhotoSummary> photos;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onRefresh;
  final Future<void> Function(WorkPhotoSummary photo, bool visible)
  onSetCustomerVisibility;
  final Future<void> Function(WorkPhotoSummary photo, bool approved)
  onSetPortfolioApproval;
  final Future<void> Function(WorkPhotoSummary photo) onDelete;

  const _WorkPhotosContent({
    required this.allPhotos,
    required this.photos,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onSetCustomerVisibility,
    required this.onSetPortfolioApproval,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalPhotos = allPhotos.length;
    final visiblePhotos = allPhotos
        .where((photo) => photo.visibleToCustomer)
        .length;
    final portfolioPhotos = allPhotos
        .where((photo) => photo.approvedForPortfolio)
        .length;
    final pendingAiPhotos = allPhotos
        .where((photo) => photo.aiStatus == 'pending')
        .length;

    return AppPage(
      title: 'Fotos de trabajos',
      subtitle:
          'Portafolio visual, evidencia de servicios y futuras mejoras con IA.',
      children: [
        const InfoPanel(
          icon: Icons.photo_library_outlined,
          title: 'Fotos de trabajos conectadas con Supabase',
          description:
              'Aqui veremos las fotos antes, despues, finales y aprobadas para portafolio.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Actualizar fotos'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            MetricCard(
              title: 'Fotos',
              value: '$totalPhotos',
              description: 'Registros cargados',
              icon: Icons.image_outlined,
            ),
            MetricCard(
              title: 'Visibles',
              value: '$visiblePhotos',
              description: 'Fotos visibles al cliente',
              icon: Icons.visibility_outlined,
            ),
            MetricCard(
              title: 'Portafolio',
              value: '$portfolioPhotos',
              description: 'Fotos aprobadas',
              icon: Icons.collections_outlined,
            ),
            MetricCard(
              title: 'IA pendiente',
              value: '$pendingAiPhotos',
              description: 'Fotos por procesar',
              icon: Icons.auto_awesome_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorkPhotoFilters(
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        const SizedBox(height: 16),
        SectionTitle('Galeria de trabajos (${photos.length})'),
        const SizedBox(height: 12),
        _WorkPhotosGrid(
          photos: photos,
          onSetCustomerVisibility: onSetCustomerVisibility,
          onSetPortfolioApproval: onSetPortfolioApproval,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _WorkPhotoFilters extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _WorkPhotoFilters({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChipButton(
          label: 'Todas',
          value: 'all',
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        _FilterChipButton(
          label: 'Visibles',
          value: 'visible',
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        _FilterChipButton(
          label: 'Portafolio',
          value: 'portfolio',
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        _FilterChipButton(
          label: 'IA pendiente',
          value: 'pending_ai',
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final String value;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onFilterChanged(value),
    );
  }
}

class _WorkPhotosGrid extends StatelessWidget {
  final List<WorkPhotoSummary> photos;
  final Future<void> Function(WorkPhotoSummary photo, bool visible)
  onSetCustomerVisibility;
  final Future<void> Function(WorkPhotoSummary photo, bool approved)
  onSetPortfolioApproval;
  final Future<void> Function(WorkPhotoSummary photo) onDelete;

  const _WorkPhotosGrid({
    required this.photos,
    required this.onSetCustomerVisibility,
    required this.onSetPortfolioApproval,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin fotos para este filtro',
        description: 'No hay fotos que coincidan con el filtro seleccionado.',
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final photo in photos)
          SizedBox(
            width: 280,
            child: _WorkPhotoCard(
              photo: photo,
              onSetCustomerVisibility: onSetCustomerVisibility,
              onSetPortfolioApproval: onSetPortfolioApproval,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

class _WorkPhotoCard extends StatelessWidget {
  final WorkPhotoSummary photo;
  final Future<void> Function(WorkPhotoSummary photo, bool visible)
  onSetCustomerVisibility;
  final Future<void> Function(WorkPhotoSummary photo, bool approved)
  onSetPortfolioApproval;
  final Future<void> Function(WorkPhotoSummary photo) onDelete;

  const _WorkPhotoCard({
    required this.photo,
    required this.onSetCustomerVisibility,
    required this.onSetPortfolioApproval,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: FotoDeTrabajo(url: photo.displayUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoTypeBadge(text: photo.photoTypeText),
                const SizedBox(height: 10),
                Text(
                  photo.captionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${photo.clientName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estilista: ${photo.stylistName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  photo.aiStatusText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: photo.visibleToCustomer,
                      onChanged: (value) =>
                          onSetCustomerVisibility(photo, value),
                    ),
                    const Expanded(
                      child: Text(
                        'Visible al cliente',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: photo.approvedForPortfolio,
                      onChanged: (value) =>
                          onSetPortfolioApproval(photo, value),
                    ),
                    const Expanded(
                      child: Text(
                        'Aprobada para portafolio',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    // Borrar va aparte y en rojo: es la unica accion de esta
                    // tarjeta que no se puede deshacer (H-09).
                    IconButton(
                      onPressed: () => onDelete(photo),
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.danger,
                      tooltip: 'Eliminar foto',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTypeBadge extends StatelessWidget {
  final String text;

  const _PhotoTypeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(text), visualDensity: VisualDensity.compact);
  }
}
