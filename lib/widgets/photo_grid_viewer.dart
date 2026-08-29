import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grid de fotos con visor modal (zoom con `InteractiveViewer`, sin paquete
/// nuevo). Compartido entre el portafolio público (D-165) y el portal de la
/// clienta (D-167) -- ambos son "una lista de fotos que se ven en grande al
/// tocarlas", solo cambia de dónde sale la lista.
class PhotoGridViewer extends StatelessWidget {
  const PhotoGridViewer({super.key, required this.photos});

  /// Una foto para el grid: su URL y, si tiene, un pie de foto.
  final List<({String url, String? caption})> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openViewer(context, photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              photo.url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.surfaceAlt,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openViewer(BuildContext context, ({String url, String? caption}) photo) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(photo.url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (photo.caption != null && photo.caption!.trim().isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.black54,
                  child: Text(
                    photo.caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
