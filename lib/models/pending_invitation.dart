class PendingInvitation {
  const PendingInvitation({
    required this.invitationId,
    required this.tenantName,
    required this.branchName,
    required this.role,
  });

  final String invitationId;
  final String tenantName;
  final String branchName;
  final String role;

  factory PendingInvitation.fromMap(Map<String, dynamic> map) {
    return PendingInvitation(
      invitationId: map['invitation_id'].toString(),
      tenantName: map['tenant_name']?.toString() ?? 'este negocio',
      branchName: map['branch_name']?.toString() ?? 'su sede',
      role: map['role']?.toString() ?? '',
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
}
