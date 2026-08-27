import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/public_salon_profile.dart';
import '../services/public_salon_service.dart';
import 'agenda_page.dart' show buildWhatsAppUri;

/// Página pública del negocio (D-098, D-164): `salonymas.com/<slug>`. No
/// requiere sesión -- usa el rol "anon" y solo llama a
/// `get_public_salon_by_slug`. Se llega aquí por el segmento de ruta o por
/// "?salon=`slug`" (ver main.dart), no por AuthGate.
///
/// Base del paso 5.1 a 5.4. El portafolio de fotos, el catálogo de
/// servicios y el botón de reserva llegan en el paso 5.5.
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
  PublicSalonProfile? profile;

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
      final result = await salonService.getSalonBySlug(widget.slug);

      if (!mounted) return;

      // D-093d: el visitante ve los colores de ESE salón, no los de Salón y
      // Más. Se aplica antes del setState para que la pantalla se pinte ya
      // con el tema del negocio.
      if (result != null) {
        AppBrand.aplicar(result.themeKey, result.brandColor);
      }

      setState(() {
        profile = result;
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
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

    final salon = profile;
    if (salon == null) {
      return const _MessageCard(
        icon: Icons.storefront_outlined,
        iconColor: AppColors.textMuted,
        title: 'Este negocio no existe',
        message:
            'El enlace que abriste no corresponde a ningún negocio activo '
            'en Salón y Más. Puede que haya cambiado de dirección.',
      );
    }

    return _SalonProfileCard(salon: salon);
  }
}

class _SalonProfileCard extends StatelessWidget {
  const _SalonProfileCard({required this.salon});

  final PublicSalonProfile salon;

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
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (salon.whatsapp != null &&
                        salon.whatsapp!.trim().isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _abrir(
                          buildWhatsAppUri(
                            salon.whatsapp!,
                            text: 'Hola, vengo de tu página en Salón y Más '
                                '¿me cuentas más?',
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.whatsapp,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (salon.contactPhone != null &&
                        salon.contactPhone!.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(
                          Uri.parse('tel:${salon.contactPhone}'),
                        ),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('Llamar'),
                      ),
                    if (salon.instagramUri != null)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(salon.instagramUri!),
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                        ),
                        label: const Text('Instagram'),
                      ),
                    if (salon.facebookUri != null)
                      OutlinedButton.icon(
                        onPressed: () => _abrir(salon.facebookUri!),
                        icon: const Icon(Icons.public_outlined, size: 18),
                        label: const Text('Facebook'),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 16),
                const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.textMuted,
                  size: 28,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Muy pronto: fotos de trabajos, catálogo de servicios y '
                  'reserva en línea directo desde esta página.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
