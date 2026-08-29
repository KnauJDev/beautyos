/// Datos para componer la tarjeta del Estudio de publicación (paso 6.2,
/// D-169): la foto ya pública, el o los servicios del ticket, y una reseña
/// real del mismo ticket cuando existe una de buena calificación (4-5
/// estrellas, aprobada y visible al público -- el servidor ya filtra esto,
/// aquí solo se lee lo que llegó).
class PublicationStudioData {
  const PublicationStudioData({
    required this.photoUrl,
    this.serviceNames,
    this.reviewRating,
    this.reviewComment,
    this.reviewClientName,
  });

  final String photoUrl;
  final String? serviceNames;
  final int? reviewRating;
  final String? reviewComment;
  final String? reviewClientName;

  bool get tieneResena =>
      reviewRating != null &&
      reviewComment != null &&
      reviewComment!.trim().isNotEmpty;

  String get servicioTexto =>
      (serviceNames == null || serviceNames!.trim().isEmpty)
      ? 'Servicio realizado'
      : serviceNames!;

  factory PublicationStudioData.fromMap(Map<String, dynamic> map) {
    return PublicationStudioData(
      photoUrl: map['photo_url'] as String,
      serviceNames: map['service_names']?.toString(),
      reviewRating: map['review_rating'] == null
          ? null
          : int.tryParse(map['review_rating'].toString()),
      reviewComment: map['review_comment']?.toString(),
      reviewClientName: map['review_client_name']?.toString(),
    );
  }
}
