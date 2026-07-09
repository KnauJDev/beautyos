import 'package:flutter/material.dart';

import '../models/my_stylist_work_photo.dart';
import '../services/my_stylist_work_photos_service.dart';
import '../widgets/app_widgets.dart';

class MyStylistWorkPhotosPage extends StatefulWidget {
  const MyStylistWorkPhotosPage({super.key});

  @override
  State<MyStylistWorkPhotosPage> createState() =>
      _MyStylistWorkPhotosPageState();
}

class _MyStylistWorkPhotosPageState extends State<MyStylistWorkPhotosPage> {
  final MyStylistWorkPhotosService photosService =
      const MyStylistWorkPhotosService();

  late final Future<List<MyStylistWorkPhoto>> photosFuture;

  @override
  void initState() {
    super.initState();
    photosFuture = photosService.getMyStylistWorkPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mis fotos',
      subtitle: 'Fotos de trabajos asociadas a tu usuario estilista.',
      children: [
        FutureBuilder<List<MyStylistWorkPhoto>>(
          future: photosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No pudimos cargar tus fotos',
                description: snapshot.error.toString(),
              );
            }

            final photos = snapshot.data ?? <MyStylistWorkPhoto>[];

            if (photos.isEmpty) {
              return const InfoPanel(
                icon: Icons.photo_library_outlined,
                title: 'Sin fotos asignadas',
                description: 'Cuando subas fotos de tus trabajos, apareceran aqui.',
              );
            }

            final visibleCount =
                photos.where((photo) => photo.visibleToCustomer).length;
            final portfolioCount =
                photos.where((photo) => photo.approvedForPortfolio).length;
            final pendingAiCount =
                photos.where((photo) => photo.aiStatus == 'pending').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(
                      title: 'Fotos',
                      value: photos.length.toString(),
                      description: 'Trabajos registrados',
                      icon: Icons.photo_library_outlined,
                    ),
                    MetricCard(
                      title: 'Visibles',
                      value: visibleCount.toString(),
                      description: 'Para cliente',
                      icon: Icons.visibility_outlined,
                    ),
                    MetricCard(
                      title: 'Portafolio',
                      value: portfolioCount.toString(),
                      description: 'Aprobadas',
                      icon: Icons.workspace_premium_outlined,
                    ),
                    MetricCard(
                      title: 'IA pendiente',
                      value: pendingAiCount.toString(),
                      description: 'Por procesar',
                      icon: Icons.auto_awesome_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionTitle('Galeria de mis trabajos'),
                const SizedBox(height: 12),
                _PhotosGrid(photos: photos),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({required this.photos});

  final List<MyStylistWorkPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: photos
          .map(
            (photo) => _PhotoCard(photo: photo),
          )
          .toList(),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo});

  final MyStylistWorkPhoto photo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 0,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                photo.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 42,
                      color: Color(0xFF9CA3AF),
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
                  _PhotoBadge(text: photo.photoTypeText),
                  const SizedBox(height: 10),
                  Text(
                    photo.caption,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PhotoLine(
                    icon: Icons.person_outline,
                    text: photo.clientName,
                  ),
                  _PhotoLine(
                    icon: Icons.content_cut_outlined,
                    text: photo.serviceName,
                  ),
                  _PhotoLine(
                    icon: Icons.auto_awesome_outlined,
                    text: photo.aiStatusText,
                  ),
                  _PhotoLine(
                    icon: Icons.visibility_outlined,
                    text: photo.visibilityText,
                  ),
                  _PhotoLine(
                    icon: Icons.workspace_premium_outlined,
                    text: photo.portfolioText,
                  ),
                  _PhotoLine(
                    icon: Icons.calendar_today_outlined,
                    text: photo.createdDateText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      backgroundColor: const Color(0xFFF5F3FF),
      labelStyle: const TextStyle(
        color: Color(0xFF5B21B6),
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
    );
  }
}

class _PhotoLine extends StatelessWidget {
  const _PhotoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
