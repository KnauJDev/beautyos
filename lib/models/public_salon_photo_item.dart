/// Una foto del portafolio público de un negocio (D-165). Solo llegan aquí
/// fotos con `approved_for_portfolio = true` y `visible_to_customer = true`.
class PublicSalonPhotoItem {
  const PublicSalonPhotoItem({
    required this.id,
    required this.photoUrl,
    this.photoType,
    this.caption,
    this.createdAt,
  });

  final String id;
  final String photoUrl;
  final String? photoType;
  final String? caption;
  final DateTime? createdAt;

  factory PublicSalonPhotoItem.fromMap(Map<String, dynamic> map) {
    return PublicSalonPhotoItem(
      id: map['id'].toString(),
      photoUrl: map['photo_url']?.toString() ?? '',
      photoType: map['photo_type']?.toString(),
      caption: map['caption']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}
