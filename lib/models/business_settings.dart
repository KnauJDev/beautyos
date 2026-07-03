class BusinessSettings {
  final String id;
  final String name;
  final String businessType;
  final String contactEmail;
  final String contactPhone;
  final String whatsapp;
  final String instagram;
  final String facebook;

  const BusinessSettings({
    required this.id,
    required this.name,
    required this.businessType,
    required this.contactEmail,
    required this.contactPhone,
    required this.whatsapp,
    required this.instagram,
    required this.facebook,
  });

  factory BusinessSettings.fromMap(Map<String, dynamic> map) {
    return BusinessSettings(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sin nombre',
      businessType: map['business_type']?.toString() ?? 'Sin tipo de negocio',
      contactEmail: map['contact_email']?.toString() ?? 'Sin correo',
      contactPhone: map['contact_phone']?.toString() ?? 'Sin teléfono',
      whatsapp: map['whatsapp']?.toString() ?? 'Sin WhatsApp',
      instagram: map['instagram']?.toString() ?? 'Sin Instagram',
      facebook: map['facebook']?.toString() ?? 'Sin Facebook',
    );
  }
}
