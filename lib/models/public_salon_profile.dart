import 'business_hour.dart';
import 'precios_desde.dart';
import 'public_salon_blog_post.dart';
import 'public_salon_photo_item.dart';
import 'public_salon_review_item.dart';
import 'public_salon_service_item.dart';
import 'public_salon_team_member.dart';
import 'redes_sociales.dart';

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
    this.tiktok,
    this.primaryBranchId,
    this.businessHours = const [],
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

  /// D-319: usuario (@salon) o dirección, como lo escriba el salón.
  final String? tiktok;

  /// Sede a la que apunta el botón "Agendar Cita" (D-165). Null si el
  /// negocio no tiene ninguna sede principal activa.
  final String? primaryBranchId;

  /// Horario de la sede principal (D-165). Vacío si no hay ninguno sembrado.
  final List<BusinessHour> businessHours;

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
      tiktok: map['tiktok']?.toString(),
      primaryBranchId: map['primary_branch_id']?.toString(),
      businessHours: (map['business_hours'] as List<dynamic>? ?? [])
          .map(
            (item) => BusinessHour.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
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

  // D-321 (08-oct): las tres redes aceptan el usuario (con o sin "@") o el
  // enlace del perfil, y devuelven null si lo escrito no lleva a ningún
  // perfil (un nombre con espacios, como "Inspirant salon"): la página no
  // enseña un botón que manda a una cuenta que no existe.

  Uri? get instagramUri => enlaceDeRed(
    instagram,
    dominio: 'instagram.com',
    armar: (u) => Uri.https('instagram.com', '/$u'),
  );

  Uri? get facebookUri => enlaceDeRed(
    facebook,
    dominio: 'facebook.com',
    armar: (u) => Uri.https('facebook.com', '/$u'),
  );

  /// D-319. En TikTok el perfil lleva la "@" en la dirección: tiktok.com/@salon.
  Uri? get tiktokUri => enlaceDeRed(
    tiktok,
    dominio: 'tiktok.com',
    armar: (u) => Uri.https('www.tiktok.com', '/@$u'),
  );
}

/// Todo lo que necesita la página pública del negocio en una sola llamada:
/// el perfil y las cuatro listas que se cargan en paralelo (D-165).
class PublicSalonFullProfile {
  const PublicSalonFullProfile({
    required this.profile,
    required this.services,
    required this.portfolio,
    required this.team,
    required this.reviews,
    required this.blogPosts,
    this.serviciosConEstilista,
    this.preciosDesde = PreciosDesde.ninguno,
  });

  final PublicSalonProfile profile;
  final List<PublicSalonServiceItem> services;
  final List<PublicSalonPhotoItem> portfolio;
  final List<PublicSalonTeamMember> team;
  final PublicSalonReviewsSummary reviews;

  /// Artículos publicados del blog (paso 6.6, D-171).
  final List<PublicSalonBlogPost> blogPosts;

  /// Los servicios que se pueden reservar en línea en la sede principal:
  /// los que tienen al menos un estilista asignado. Los demás dicen
  /// "Pregunta por WhatsApp" en vez de *Reservar* (D-322), y así el salón ve
  /// también a cuál le falta estilista. `null` si no se pudo saber: entonces
  /// todos dicen *Reservar*, como antes.
  final Set<String>? serviciosConEstilista;

  /// Las categorías con precio "desde" (D-326).
  final PreciosDesde preciosDesde;
}
