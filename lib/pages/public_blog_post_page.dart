import 'package:flutter/material.dart';

import '../models/public_salon_blog_post.dart';
import '../theme/app_theme.dart';

/// Un artículo del blog a pantalla completa (paso 6.6, D-171). Sin url
/// propia todavía -- se llega solo empujado (`Navigator.push`) desde la
/// página pública del negocio, mismo patrón que `PublicBookingPage` y
/// `PublicReviewPage`.
class PublicBlogPostPage extends StatelessWidget {
  const PublicBlogPostPage({super.key, required this.post});

  final PublicSalonBlogPost post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.coverPhotoUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Image.network(
                      post.coverPhotoUrl!,
                      width: double.infinity,
                      height: 240,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (post.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fecha(post.createdAt!),
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fecha(DateTime fecha) {
    final local = fecha.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }
}
