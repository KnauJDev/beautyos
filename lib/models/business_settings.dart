class BusinessSettings {
  final String id;
  final String name;

  /// Nombre real del titular (user_profiles.full_name del owner). Null si el
  /// negocio todavía no tiene un owner con perfil activo.
  final String? contactName;
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

  /// Identificador del enlace público del negocio (D-098, D-164):
  /// `salonymas.com/<slug>`. Null si todavía no se le asignó uno.
  final String? slug;

  const BusinessSettings({
    required this.id,
    required this.name,
    this.contactName,
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
    this.slug,
  });

  factory BusinessSettings.fromMap(Map<String, dynamic> map) {
    return BusinessSettings(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sin nombre',
      contactName: map['contact_name']?.toString(),
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
      slug: map['slug']?.toString(),
    );
  }
}
