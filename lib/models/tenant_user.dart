class TenantUser {
  const TenantUser({
    required this.profileId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.active,
    required this.stylistId,
    required this.stylistName,
    required this.createdAt,
  });

  final String profileId;
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final bool active;
  final String? stylistId;
  final String? stylistName;
  final DateTime? createdAt;

  factory TenantUser.fromMap(Map<String, dynamic> map) {
    return TenantUser(
      profileId: map['profile_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Usuario BeautyOS',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? 'client',
      active: map['active'] == true,
      stylistId: map['stylist_id']?.toString(),
      stylistName: map['stylist_name']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  bool get isOwner => role == 'owner';

  bool get hasStylistLink => stylistId != null && stylistId!.isNotEmpty;

  String get roleText {
    switch (role) {
      case 'owner':
        return 'Propietario';
      case 'admin':
        return 'Administrador';
      case 'stylist':
        return 'Estilista';
      case 'assistant':
        return 'Asistente';
      case 'client':
        return 'Cliente';
      default:
        return 'Usuario';
    }
  }
}
