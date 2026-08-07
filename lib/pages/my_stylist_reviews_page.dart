import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../models/my_stylist_review.dart';
import '../services/my_stylist_reviews_service.dart';
import '../widgets/app_widgets.dart';

class MyStylistReviewsPage extends StatefulWidget {
  const MyStylistReviewsPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<MyStylistReviewsPage> createState() => _MyStylistReviewsPageState();
}

class _MyStylistReviewsPageState extends State<MyStylistReviewsPage> {
  late final MyStylistReviewsService reviewsService;
  late Future<List<MyStylistReview>> reviewsFuture;

  @override
  void initState() {
    super.initState();
    reviewsService = MyStylistReviewsService(branchId: widget.branchId);
    reviewsFuture = reviewsService.getMyReviews();
  }

  void _refresh() {
    setState(() {
      reviewsFuture = reviewsService.getMyReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mis reseñas',
      subtitle:
          'Calificaciones y comentarios que tus clientes dejaron sobre ti.',
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Actualizar reseñas'),
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<MyStylistReview>>(
          future: reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No pudimos cargar tus reseñas',
                description: snapshot.error.toString(),
              );
            }

            final reviews = snapshot.data ?? <MyStylistReview>[];

            if (reviews.isEmpty) {
              return const InfoPanel(
                icon: Icons.rate_review_outlined,
                title: 'Todavía no tienes reseñas',
                description:
                    'Cuando un cliente califique un servicio tuyo y el '
                    'negocio la apruebe, aparecerá aquí.',
              );
            }

            final averageRating =
                reviews.fold<int>(0, (sum, review) => sum + review.rating) /
                reviews.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(
                      icon: Icons.star_outline,
                      title: 'Calificación promedio',
                      value: averageRating.toStringAsFixed(1),
                      description: 'Sobre 5 estrellas',
                    ),
                    MetricCard(
                      icon: Icons.forum_outlined,
                      title: 'Reseñas',
                      value: reviews.length.toString(),
                      description: 'Aprobadas por el negocio',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...reviews.map((review) => _ReviewCard(review: review)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final MyStylistReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StarsRow(rating: review.rating),
                  const Spacer(),
                  Text(
                    review.createdAtText,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${review.serviceName} · ${review.clientName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                review.commentText,
                style: const TextStyle(color: AppColors.textStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 18,
          color: AppColors.warning,
        );
      }),
    );
  }
}
