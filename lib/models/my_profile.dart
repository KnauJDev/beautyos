class MyProfile {
  const MyProfile({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.active,
  });

  final String id;
  final String? tenantId;
  final String? tenantName;
  final String userId;
  final String fullName;
  final String role;
  final bool active;

  factory MyProfile.fromMap(Map<String, dynamic> map) {
    return MyProfile(
      id: map['id']?.toString() ?? '',
      tenantId: map['tenant_id']?.toString(),
      tenantName: map['tenant_name']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Usuario BeautyOS',
      role: map['role']?.toString() ?? 'client',
      active: map['active'] == true,
    );
  }

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

  bool get isOwnerOrAdmin {
    return role == 'owner' || role == 'admin';
  }

  bool get isStylist {
    return role == 'stylist';
  }

  bool get isClient {
    return role == 'client';
  }
}
