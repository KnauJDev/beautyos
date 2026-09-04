import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_settings.dart';
import '../models/publication_studio_data.dart';
import '../models/work_photo_summary.dart';
import '../services/business_settings_service.dart';
import '../services/work_photos_service.dart';
import '../theme/app_theme.dart';

/// Abre el Estudio de publicación (paso 6.2, D-169) para una foto ya
/// aprobada para portafolio y con consentimiento de la clienta.
Future<void> showPublicationStudioDialog(
  BuildContext context, {
  required String branchId,
  required WorkPhotoSummary photo,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PublicationStudioDialog(branchId: branchId, photo: photo),
  );
}

class _StudioContent {
  const _StudioContent({required this.data, required this.business});

  final PublicationStudioData data;
  final BusinessSettings business;
}

class _PublicationStudioDialog extends StatefulWidget {
  const _PublicationStudioDialog({
    required this.branchId,
    required this.photo,
  });

  final String branchId;
  final WorkPhotoSummary photo;

  @override
  State<_PublicationStudioDialog> createState() =>
      _PublicationStudioDialogState();
}

class _PublicationStudioDialogState extends State<_PublicationStudioDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  late final Future<_StudioContent> _future;
  bool _incluirResena = true;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<_StudioContent> _cargar() async {
    final service = WorkPhotosService(branchId: widget.branchId);
    final data = await service.getPublicationStudioData(widget.photo.id);
    final business = await const BusinessSettingsService().getBusinessSettings();

    // Se espera a que las imágenes ya estén decodificadas en el caché antes
    // de mostrar el botón de descarga: `RepaintBoundary.toImage()` captura
    // lo que ya se pintó, y una red lenta dejaría la captura con la foto o
    // el logo en blanco si se permitiera descargar antes de tiempo.
    if (mounted) {
      final porCachear = <Future<void>>[
        precacheImage(NetworkImage(data.photoUrl), context),
      ];
      final logo = business.logoUrl;
      if (logo != null && logo.trim().isNotEmpty) {
        porCachear.add(precacheImage(NetworkImage(logo), context));
      }
      await Future.wait(porCachear);
    }

    if (!data.tieneResena) {
      _incluirResena = false;
    }

    return _StudioContent(data: data, business: business);
  }

  Future<void> _descargar() async {
    setState(() => _generando = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dataUri = Uri.parse(
        'data:image/png;base64,${base64Encode(bytes)}',
      );

      await launchUrl(dataUri, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Imagen abierta en una pestaña nueva -- guárdala desde ahí.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo generar la imagen: $message')));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: FutureBuilder<_StudioContent>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estudio de publicación',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'No se pudo preparar la imagen para publicación. Revisa tu conexión a internet o intenta nuevamente más tarde.',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  );
                }

                final content = snapshot.data!;
                return _StudioReady(
                  content: content,
                  boundaryKey: _boundaryKey,
                  incluirResena: _incluirResena,
                  onIncluirResenaChanged: (value) =>
                      setState(() => _incluirResena = value),
                  generando: _generando,
                  onDescargar: _descargar,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioReady extends StatelessWidget {
  const _StudioReady({
    required this.content,
    required this.boundaryKey,
    required this.incluirResena,
    required this.onIncluirResenaChanged,
    required this.generando,
    required this.onDescargar,
  });

  final _StudioContent content;
  final GlobalKey boundaryKey;
  final bool incluirResena;
  final ValueChanged<bool> onIncluirResenaChanged;
  final bool generando;
  final VoidCallback onDescargar;

  @override
  Widget build(BuildContext context) {
    final data = content.data;
    final business = content.business;
    final tieneWhatsapp =
        business.whatsapp.trim().isNotEmpty &&
        business.whatsapp != 'Sin WhatsApp';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⭐ Estudio de publicación',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Lista para Instagram: foto + logo + servicio, sin salir de la app.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SizedBox(
            width: 320,
            height: 320,
            child: FittedBox(
              child: SizedBox(
                width: 1080,
                height: 1080,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: _PublicationCard(
                    photoUrl: data.photoUrl,
                    businessName: business.name,
                    logoUrl: business.logoUrl,
                    serviceText: data.servicioTexto,
                    whatsapp: tieneWhatsapp ? business.whatsapp : null,
                    reviewComment: incluirResena && data.tieneResena
                        ? data.reviewComment
                        : null,
                    reviewClientName: incluirResena && data.tieneResena
                        ? data.reviewClientName
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (data.tieneResena) ...[
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: incluirResena,
            onChanged: onIncluirResenaChanged,
            title: Text(
              'Incluir reseña de ${data.reviewClientName ?? "la clienta"}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: generando ? null : onDescargar,
              icon: generando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: Text(generando ? 'Generando…' : 'Descargar imagen'),
            ),
          ],
        ),
      ],
    );
  }
}

/// La tarjeta 1080x1080 en sí. Vive en tamaño real (no escalado) para que
/// `RepaintBoundary.toImage()` capture resolución completa lista para
/// Instagram -- el `FittedBox` de arriba solo la muestra más chica en
/// pantalla, no cambia lo que hay dentro del boundary.
class _PublicationCard extends StatelessWidget {
  const _PublicationCard({
    required this.photoUrl,
    required this.businessName,
    required this.logoUrl,
    required this.serviceText,
    required this.whatsapp,
    this.reviewComment,
    this.reviewClientName,
  });

  final String photoUrl;
  final String businessName;
  final String? logoUrl;
  final String serviceText;
  final String? whatsapp;
  final String? reviewComment;
  final String? reviewClientName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(photoUrl, fit: BoxFit.cover),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 48,
            left: 48,
            right: 48,
            child: Row(
              children: [
                if (logoUrl != null && logoUrl!.trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      logoUrl!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    businessName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 48,
            right: 48,
            bottom: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  serviceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                  ),
                ),
                if (reviewComment != null && reviewComment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    '"$reviewComment"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (reviewClientName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '— $reviewClientName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                        ),
                      ),
                    ),
                ],
                if (whatsapp != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Agenda por WhatsApp: $whatsapp',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
