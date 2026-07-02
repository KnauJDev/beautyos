class ClientSummary {
  final String id;
  final String name;
  final String phone;
  final DateTime? createdAt;

  const ClientSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  factory ClientSummary.fromMap(Map<String, dynamic> map) {
    return ClientSummary(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      phone: map['phone']?.toString() ?? 'Sin teléfono',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}
