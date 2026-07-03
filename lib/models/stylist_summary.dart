class StylistSummary {
  final String id;
  final String name;
  final String phone;
  final String specialty;
  final DateTime? createdAt;

  const StylistSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    required this.createdAt,
  });

  factory StylistSummary.fromMap(Map<String, dynamic> map) {
    return StylistSummary(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      phone: map['phone']?.toString() ?? 'Sin tel\u00e9fono',
      specialty: map['specialty']?.toString() ?? 'Sin especialidad',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  String get createdDateText {
    if (createdAt == null) {
      return 'Sin fecha';
    }

    final localDate = createdAt!.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    return '$day/$month/$year';
  }
}
