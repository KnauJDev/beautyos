import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/descargar_archivo.dart';
import '../theme/app_theme.dart';

/// El código QR del enlace del salón (D-319, 07-oct). La tarjeta *Tu enlace*
/// decía "compártelo en un código QR", pero la app no lo hacía: el salón
/// tenía que fabricarlo en otra página. Ahora se ve y se descarga como imagen
/// para imprimir (mostrador, espejo, tarjetas).
///
/// Corrección de errores **media** (QrErrorCorrectLevel.M): un QR impreso se
/// raya o se dobla, y con la baja (la de por defecto) deja de leerse antes.
const nivelDelQr = QrErrorCorrectLevel.M;

/// "qr-peluqueria-exito-prueba.png": el nombre del archivo que se descarga.
String nombreDelArchivoQr(String? nombreDelSalon) {
  const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final base = (nombreDelSalon ?? '')
      .toLowerCase()
      .split('')
      .map((c) => tildes[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return base.isEmpty ? 'qr-de-tu-salon.png' : 'qr-$base.png';
}

/// La imagen para imprimir: fondo blanco, el QR con su margen (sin margen,
/// sobre un mostrador oscuro, la cámara no lo encuentra), y debajo el nombre
/// del salón y "Agenda tu cita aquí".
Future<Uint8List> imagenDelCodigoQr({
  required String enlace,
  String? nombreDelSalon,
}) async {
  const lado = 720.0;
  const margen = 72.0;
  const ancho = lado + 2 * margen;

  final nombre = nombreDelSalon?.trim() ?? '';
  TextPainter texto(String s, double tam, Color color, FontWeight peso) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: color,
            fontSize: tam,
            fontWeight: peso,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: lado);

  final titulo = texto(
    nombre.isEmpty ? 'Agenda tu cita' : nombre,
    44,
    Colors.black,
    FontWeight.w700,
  );
  final subtitulo = texto(
    nombre.isEmpty ? 'Escanéalo con la cámara' : 'Agenda tu cita aquí',
    30,
    // Gris fijo y no el del tema: es para imprimir, igual en todos los salones.
    Colors.black54,
    FontWeight.w400,
  );
  final alto = margen + lado + 40 + titulo.height + 12 + subtitulo.height + margen;

  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  lienzo.drawRect(
    Rect.fromLTWH(0, 0, ancho, alto),
    Paint()..color = Colors.white,
  );
  lienzo.save();
  lienzo.translate(margen, margen);
  QrPainter(
    data: enlace,
    version: QrVersions.auto,
    errorCorrectionLevel: nivelDelQr,
    gapless: true,
  ).paint(lienzo, const Size(lado, lado));
  lienzo.restore();
  var y = margen + lado + 40;
  titulo.paint(lienzo, Offset((ancho - titulo.width) / 2, y));
  y += titulo.height + 12;
  subtitulo.paint(lienzo, Offset((ancho - subtitulo.width) / 2, y));

  final imagen = await grabadora.endRecording().toImage(
    ancho.ceil(),
    alto.ceil(),
  );
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}

/// La ventana del QR: se ve, y se descarga.
Future<void> mostrarCodigoQr(
  BuildContext context, {
  required String enlace,
  String? nombreDelSalon,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _VentanaDelQr(enlace: enlace, nombreDelSalon: nombreDelSalon),
  );
}

class _VentanaDelQr extends StatefulWidget {
  const _VentanaDelQr({required this.enlace, this.nombreDelSalon});

  final String enlace;
  final String? nombreDelSalon;

  @override
  State<_VentanaDelQr> createState() => _VentanaDelQrState();
}

class _VentanaDelQrState extends State<_VentanaDelQr> {
  bool _descargando = false;

  Future<void> _descargar() async {
    setState(() => _descargando = true);
    try {
      final bytes = await imagenDelCodigoQr(
        enlace: widget.enlace,
        nombreDelSalon: widget.nombreDelSalon,
      );
      await descargarArchivo(
        bytes,
        nombre: nombreDelArchivoQr(widget.nombreDelSalon),
        tipo: 'image/png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen descargada: está en tus Descargas, lista para imprimir.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar la imagen: $error')),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código QR de tu enlace'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: widget.enlace,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: nivelDelQr,
                semanticsLabel: 'Código QR de ${widget.enlace}',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Imprímelo y ponlo en el mostrador, el espejo o tus tarjetas: '
              'tus clientes lo escanean con la cámara del celular y se abre tu '
              'página para agendar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _descargando ? null : _descargar,
          icon: _descargando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 18),
          label: const Text('Descargar imagen'),
        ),
      ],
    );
  }
}
