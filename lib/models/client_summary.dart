class ClientSummary {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final bool active;
  final DateTime? createdAt;

  const ClientSummary({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    this.active = true,
    required this.createdAt,
  });

  factory ClientSummary.fromMap(Map<String, dynamic> map) {
    return ClientSummary(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      phone: map['phone']?.toString() ?? 'Sin teléfono',
      email: map['email']?.toString(),
      notes: map['notes']?.toString(),
      active: map['active'] as bool? ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}
