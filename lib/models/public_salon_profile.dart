/// Perfil comercial público de un negocio, resuelto por su slug sin sesión
/// (D-098, D-164). Solo trae datos de vitrina -- nada operativo ni de
/// contacto administrativo interno (eso vive en `BusinessSettings`).
class PublicSalonProfile {
  const PublicSalonProfile({
    required this.tenantId,
    required this.name,
    required this.slug,
    this.businessType,
    this.logoUrl,
    this.coverPhotoUrl,
    this.themeKey,
    this.brandColor,
    this.city,
    this.address,
    this.whatsapp,
    this.contactPhone,
    this.instagram,
    this.facebook,
  });

  final String tenantId;
  final String name;
  final String slug;
  final String? businessType;
  final String? logoUrl;
  final String? coverPhotoUrl;

  /// Tema de marca blanca del negocio (D-093d): la página pública se pinta
  /// con los colores del salón, no los de Salón y Más.
  final String? themeKey;

  /// Solo tiene valor cuando [themeKey] es `personalizado` (D-109).
  final String? brandColor;

  final String? city;

  /// De la sede principal activa del tenant -- `tenants` no tiene dirección
  /// propia, solo cada sede.
  final String? address;

  final String? whatsapp;
  final String? contactPhone;
  final String? instagram;
  final String? facebook;

  factory PublicSalonProfile.fromMap(Map<String, dynamic> map) {
    return PublicSalonProfile(
      tenantId: map['tenant_id'].toString(),
      name: map['name']?.toString() ?? 'Este negocio',
      slug: map['slug']?.toString() ?? '',
      businessType: map['business_type']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      coverPhotoUrl: map['cover_photo_url']?.toString(),
      themeKey: map['theme_key']?.toString(),
      brandColor: map['brand_color']?.toString(),
      city: map['city']?.toString(),
      address: map['address']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      contactPhone: map['contact_phone']?.toString(),
      instagram: map['instagram']?.toString(),
      facebook: map['facebook']?.toString(),
    );
  }

  /// "Ciudad · Dirección", con lo que haya disponible.
  String get locationLine {
    return [city, address]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
  }

  /// Handle de Instagram sin el "@" que ya trae el hint del campo en
  /// Configuración (ej. "@naguaradeunas" -> "naguaradeunas").
  String? get instagramHandle {
    final value = instagram?.trim();
    if (value == null || value.isEmpty) return null;
    return value.startsWith('@') ? value.substring(1) : value;
  }

  Uri? get instagramUri {
    final handle = instagramHandle;
    if (handle == null || handle.isEmpty) return null;
    return Uri.https('instagram.com', '/$handle');
  }

  Uri? get facebookUri {
    final value = facebook?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value);
    }
    final handle = value.startsWith('@') ? value.substring(1) : value;
    return Uri.https('facebook.com', '/$handle');
  }
}
