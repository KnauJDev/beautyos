import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/review_reply_draft.dart';
import '../models/review_summary.dart';
import '../services/business_settings_service.dart';
import '../services/reviews_service.dart';
import '../widgets/app_widgets.dart';

class ResenasPage extends StatefulWidget {
  const ResenasPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<ResenasPage> createState() => _ResenasPageState();
}

class _ResenasPageState extends State<ResenasPage> {
  late final ReviewsService _reviewsService;

  late Future<List<ReviewSummary>> _reviewsFuture;
  String _selectedFilter = 'all';

  /// Solo alimenta el borrador sugerido de respuesta (D-170) -- si falla al
  /// cargar, un nombre genérico no bloquea ver ni responder reseñas.
  String _businessName = 'nuestro salón';

  @override
  void initState() {
    super.initState();
    _reviewsService = ReviewsService(branchId: widget.branchId);
    _reviewsFuture = _reviewsService.getReviewsSummary();
    _cargarNombreNegocio();
  }

  Future<void> _cargarNombreNegocio() async {
    try {
      final settings = await const BusinessSettingsService()
          .getBusinessSettings();
      if (mounted) setState(() => _businessName = settings.name);
    } catch (_) {
      // Silencioso a propósito: ver y responder reseñas no depende de esto.
    }
  }

  void _refreshReviews() {
    setState(() {
      _reviewsFuture = _reviewsService.getReviewsSummary();
    });
  }

  Future<void> _moderateReview(ReviewSummary review, bool approve) async {
    try {
      await _reviewsService.moderateReview(
        reviewId: review.id,
        approve: approve,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Reseña aprobada.' : 'Reseña rechazada.'),
        ),
      );
      _refreshReviews();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo moderar la reseña: $message')),
      );
    }
  }

  Future<void> _setReviewVisibility(ReviewSummary review, bool visible) async {
    try {
      await _reviewsService.setReviewVisibility(
        reviewId: review.id,
        visible: visible,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visible ? 'Reseña visible al público.' : 'Reseña ocultada.',
          ),
        ),
      );
      _refreshReviews();
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

  Future<void> _openReplyDialog(ReviewSummary review) async {
    final draft = review.tieneRespuesta
        ? review.businessReply!
        : ReviewReplyDraftBuilder.generar(
            rating: review.rating,
            clientName: review.clientName,
            serviceName: review.serviceName,
            businessName: _businessName,
          );

    final controller = TextEditingController(text: draft);

    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          review.tieneRespuesta ? 'Editar respuesta' : 'Responder reseña',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sugerencia lista para editar -- revisa el tono antes de '
                'guardar. Se publica junto a la reseña en tu página.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          if (review.tieneRespuesta)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text(
                'Quitar respuesta',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (resultado == null) return;
    await _saveReply(review, resultado);
  }

  Future<void> _saveReply(ReviewSummary review, String reply) async {
    try {
      await _reviewsService.setReviewReply(reviewId: review.id, reply: reply);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reply.trim().isEmpty ? 'Respuesta eliminada.' : 'Respuesta guardada.',
          ),
        ),
      );
      _refreshReviews();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la respuesta: $message')),
      );
    }
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
          return const Center(child: CircularProgressIndicator());
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
          onModerate: _moderateReview,
          onSetVisibility: _setReviewVisibility,
          onReply: _openReplyDialog,
          onRefresh: _refreshReviews,
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
  final Future<void> Function(ReviewSummary review, bool approve) onModerate;
  final Future<void> Function(ReviewSummary review, bool visible)
  onSetVisibility;
  final Future<void> Function(ReviewSummary review) onReply;
  final VoidCallback onRefresh;

  const _ReviewsContent({
    required this.allReviews,
    required this.reviews,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onModerate,
    required this.onSetVisibility,
    required this.onReply,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalReviews = allReviews.length;
    final publicReviews = allReviews
        .where((review) => review.visibleToPublic)
        .length;
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
      subtitle:
          'Calificaciones, comentarios y moderación de opiniones de clientes.',
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Actualizar reseñas'),
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
        _ReviewsList(
          reviews: reviews,
          onModerate: onModerate,
          onSetVisibility: onSetVisibility,
          onReply: onReply,
        ),
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
  final Future<void> Function(ReviewSummary review, bool approve) onModerate;
  final Future<void> Function(ReviewSummary review, bool visible)
  onSetVisibility;
  final Future<void> Function(ReviewSummary review) onReply;

  const _ReviewsList({
    required this.reviews,
    required this.onModerate,
    required this.onSetVisibility,
    required this.onReply,
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
          _ReviewCard(
            review: review,
            onModerate: onModerate,
            onSetVisibility: onSetVisibility,
            onReply: onReply,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewSummary review;
  final Future<void> Function(ReviewSummary review, bool approve) onModerate;
  final Future<void> Function(ReviewSummary review, bool visible)
  onSetVisibility;
  final Future<void> Function(ReviewSummary review) onReply;

  const _ReviewCard({
    required this.review,
    required this.onModerate,
    required this.onSetVisibility,
    required this.onReply,
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
                    color: AppColors.warning,
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
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cliente: ${review.clientName}',
              style: const TextStyle(fontSize: 14, color: AppColors.textStrong),
            ),
            const SizedBox(height: 4),
            Text(
              'Estilista: ${review.stylistName}',
              style: const TextStyle(fontSize: 14, color: AppColors.textStrong),
            ),
            const SizedBox(height: 4),
            Text(
              'Servicio: ${review.serviceName}',
              style: const TextStyle(fontSize: 14, color: AppColors.textStrong),
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha: ${review.createdDateText}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (review.tieneRespuesta) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.brandTintSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.brandTint),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu respuesta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.businessReply!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textStrong),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => onReply(review),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar respuesta'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => onReply(review),
                icon: const Icon(Icons.reply_outlined, size: 16),
                label: const Text('Responder'),
              ),
            if (review.moderationStatus == 'pending') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => onModerate(review, true),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aprobar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onModerate(review, false),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Rechazar'),
                  ),
                ],
              ),
            ],
            if (review.moderationStatus == 'approved') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: review.visibleToPublic,
                    onChanged: (value) => onSetVisibility(review, value),
                  ),
                  const SizedBox(width: 8),
                  const Text('Visible al público'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(text), visualDensity: VisualDensity.compact);
  }
}
