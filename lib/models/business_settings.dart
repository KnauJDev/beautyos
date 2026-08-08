class BusinessSettings {
  final String id;
  final String name;
  final String businessType;
  final String contactEmail;
  final String contactPhone;
  final String whatsapp;
  final String instagram;
  final String facebook;
  final String? logoUrl;
  final String? coverPhotoUrl;

  /// Tema de marca blanca elegido (D-093b). Se guarda el nombre, no los
  /// colores: al afinar un tema mejoran solos todos los negocios que lo usan.
  final String? themeKey;

  /// Solo tiene valor cuando [themeKey] es `personalizado` (D-109).
  final String? brandColor;

  const BusinessSettings({
    required this.id,
    required this.name,
    required this.businessType,
    required this.contactEmail,
    required this.contactPhone,
    required this.whatsapp,
    required this.instagram,
    required this.facebook,
    this.logoUrl,
    this.coverPhotoUrl,
    this.themeKey,
    this.brandColor,
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
      logoUrl: map['logo_url']?.toString(),
      coverPhotoUrl: map['cover_photo_url']?.toString(),
      themeKey: map['theme_key']?.toString(),
      brandColor: map['brand_color']?.toString(),
    );
  }
}
