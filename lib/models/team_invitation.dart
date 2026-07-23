class TeamInvitation {
  const TeamInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.stylistName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String email;
  final String role;
  final String? stylistName;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory TeamInvitation.fromMap(Map<String, dynamic> map) {
    return TeamInvitation(
      id: map['invitation_id'].toString(),
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      stylistName: map['stylist_name']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      expiresAt: map['expires_at'] == null
          ? null
          : DateTime.tryParse(map['expires_at'].toString()),
    );
  }

  String get roleText {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'stylist':
        return 'Estilista';
      case 'assistant':
        return 'Asistente';
      default:
        return role;
    }
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptada';
      case 'cancelled':
        return 'Cancelada';
      case 'expired':
        return 'Vencida';
      default:
        return status;
    }
  }
}
