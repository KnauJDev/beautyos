import 'package:flutter/material.dart';

import '../models/work_photo_summary.dart';
import '../services/work_photos_service.dart';
import '../widgets/app_widgets.dart';

class FotosTrabajosPage extends StatefulWidget {
  const FotosTrabajosPage({super.key});

  @override
  State<FotosTrabajosPage> createState() => _FotosTrabajosPageState();
}

class _FotosTrabajosPageState extends State<FotosTrabajosPage> {
  final WorkPhotosService _workPhotosService = const WorkPhotosService();

  late Future<List<WorkPhotoSummary>> _workPhotosFuture;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkPhotoSummary>>(
      future: _workPhotosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
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

  const _WorkPhotosContent({
    required this.allPhotos,
    required this.photos,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalPhotos = allPhotos.length;
    final visiblePhotos =
        allPhotos.where((photo) => photo.visibleToCustomer).length;
    final portfolioPhotos =
        allPhotos.where((photo) => photo.approvedForPortfolio).length;
    final pendingAiPhotos =
        allPhotos.where((photo) => photo.aiStatus == 'pending').length;

    return AppPage(
      title: 'Fotos de trabajos',
      subtitle: 'Portafolio visual, evidencia de servicios y futuras mejoras con IA.',
      children: [
        const InfoPanel(
          icon: Icons.photo_library_outlined,
          title: 'Fotos de trabajos conectadas con Supabase',
          description:
              'Aqui veremos las fotos antes, despues, finales y aprobadas para portafolio.',
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
        _WorkPhotosGrid(photos: photos),
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

  const _WorkPhotosGrid({
    required this.photos,
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
            child: _WorkPhotoCard(photo: photo),
          ),
      ],
    );
  }
}

class _WorkPhotoCard extends StatelessWidget {
  final WorkPhotoSummary photo;

  const _WorkPhotoCard({
    required this.photo,
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
            child: Image.network(
              photo.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: Color(0xFFF3F4F6),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 42,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                );
              },
            ),
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
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${photo.clientName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estilista: ${photo.stylistName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  photo.aiStatusText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  photo.visibilityText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  photo.portfolioText,
                  style: const TextStyle(
                    fontSize: 13,
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

class _PhotoTypeBadge extends StatelessWidget {
  final String text;

  const _PhotoTypeBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }
}
