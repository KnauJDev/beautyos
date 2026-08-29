import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_salon_blog_post.dart';
import '../models/public_salon_photo_item.dart';
import '../models/public_salon_profile.dart';
import '../models/public_salon_review_item.dart';
import '../models/public_salon_service_item.dart';
import '../models/public_salon_team_member.dart';

/// Llama a las RPC públicas (rol "anon", sin sesión) que arman la página
/// completa de un negocio (D-098, D-164, D-165).
class PublicSalonService {
  const PublicSalonService();

  /// `null` si el slug no existe o el negocio no está activo.
  Future<PublicSalonProfile?> getSalonBySlug(String slug) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_by_slug',
      params: {'p_slug': slug},
    );

    final rows = response as List;
    if (rows.isEmpty) return null;

    return PublicSalonProfile.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<List<PublicSalonServiceItem>> getServices(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_services',
      params: {'p_tenant_id': tenantId},
    );

    return (response as List)
        .map(
          (item) => PublicSalonServiceItem.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<PublicSalonPhotoItem>> getPortfolio(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_portfolio',
      params: {'p_tenant_id': tenantId},
    );

    return (response as List)
        .map(
          (item) => PublicSalonPhotoItem.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<PublicSalonTeamMember>> getTeam(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_team',
      params: {'p_tenant_id': tenantId},
    );

    return (response as List)
        .map(
          (item) => PublicSalonTeamMember.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<PublicSalonReviewsSummary> getReviews(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_reviews',
      params: {'p_tenant_id': tenantId},
    );

    return PublicSalonReviewsSummary.fromRows(response as List);
  }

  Future<List<PublicSalonBlogPost>> getBlogPosts(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_blog_posts',
      params: {'p_tenant_id': tenantId},
    );

    return (response as List)
        .map(
          (item) => PublicSalonBlogPost.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Perfil completo de la página pública: resuelve el slug primero (para
  /// tener el `tenant_id`) y luego trae servicios, portafolio, equipo,
  /// reseñas y blog en paralelo. `null` si el slug no existe.
  Future<PublicSalonFullProfile?> getFullProfile(String slug) async {
    final profile = await getSalonBySlug(slug);
    if (profile == null) return null;

    final results = await Future.wait([
      getServices(profile.tenantId),
      getPortfolio(profile.tenantId),
      getTeam(profile.tenantId),
      getReviews(profile.tenantId),
      getBlogPosts(profile.tenantId),
    ]);

    return PublicSalonFullProfile(
      profile: profile,
      services: results[0] as List<PublicSalonServiceItem>,
      portfolio: results[1] as List<PublicSalonPhotoItem>,
      team: results[2] as List<PublicSalonTeamMember>,
      reviews: results[3] as PublicSalonReviewsSummary,
      blogPosts: results[4] as List<PublicSalonBlogPost>,
    );
  }
}
