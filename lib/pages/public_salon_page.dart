import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/public_salon_photo_item.dart';
import '../models/public_salon_profile.dart';
import '../models/public_salon_review_item.dart';
import '../models/public_salon_service_item.dart';
import '../models/public_salon_team_member.dart';
import '../services/public_salon_service.dart';
import '../widgets/photo_grid_viewer.dart';
import 'agenda_page.dart' show buildWhatsAppUri;
import 'client_portal_page.dart';
import 'public_booking_page.dart';

/// Página pública del negocio (D-098, D-164, D-165):
/// `salonymas.com/<slug>`. No requiere sesión -- usa el rol "anon". Se
/// llega aquí por el segmento de ruta o por "?salon=`slug`" (ver
/// main.dart), no por AuthGate.
class PublicSalonPage extends StatefulWidget {
  const PublicSalonPage({super.key, required this.slug});

  final String slug;

  @override
  State<PublicSalonPage> createState() => _PublicSalonPageState();
}

class _PublicSalonPageState extends State<PublicSalonPage> {
  final PublicSalonService salonService = const PublicSalonService();

  bool isLoading = true;
  String? loadError;
  PublicSalonFullProfile? fullProfile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await salonService.getFullProfile(widget.slug);

      if (!mounted) return;

      // D-093d: el visitante ve los colores de ESE salón, no los de Salón y
      // Más. Se aplica antes del setState para que la pantalla se pinte ya
      // con el tema del negocio.
      if (result != null) {
        AppBrand.aplicar(result.profile.themeKey, result.profile.brandColor);
      }

      setState(() {
        fullProfile = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = error.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (loadError != null) {
      return _MessageCard(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        title: 'No se pudo cargar esta página',
        message: loadError!,
        onRetry: _load,
      );
    }

    final result = fullProfile;
    if (result == null) {
      return const _MessageCard(
        icon: Icons.storefront_outlined,
        iconColor: AppColors.textMuted,
        title: 'Este negocio no existe',
        message:
            'El enlace que abriste no corresponde a ningún negocio activo '
            'en Salón y Más. Puede que haya cambiado de dirección.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroHeader(
          salon: result.profile,
          reviews: result.reviews,
          onBook: result.profile.primaryBranchId == null
              ? null
              : () => _openBooking(result.profile.primaryBranchId!),
          onOpenPortal: () => _openClientPortal(result.profile),
        ),
        if (result.services.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ServicesSection(
            services: result.services,
            onReserve: result.profile.primaryBranchId == null
                ? null
                : (serviceId) => _openBooking(
                    result.profile.primaryBranchId!,
                    preselectedServiceId: serviceId,
                  ),
          ),
        ],
        if (result.portfolio.isNotEmpty) ...[
          const SizedBox(height: 20),
          _PortfolioSection(photos: result.portfolio),
        ],
        if (result.team.isNotEmpty) ...[
          const SizedBox(height: 20),
          _TeamSection(team: result.team),
        ],
        if (result.reviews.totalReviews > 0) ...[
          const SizedBox(height: 20),
          _ReviewsSection(summary: result.reviews),
        ],
        const SizedBox(height: 20),
        _HoursLocationSection(salon: result.profile),
      ],
    );
  }

  void _openBooking(String branchId, {String? preselectedServiceId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicBookingPage(
          branchId: branchId,
          preselectedServiceId: preselectedServiceId,
        ),
      ),
    );
  }

  void _openClientPortal(PublicSalonProfile salon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientPortalPage(
          tenantId: salon.tenantId,
          businessName: salon.name,
          businessWhatsapp: salon.whatsapp,
        ),
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Encabezado (portada, logo, nombre, calificación, contacto)
// =============================================================================

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.salon,
    required this.reviews,
    required this.onBook,
    required this.onOpenPortal,
  });

  final PublicSalonProfile salon;
  final PublicSalonReviewsSummary reviews;
  final VoidCallback? onBook;
  final VoidCallback onOpenPortal;

  Future<void> _abrir(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (salon.coverPhotoUrl != null)
            Image.network(
              salon.coverPhotoUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (salon.logoUrl != null) ...[
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        salon.logoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  salon.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDeep,
                  ),
                ),
                if (salon.businessType != null &&
                    salon.businessType!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    salon.businessType!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (salon.locationLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    salon.locationLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (reviews.totalReviews > 0) ...[
                  const SizedBox(height: 10),
                  _StarRatingLine(
                    rating: reviews.avgRating,
                    totalReviews: reviews.totalReviews,
                  ),
                ],
                if (onBook != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onBook,
                    icon: const Text('📅', style: TextStyle(fontSize: 16)),
                    label: const Text('Agendar Cita'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (salon.whatsapp != null &&
                        salon.whatsapp!.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(
                          buildWhatsAppUri(
                            salon.whatsapp!,
                            text: 'Hola, vengo de tu página en Salón y Más '
                                '¿me cuentas más?',
                          ),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: AppColors.whatsapp,
                        ),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.whatsapp,
                        ),
                      ),
                    if (salon.contactPhone != null &&
                        salon.contactPhone!.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(
                          Uri.parse('tel:${salon.contactPhone}'),
                        ),
                        icon: const Icon(Icons.call_outlined, size: 16),
                        label: const Text('Llamar'),
                      ),
                    if (salon.instagramUri != null)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(salon.instagramUri!),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Instagram'),
                      ),
                    if (salon.facebookUri != null)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(salon.facebookUri!),
                        icon: const Icon(Icons.public_outlined, size: 16),
                        label: const Text('Facebook'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: onOpenPortal,
                    icon: const Text('👤', style: TextStyle(fontSize: 14)),
                    label: const Text('Mis citas y fotos'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRatingLine extends StatelessWidget {
  const _StarRatingLine({required this.rating, required this.totalReviews});

  final double rating;
  final int totalReviews;

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.round().clamp(0, 5);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < fullStars ? Icons.star : Icons.star_border,
            size: 18,
            color: AppColors.warning,
          ),
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} ($totalReviews '
          '${totalReviews == 1 ? 'reseña' : 'reseñas'})',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// =============================================================================
// SECCIÓN GENÉRICA
// =============================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.brand, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Servicios
// =============================================================================

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.services, required this.onReserve});

  final List<PublicSalonServiceItem> services;
  final void Function(String serviceId)? onReserve;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Servicios',
      icon: Icons.content_cut_outlined,
      child: Column(
        children: [
          for (final service in services) ...[
            _ServiceRow(service: service, onReserve: onReserve),
            if (service != services.last) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.onReserve});

  final PublicSalonServiceItem service;
  final void Function(String serviceId)? onReserve;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (service.description != null &&
                  service.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  service.description!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    service.durationLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    service.priceLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onReserve != null) ...[
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => onReserve!(service.id),
            child: const Text('Reservar'),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// SECCIÓN: Portafolio
// =============================================================================

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({required this.photos});

  final List<PublicSalonPhotoItem> photos;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Portafolio',
      icon: Icons.photo_library_outlined,
      child: PhotoGridViewer(
        photos: photos
            .map((photo) => (url: photo.photoUrl, caption: photo.caption))
            .toList(),
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Equipo
// =============================================================================

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.team});

  final List<PublicSalonTeamMember> team;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Equipo',
      icon: Icons.groups_outlined,
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final member in team) _TeamMemberCard(member: member)],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({required this.member});

  final PublicSalonTeamMember member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.brandTint,
            backgroundImage: member.photoUrl != null
                ? NetworkImage(member.photoUrl!)
                : null,
            child: member.photoUrl == null
                ? Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (member.bio != null && member.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              member.bio!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Reseñas
// =============================================================================

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.summary});

  final PublicSalonReviewsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Reseñas',
      icon: Icons.star_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StarRatingLine(
            rating: summary.avgRating,
            totalReviews: summary.totalReviews,
          ),
          const SizedBox(height: 16),
          for (final review in summary.reviews) ...[
            _ReviewTile(review: review),
            if (review != summary.reviews.last) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PublicSalonReviewItem review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              review.clientName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.warning,
                  ),
              ],
            ),
          ],
        ),
        if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            review.comment!,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// SECCIÓN: Horarios y Ubicación
// =============================================================================

class _HoursLocationSection extends StatelessWidget {
  const _HoursLocationSection({required this.salon});

  final PublicSalonProfile salon;

  Future<void> _abrir(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Uri? get _mapsUri {
    final address = salon.address?.trim();
    if (address == null || address.isEmpty) return null;

    final city = salon.city?.trim();
    final query = city != null && city.isNotEmpty ? '$address, $city' : address;

    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Horarios y ubicación',
      icon: Icons.schedule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (salon.locationLine.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(salon.locationLine)),
              ],
            ),
            if (_mapsUri != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _abrir(context, _mapsUri!),
                icon: const Text('📍', style: TextStyle(fontSize: 14)),
                label: const Text('Ver en Google Maps'),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (salon.businessHours.isEmpty)
            const Text(
              'Este negocio todavía no publicó su horario de atención.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            for (final hour in salon.businessHours)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(hour.dayName, style: const TextStyle(fontSize: 13)),
                    Text(
                      hour.scheduleText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hour.isOpen
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// =============================================================================
// ESTADOS DE MENSAJE (cargando / error / no encontrado)
// =============================================================================

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
