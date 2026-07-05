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

  @override
  void initState() {
    super.initState();
    _workPhotosFuture = _workPhotosService.getWorkPhotosSummary();
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

        final photos = snapshot.data ?? [];

        return _WorkPhotosContent(photos: photos);
      },
    );
  }
}

class _WorkPhotosContent extends StatelessWidget {
  final List<WorkPhotoSummary> photos;

  const _WorkPhotosContent({
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    final totalPhotos = photos.length;
    final visiblePhotos =
        photos.where((photo) => photo.visibleToCustomer).length;
    final portfolioPhotos =
        photos.where((photo) => photo.approvedForPortfolio).length;
    final pendingAiPhotos =
        photos.where((photo) => photo.aiStatus == 'pending').length;

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
        const SectionTitle('Galeria de trabajos'),
        const SizedBox(height: 12),
        _WorkPhotosGrid(photos: photos),
      ],
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
        title: 'Sin fotos registradas',
        description: 'Todavia no hay fotos de trabajos cargadas en el sistema.',
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
