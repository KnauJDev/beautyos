/// Un estilista activo del equipo de un negocio, para su página pública
/// (D-165). `color_code` no existe en `stylists`: viajan `photo_url` y
/// `bio` (D-084) en su lugar.
class PublicSalonTeamMember {
  const PublicSalonTeamMember({
    required this.id,
    required this.name,
    this.photoUrl,
    this.bio,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String? bio;

  factory PublicSalonTeamMember.fromMap(Map<String, dynamic> map) {
    return PublicSalonTeamMember(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Estilista',
      photoUrl: map['photo_url']?.toString(),
      bio: map['bio']?.toString(),
    );
  }
}
