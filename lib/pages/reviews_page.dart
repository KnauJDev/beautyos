import 'package:flutter/material.dart';

import '../models/review_summary.dart';
import '../services/reviews_service.dart';
import '../widgets/app_widgets.dart';

class ResenasPage extends StatefulWidget {
  const ResenasPage({super.key});

  @override
  State<ResenasPage> createState() => _ResenasPageState();
}

class _ResenasPageState extends State<ResenasPage> {
  final ReviewsService _reviewsService = const ReviewsService();

  late Future<List<ReviewSummary>> _reviewsFuture;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _reviewsService.getReviewsSummary();
  }

  List<ReviewSummary> _filterReviews(List<ReviewSummary> reviews) {
    switch (_selectedFilter) {
      case 'public':
        return reviews.where((review) => review.visibleToPublic).toList();
      case 'approved':
        return reviews
            .where((review) => review.moderationStatus == 'approved')
            .toList();
      case 'pending':
        return reviews
            .where((review) => review.moderationStatus == 'pending')
            .toList();
      default:
        return reviews;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReviewSummary>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar reseñas',
            description: snapshot.error.toString(),
          );
        }

        final allReviews = snapshot.data ?? [];
        final filteredReviews = _filterReviews(allReviews);

        return _ReviewsContent(
          allReviews: allReviews,
          reviews: filteredReviews,
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

class _ReviewsContent extends StatelessWidget {
  final List<ReviewSummary> allReviews;
  final List<ReviewSummary> reviews;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _ReviewsContent({
    required this.allReviews,
    required this.reviews,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalReviews = allReviews.length;
    final publicReviews =
        allReviews.where((review) => review.visibleToPublic).length;
    final approvedReviews = allReviews
        .where((review) => review.moderationStatus == 'approved')
        .length;
    final pendingReviews = allReviews
        .where((review) => review.moderationStatus == 'pending')
        .length;

    final averageRating = totalReviews == 0
        ? 0
        : allReviews.map((review) => review.rating).reduce((a, b) => a + b) /
            totalReviews;

    return AppPage(
      title: 'Reseñas',
      subtitle: 'Calificaciones, comentarios y moderación de opiniones de clientes.',
      children: [
        const InfoPanel(
          icon: Icons.rate_review_outlined,
          title: 'Reseñas conectadas con Supabase',
          description:
              'Aqui veremos las opiniones de clientes, su calificacion, estado de moderacion y visibilidad publica.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            MetricCard(
              title: 'Reseñas',
              value: '$totalReviews',
              description: 'Total registradas',
              icon: Icons.reviews_outlined,
            ),
            MetricCard(
              title: 'Promedio',
              value: averageRating.toStringAsFixed(1),
              description: 'Calificación general',
              icon: Icons.star_outline,
            ),
            MetricCard(
              title: 'Públicas',
              value: '$publicReviews',
              description: 'Visibles al público',
              icon: Icons.visibility_outlined,
            ),
            MetricCard(
              title: 'Aprobadas',
              value: '$approvedReviews',
              description: 'Ya moderadas',
              icon: Icons.verified_outlined,
            ),
            MetricCard(
              title: 'Pendientes',
              value: '$pendingReviews',
              description: 'Por moderar',
              icon: Icons.pending_actions_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ReviewFilters(
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        const SizedBox(height: 16),
        SectionTitle('Listado de reseñas (${reviews.length})'),
        const SizedBox(height: 12),
        _ReviewsList(reviews: reviews),
      ],
    );
  }
}

class _ReviewFilters extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _ReviewFilters({
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
          label: 'Públicas',
          value: 'public',
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        _FilterChipButton(
          label: 'Aprobadas',
          value: 'approved',
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        _FilterChipButton(
          label: 'Pendientes',
          value: 'pending',
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

class _ReviewsList extends StatelessWidget {
  final List<ReviewSummary> reviews;

  const _ReviewsList({
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin reseñas para este filtro',
        description: 'No hay reseñas que coincidan con el filtro seleccionado.',
      );
    }

    return Column(
      children: [
        for (final review in reviews) ...[
          _ReviewCard(review: review),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewSummary review;

  const _ReviewCard({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  review.starsText,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _StatusChip(text: review.moderationText),
                _StatusChip(text: review.visibilityText),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review.commentText,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cliente: ${review.clientName}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Estilista: ${review.stylistName}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Servicio: ${review.serviceName}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha: ${review.createdDateText}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({
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

