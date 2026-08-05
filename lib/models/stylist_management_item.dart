class StylistManagementItem {
  const StylistManagementItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    required this.active,
    this.photoUrl,
    this.bio,
  });

  final String id;
  final String name;
  final String phone;
  final String specialty;
  final bool active;
  final String? photoUrl;
  final String? bio;

  factory StylistManagementItem.fromMap(Map<String, dynamic> map) {
    return StylistManagementItem(
      id: map['stylist_id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      phone: map['phone']?.toString() ?? 'Sin teléfono',
      specialty: map['specialty']?.toString() ?? 'Sin especialidad',
      active: map['active'] == true,
      photoUrl: map['photo_url']?.toString(),
      bio: map['bio']?.toString(),
    );
  }
}
