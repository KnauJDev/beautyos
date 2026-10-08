import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grid de fotos con visor modal (zoom con `InteractiveViewer`, sin paquete
/// nuevo). Compartido entre el portafolio público (D-165) y el portal de la
/// clienta (D-167) -- ambos son "una lista de fotos que se ven en grande al
/// tocarlas", solo cambia de dónde sale la lista.
class PhotoGridViewer extends StatelessWidget {
  const PhotoGridViewer({super.key, required this.photos, this.etiquetas});

  /// Una foto para el grid: su URL y, si tiene, un pie de foto.
  final List<({String url, String? caption})> photos;

  /// Opcional: una etiqueta corta por foto, pintada sobre la miniatura, en
  /// el mismo orden que [photos] (`null` = sin etiqueta). La usa el portal
  /// de la clienta para distinguir lo publicado de lo que es solo para ella
  /// (D-286, AU). El portafolio público no la pasa y se ve igual que antes.
  final List<String?>? etiquetas;

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
        final etiqueta = (etiquetas != null && index < etiquetas!.length)
            ? etiquetas![index]
            : null;
        final miniatura = Image.network(
          photo.url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surfaceAlt,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textMuted,
            ),
          ),
        );
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => abrirFotoEnGrande(context, photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: etiqueta == null
                ? miniatura
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      miniatura,
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              etiqueta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// El visor en grande (zoom con `InteractiveViewer`). Lo usan esta grilla y
/// el carrusel de *Nuestro trabajo* de la página pública (D-320).
void abrirFotoEnGrande(
  BuildContext context,
  ({String url, String? caption}) photo,
) {
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
