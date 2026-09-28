import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/agenda_page.dart' show buildWhatsAppUri;
import '../services/client_consent_service.dart';

/// Paso 9.48, Bloque 4 (D-288): el salón le pide a la clienta que decida
/// sobre sus fotos y su reseña, mandándole por WhatsApp SU enlace
/// (`?autorizar=`, D-287). Desde que se quitó la casilla al subir la foto
/// (AQ), esta es la única forma de conseguir el permiso: lo da ella.
///
/// Se usa desde tres sitios, por decisión del propietario (28-sep): al subir
/// la foto, en la galería y en la ficha de la clienta. Dueño, administrador
/// o asistente; la base se lo niega a un estilista.
class PedirAutorizacion {
  const PedirAutorizacion._();

  static const textoBoton = 'Pedir autorización por WhatsApp';

  /// El mensaje exacto, decidido por el propietario el 28-sep.
  static String mensaje({
    required String nombre,
    required String salon,
    required String enlace,
  }) {
    final primerNombre = nombre.trim().split(' ').first;
    final saludo = primerNombre.isEmpty ? 'Hola' : 'Hola $primerNombre';
    return '$saludo, en $salon nos encantó cómo quedó tu servicio. Aquí puedes '
        'decidir si nos autorizas a mostrar tus fotos y tu reseña: $enlace. '
        'Tú decides y puedes cambiarlo cuando quieras.';
  }

  static String enlace(String token, {String? origen}) =>
      '${origen ?? _origen()}/?autorizar=$token';

  /// El dominio desde el que se usa la app. Fuera de la web (pruebas),
  /// `Uri.base` no tiene origen y se usa el del producto.
  static String _origen() {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
    return 'https://salonymas.com';
  }

  /// Pide los datos a la base y abre WhatsApp con el mensaje listo. Si la
  /// clienta no tiene celular, copia el mensaje para mandarlo por otro lado.
  static Future<void> enviar(
    BuildContext context,
    String clientId, {
    ClientConsentService service = const ClientConsentService(),
  }) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final datos = await service.whatsappData(clientId);
      final texto = mensaje(
        nombre: datos.clientName,
        salon: datos.businessName,
        enlace: enlace(datos.token),
      );
      final celular = datos.clientPhone;
      if (celular == null || celular.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
        await Clipboard.setData(ClipboardData(text: texto));
        mensajero.showSnackBar(
          const SnackBar(
            content: Text(
              'Esta clienta no tiene celular registrado. Copié el mensaje con '
              'su enlace para que se lo envíes por otro medio.',
            ),
          ),
        );
        return;
      }
      await launchUrl(
        buildWhatsAppUri(celular, text: texto),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      final detalle = error is PostgrestException
          ? error.message
          : 'Revisa tu conexión e intenta otra vez.';
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo preparar el mensaje. $detalle')),
      );
    }
  }
}

/// El botón, igual en los tres sitios.
class BotonPedirAutorizacion extends StatelessWidget {
  const BotonPedirAutorizacion({
    super.key,
    required this.clientId,
    this.compacto = false,
    this.service = const ClientConsentService(),
  });

  final String clientId;
  final bool compacto;
  final ClientConsentService service;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: compacto
          ? OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            )
          : null,
      onPressed: () =>
          PedirAutorizacion.enviar(context, clientId, service: service),
      icon: Icon(Icons.chat_outlined, size: compacto ? 14 : 16),
      label: const Text(PedirAutorizacion.textoBoton),
    );
  }
}

/// Después de subir una foto desde Tickets: la foto nace sin
/// permiso de publicar, así que se ofrece pedírselo a ella en ese momento.
Future<void> ofrecerPedirAutorizacion(
  BuildContext context, {
  required String clientId,
  required String clientName,
}) {
  final nombre = clientName.trim().isEmpty ? 'la clienta' : clientName.trim();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Foto agregada'),
      content: Text(
        'Para mostrarla en tu página o en redes necesitas que $nombre la '
        'autorice. Envíale su enlace por WhatsApp: ella decide desde su '
        'celular.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            PedirAutorizacion.enviar(context, clientId);
          },
          icon: const Icon(Icons.chat_outlined, size: 16),
          label: const Text(PedirAutorizacion.textoBoton),
        ),
      ],
    ),
  );
}
