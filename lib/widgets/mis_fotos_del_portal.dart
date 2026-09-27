import 'package:flutter/material.dart';

import '../models/client_consent.dart';
import '../models/client_portal_data.dart';
import '../services/client_consent_service.dart';
import '../theme/app_theme.dart';
import 'photo_grid_viewer.dart';

/// "Mis fotos de trabajos" del portal de la clienta (D-286, hallazgo AU).
///
/// Muestra **toda** foto que el salón le marcó como visible, esté o no en el
/// portafolio -- decisión del propietario del 27-sep. Hasta entonces el
/// portal solo recibía las publicadas, y el interruptor "Visible al cliente"
/// no hacía nada sin portafolio.
///
/// Las privadas llegan sin dirección: para cada una se pide una URL temporal
/// a `client-consent-photo-url` (D-281), que vuelve a comprobar con el token
/// que la foto es de ella. Cada miniatura lleva una etiqueta que dice si
/// está publicada en la página del salón o no.
class MisFotosDelPortal extends StatefulWidget {
  const MisFotosDelPortal({
    super.key,
    required this.fotos,
    required this.credencial,
    this.service = const ClientConsentService(),
  });

  final List<ClientPortalPhoto> fotos;
  final ClientConsentCredential credencial;
  final ClientConsentService service;

  static const etiquetaPublicada = 'En la página del salón';
  static const etiquetaSoloParaTi = 'Solo para ti';
  static const sinFotos = 'Todavía no tienes fotos aquí.';

  @override
  State<MisFotosDelPortal> createState() => _MisFotosDelPortalState();
}

class _MisFotosDelPortalState extends State<MisFotosDelPortal> {
  /// Dirección con la que se ve cada foto, por id. Las publicadas traen la
  /// suya; las privadas, la temporal (o '' si no se pudo: la miniatura
  /// muestra el ícono de foto rota en vez de quedarse cargando).
  Map<String, String>? _urls;

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  @override
  void didUpdateWidget(covariant MisFotosDelPortal anterior) {
    super.didUpdateWidget(anterior);
    if (_firma(anterior.fotos) != _firma(widget.fotos)) _resolver();
  }

  /// Cambia si llega otra foto, se va una, o una cambia de publicada a
  /// privada (el caso de retirar la autorización).
  static String _firma(List<ClientPortalPhoto> fotos) =>
      fotos.map((f) => '${f.id}:${f.inPortfolio}:${f.photoUrl}').join('|');

  Future<void> _resolver() async {
    final fotos = widget.fotos;
    final pares = await Future.wait(
      fotos.map((f) async {
        final url = f.photoUrl ??
            await widget.service.urlTemporal(f.id, widget.credencial);
        return MapEntry(f.id, url ?? '');
      }),
    );
    if (!mounted || _firma(fotos) != _firma(widget.fotos)) return;
    setState(() => _urls = Map.fromEntries(pares));
  }

  @override
  Widget build(BuildContext context) {
    final fotos = widget.fotos;
    if (fotos.isEmpty) {
      return const Text(
        MisFotosDelPortal.sinFotos,
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }

    final urls = _urls;
    if (urls == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return PhotoGridViewer(
      photos: [
        for (final f in fotos) (url: urls[f.id] ?? '', caption: f.caption),
      ],
      etiquetas: [
        for (final f in fotos)
          f.inPortfolio
              ? MisFotosDelPortal.etiquetaPublicada
              : MisFotosDelPortal.etiquetaSoloParaTi,
      ],
    );
  }
}
