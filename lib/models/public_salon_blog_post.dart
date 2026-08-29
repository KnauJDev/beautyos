/// Un artículo publicado del blog del negocio (paso 6.6, D-171). Sin url
/// propia por artículo en esta versión: se navega solo desde dentro de la
/// página pública del negocio.
class PublicSalonBlogPost {
  const PublicSalonBlogPost({
    required this.id,
    required this.title,
    required this.content,
    this.coverPhotoUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final String? coverPhotoUrl;
  final DateTime? createdAt;

  factory PublicSalonBlogPost.fromMap(Map<String, dynamic> map) {
    return PublicSalonBlogPost(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Sin título',
      content: map['content']?.toString() ?? '',
      coverPhotoUrl: map['cover_photo_url']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  /// Resumen corto para la tarjeta de la lista -- corta en un límite de
  /// palabra, nunca a mitad de una, y agrega "…" solo si de verdad recortó.
  String get excerpt {
    final limpio = content.trim();
    const limite = 140;

    if (limpio.length <= limite) return limpio;

    final cortado = limpio.substring(0, limite);
    final ultimoEspacio = cortado.lastIndexOf(' ');
    final sinPartir = ultimoEspacio > 0
        ? cortado.substring(0, ultimoEspacio)
        : cortado;

    return '$sinPartir…';
  }
}
