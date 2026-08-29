/// Una reseña pública ya moderada y aprobada (D-165).
class PublicSalonReviewItem {
  const PublicSalonReviewItem({
    required this.clientName,
    required this.rating,
    this.comment,
    this.businessReply,
    this.createdAt,
  });

  final String clientName;
  final int rating;
  final String? comment;

  /// Respuesta pública del salón a esta reseña (paso 6.3, D-170).
  final String? businessReply;
  final DateTime? createdAt;

  factory PublicSalonReviewItem.fromMap(Map<String, dynamic> map) {
    return PublicSalonReviewItem(
      clientName: map['client_name']?.toString() ?? 'Clienta',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString(),
      businessReply: map['business_reply']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}

/// Promedio, total y últimas reseñas públicas de un negocio (D-165).
///
/// `get_public_salon_reviews` devuelve el promedio y el total repetidos en
/// cada fila (o cero filas si no hay reseñas visibles); este envoltorio los
/// separa una sola vez para que la pantalla no tenga que leerlos de la
/// primera reseña de la lista.
class PublicSalonReviewsSummary {
  const PublicSalonReviewsSummary({
    required this.avgRating,
    required this.totalReviews,
    required this.reviews,
  });

  final double avgRating;
  final int totalReviews;
  final List<PublicSalonReviewItem> reviews;

  static const empty = PublicSalonReviewsSummary(
    avgRating: 0,
    totalReviews: 0,
    reviews: [],
  );

  factory PublicSalonReviewsSummary.fromRows(List<dynamic> rows) {
    if (rows.isEmpty) return empty;

    final maps = rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    return PublicSalonReviewsSummary(
      avgRating: (maps.first['avg_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (maps.first['total_reviews'] as num?)?.toInt() ?? 0,
      reviews: maps.map(PublicSalonReviewItem.fromMap).toList(),
    );
  }
}
