/// Un artículo de blog visto desde el panel del salón (paso 6.6, D-171):
/// incluye los borradores, a diferencia de [PublicSalonBlogPost].
class BlogPost {
  const BlogPost({
    required this.id,
    required this.title,
    required this.content,
    this.coverPhotoUrl,
    required this.published,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String? coverPhotoUrl;
  final bool published;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BlogPost.fromMap(Map<String, dynamic> map) {
    return BlogPost(
      id: map['id'] as String,
      title: map['title']?.toString() ?? 'Sin título',
      content: map['content']?.toString() ?? '',
      coverPhotoUrl: map['cover_photo_url']?.toString(),
      published: map['published'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  String get statusText => published ? 'Publicado' : 'Borrador';

  String get createdDateText {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();
    return '$day/$month/$year';
  }
}
