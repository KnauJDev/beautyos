import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blog_post.dart';

/// CRUD del blog del propio negocio (paso 6.6, D-171). Autoservicio, sin
/// `branchId`: el blog es del tenant, no de una sede -- mismo criterio que
/// `BusinessSettingsService` (nombre, logo, slug).
class BlogService {
  const BlogService();

  Future<List<BlogPost>> getBlogPosts() async {
    final response = await Supabase.instance.client.rpc(
      'get_blog_posts_summary',
    );

    return (response as List)
        .map(
          (item) => BlogPost.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<String> createBlogPost({
    required String title,
    required String content,
    String? coverPhotoUrl,
    required bool published,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_blog_post',
      params: {
        'p_title': title,
        'p_content': content,
        'p_cover_photo_url': coverPhotoUrl,
        'p_published': published,
      },
    );

    return response as String;
  }

  Future<void> updateBlogPost({
    required String postId,
    required String title,
    required String content,
    String? coverPhotoUrl,
    required bool published,
  }) async {
    await Supabase.instance.client.rpc(
      'update_blog_post',
      params: {
        'p_post_id': postId,
        'p_title': title,
        'p_content': content,
        'p_cover_photo_url': coverPhotoUrl,
        'p_published': published,
      },
    );
  }

  Future<void> deleteBlogPost(String postId) async {
    await Supabase.instance.client.rpc(
      'delete_blog_post',
      params: {'p_post_id': postId},
    );
  }
}
