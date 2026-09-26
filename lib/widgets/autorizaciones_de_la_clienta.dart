import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/client_consent.dart';
import '../pages/agenda_page.dart' show buildWhatsAppUri;
import '../services/client_consent_service.dart';
import '../services/epayco_checkout_service.dart' show EpaycoCheckoutService;
import '../theme/app_theme.dart';

/// Donde la clienta decide sobre SUS fotos y SUS reseñas (paso 9.48, D-281 y
/// D-282), y donde puede cambiar de opinión (Ley 1581).
///
/// Es una pieza aparte, no parte del portal, porque la usan dos pantallas:
/// el portal con PIN (D-167) y el enlace directo. Las dos llegan a la misma
/// base por la misma [ClientConsentCredential].
///
/// **Los textos son decisión del propietario (26-sep), no del asistente:**
/// la pregunta de la foto, los botones, las tres formas de aparecer en una
/// reseña, y el aviso con WhatsApp al retirar una foto ya publicada.
class AutorizacionesDeLaClienta extends StatefulWidget {
  const AutorizacionesDeLaClienta({
    super.key,
    required this.credencial,
    required this.nombreSalon,
    this.whatsappSalon,
    this.ocultarSiNoHayNada = false,
    this.espacioDebajo = 0,
    this.alCambiar,
    this.service = const ClientConsentService(),
  });

  final ClientConsentCredential credencial;

  /// Respaldo si la base no trae el nombre del salón.
  final String nombreSalon;
  final String? whatsappSalon;

  /// En el portal, si no hay nada que decidir, esta pieza no ocupa sitio.
  final bool ocultarSiNoHayNada;

  /// Espacio bajo la pieza, solo cuando se ve: si no hay nada que decidir y
  /// se oculta, no deja un hueco en blanco.
  final double espacioDebajo;

  /// Se avisa después de cada decisión que salió bien. El portal lo usa
  /// para recargar "Mis fotos": una foto retirada ya no está publicada.
  final VoidCallback? alCambiar;
  final ClientConsentService service;

  /// El texto exacto de la pregunta de la foto (decisión del propietario).
  static String preguntaDeFoto(String salon) =>
      '¿Autorizas a $salon a mostrar esta foto en su página y en sus redes '
      'sociales?';

  /// `null` si el nombre sirve; si no, el motivo. Mismos topes que la base
  /// (`reviews_client_display_name_len`): de 2 a 40 letras.
  static String? validarNombrePropio(String texto) {
    final limpio = texto.trim();
    if (limpio.length < 2) return 'Escribe al menos 2 letras.';
    if (limpio.length > 40) return 'Máximo 40 letras.';
    return null;
  }

  /// El nombre con el que sale la reseña en público, según lo que eligió.
  static String nombrePublico(ConsentReview resena, String nombreReal) {
    switch (resena.choice) {
      case ReviewNameChoice.nombreReal:
        return nombreReal;
      case ReviewNameChoice.nombrePropio:
        return resena.displayName ?? nombreReal;
      case ReviewNameChoice.verificada:
      case null:
        return 'Clienta verificada';
    }
  }

  @override
  State<AutorizacionesDeLaClienta> createState() =>
      _AutorizacionesDeLaClientaState();
}

class _AutorizacionesDeLaClientaState extends State<AutorizacionesDeLaClienta> {
  ClientConsentOverview? _datos;
  bool _cargando = true;
  String? _errorCarga;
  bool _ocupado = false;

  /// Una sola petición de dirección por foto. Si se pidiera dentro del
  /// `build`, cada reconstrucción volvería a firmar (la lección de D-211).
  final Map<String, Future<String?>> _direcciones = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String get _salon => _datos?.businessName ?? widget.nombreSalon;
  String? get _whatsapp => _datos?.businessWhatsapp ?? widget.whatsappSalon;

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final datos = await widget.service.getOverview(widget.credencial);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorCarga = _mensaje(error);
        _cargando = false;
      });
    }
  }

  Future<String?> _direccion(ConsentPhoto foto) {
    return _direcciones.putIfAbsent(
      foto.id,
      () => widget.service.photoViewUrl(foto, widget.credencial),
    );
  }

  static String _mensaje(Object error) {
    if (error is PostgrestException) return error.message;
    final delServidor = EpaycoCheckoutService.mensajeDelServidor(error);
    if (delServidor != null) return delServidor;
    return 'No se pudo completar. Revisa tu conexión e intenta otra vez.';
  }

  /// Corre una acción, avisa si falla y recarga lo que se ve. Mientras
  /// corre, ningún otro botón responde: dos toques rápidos no mandan dos
  /// decisiones.
  Future<bool> _hacer(Future<void> Function() accion) async {
    if (_ocupado) return false;
    setState(() => _ocupado = true);
    try {
      await accion();
      await _cargar();
      widget.alCambiar?.call();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mensaje(error)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // ---------------------------------------------------------------------
  // Fotos
  // ---------------------------------------------------------------------

  Future<void> _decidirFoto(ConsentPhoto foto, bool autoriza) async {
    // Decir "no" a una foto que ya está en internet es retirarla: va por el
    // camino que la saca del almacén público primero (D-282).
    if (!autoriza && foto.isPublished) {
      await _retirarPublicada(foto);
      return;
    }
    await _hacer(
      () => widget.service.setPhoto(foto.id, autoriza, widget.credencial),
    );
  }

  Future<void> _retirarPublicada(ConsentPhoto foto) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar autorización'),
        content: Text(
          'La foto se quitará de la página de $_salon. ¿Quieres retirarla?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, retirarla'),
          ),
        ],
      ),
    );
    if (confirma != true || !mounted) return;

    final hecho = await _hacer(
      () => widget.service.revokePublishedPhoto(foto.id, widget.credencial),
    );
    if (!hecho || !mounted) return;

    final whatsapp = _whatsapp;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Listo'),
        content: Text(
          'Ya no aparece en la página de $_salon. Si la compartieron en sus '
          'redes sociales, esa publicación la tiene que borrar el salón.',
        ),
        actions: [
          if (whatsapp != null && whatsapp.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () {
                launchUrl(
                  buildWhatsAppUri(
                    whatsapp,
                    text: 'Hola, retiré mi autorización para que publiquen '
                        'una foto mía. Si la compartieron en sus redes '
                        'sociales, ¿me ayudan a quitarla? Gracias.',
                  ),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Avisar al salón por WhatsApp'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Reseñas
  // ---------------------------------------------------------------------

  Future<void> _elegirNombre(ConsentReview resena) async {
    final nombreReal = _datos?.clientName ?? 'Clienta';
    final eleccion = await showDialog<ReviewNameChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('¿Cómo quieres aparecer en tu reseña?'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(ReviewNameChoice.verificada),
            child: const Text('Como «Clienta verificada»'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(ReviewNameChoice.nombreReal),
            child: Text('Con mi nombre ($nombreReal)'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(ReviewNameChoice.nombrePropio),
            child: const Text('Con otro nombre, que escribo yo'),
          ),
        ],
      ),
    );
    if (eleccion == null || !mounted) return;

    switch (eleccion) {
      case ReviewNameChoice.verificada:
        await _hacer(
          () => widget.service.setReviewName(
            resena.id,
            false,
            widget.credencial,
          ),
        );
      case ReviewNameChoice.nombreReal:
        await _hacer(
          () => widget.service.setReviewName(
            resena.id,
            true,
            widget.credencial,
          ),
        );
      case ReviewNameChoice.nombrePropio:
        final alias = await showDialog<String>(
          context: context,
          builder: (context) => _DialogoNombrePropio(
            inicial: resena.displayName ?? '',
          ),
        );
        if (alias == null || !mounted) return;
        await _hacer(
          () => widget.service.setReviewAlias(
            resena.id,
            alias,
            widget.credencial,
          ),
        );
    }
  }

  // ---------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final contenido = _contenido();
    if (contenido == null) return const SizedBox.shrink();
    if (widget.espacioDebajo == 0) return contenido;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.espacioDebajo),
      child: contenido,
    );
  }

  /// `null` cuando la pieza no debe ocupar sitio.
  Widget? _contenido() {
    if (_cargando && _datos == null) {
      if (widget.ocultarSiNoHayNada) return null;
      return const _Tarjeta(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final datos = _datos;
    if (datos == null) {
      return _Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _errorCarga ?? 'No se pudo cargar.',
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (datos.vacio) {
      if (widget.ocultarSiNoHayNada) return null;
      return const _Tarjeta(
        child: Text(
          'No tienes fotos ni reseñas por autorizar.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (datos.pendientes > 0) ...[
          _Tarjeta(
            titulo: 'Por autorizar (${datos.pendientes})',
            icono: Icons.verified_user_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final foto in datos.pendingPhotos) ...[
                  _FotoPendiente(
                    foto: foto,
                    direccion: _direccion(foto),
                    pregunta: AutorizacionesDeLaClienta.preguntaDeFoto(_salon),
                    ocupado: _ocupado,
                    onDecidir: (autoriza) => _decidirFoto(foto, autoriza),
                  ),
                  const Divider(height: 32),
                ],
                for (final resena in datos.pendingReviews) ...[
                  _ResenaConNombre(
                    resena: resena,
                    comoSale: 'Mientras no elijas, tu reseña aparece como '
                        '«Clienta verificada».',
                    textoBoton: 'Elegir cómo aparezco',
                    ocupado: _ocupado,
                    onElegir: () => _elegirNombre(resena),
                  ),
                  const Divider(height: 32),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (datos.answeredPhotos.isNotEmpty ||
            datos.answeredReviews.isNotEmpty)
          _Tarjeta(
            titulo: 'Lo que ya respondiste',
            icono: Icons.history_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final foto in datos.answeredPhotos) ...[
                  _FotoRespondida(
                    foto: foto,
                    direccion: _direccion(foto),
                    salon: _salon,
                    ocupado: _ocupado,
                    onCambiar: () => _decidirFoto(
                      foto,
                      !(foto.authorized ?? false),
                    ),
                  ),
                  const Divider(height: 32),
                ],
                for (final resena in datos.answeredReviews) ...[
                  _ResenaConNombre(
                    resena: resena,
                    comoSale: 'Apareces como: '
                        '${AutorizacionesDeLaClienta.nombrePublico(resena, datos.clientName)}'
                        '${resena.esperaRevision ? '. El salón está revisando ese nombre: '
                              'tu reseña no se ve en su página mientras tanto.' : ''}',
                    textoBoton: 'Cambiar',
                    ocupado: _ocupado,
                    onElegir: () => _elegirNombre(resena),
                  ),
                  const Divider(height: 32),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.titulo, this.icono});

  final Widget child;
  final String? titulo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, color: AppColors.brand, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      titulo!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _Imagen extends StatelessWidget {
  const _Imagen({required this.direccion});

  final Future<String?> direccion;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: FutureBuilder<String?>(
          future: direccion,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(
                color: AppColors.surfaceAlt,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final url = snapshot.data;
            if (url == null) return const _SinImagen();
            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _SinImagen(),
            );
          },
        ),
      ),
    );
  }
}

class _SinImagen extends StatelessWidget {
  const _SinImagen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se pudo mostrar la foto. Actualiza la página para intentarlo '
            'otra vez.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _FotoPendiente extends StatelessWidget {
  const _FotoPendiente({
    required this.foto,
    required this.direccion,
    required this.pregunta,
    required this.ocupado,
    required this.onDecidir,
  });

  final ConsentPhoto foto;
  final Future<String?> direccion;
  final String pregunta;
  final bool ocupado;
  final ValueChanged<bool> onDecidir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Imagen(direccion: direccion),
        if (foto.caption != null && foto.caption!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            foto.caption!,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          pregunta,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: ocupado ? null : () => onDecidir(true),
              child: const Text('Sí, autorizo'),
            ),
            OutlinedButton(
              onPressed: ocupado ? null : () => onDecidir(false),
              child: const Text('No, prefiero que no'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FotoRespondida extends StatelessWidget {
  const _FotoRespondida({
    required this.foto,
    required this.direccion,
    required this.salon,
    required this.ocupado,
    required this.onCambiar,
  });

  final ConsentPhoto foto;
  final Future<String?> direccion;
  final String salon;
  final bool ocupado;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final autorizada = foto.authorized ?? false;
    final estado = !autorizada
        ? 'No autorizada'
        : foto.isPublished
            ? 'Autorizada · publicada en la página de $salon'
            : 'Autorizada · $salon todavía no la ha publicado';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: _Imagen(direccion: direccion)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                estado,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: ocupado ? null : onCambiar,
                child: Text(autorizada ? 'Retirar autorización' : 'Autorizar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResenaConNombre extends StatelessWidget {
  const _ResenaConNombre({
    required this.resena,
    required this.comoSale,
    required this.textoBoton,
    required this.ocupado,
    required this.onElegir,
  });

  final ConsentReview resena;
  final String comoSale;
  final String textoBoton;
  final bool ocupado;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final comentario = resena.comment?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '★' * resena.rating,
          style: const TextStyle(fontSize: 18, color: AppColors.warning),
        ),
        if (comentario != null && comentario.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('«$comentario»', style: const TextStyle(fontSize: 14)),
        ],
        const SizedBox(height: 8),
        Text(
          comoSale,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: ocupado ? null : onElegir,
          child: Text(textoBoton),
        ),
      ],
    );
  }
}

class _DialogoNombrePropio extends StatefulWidget {
  const _DialogoNombrePropio({required this.inicial});

  final String inicial;

  @override
  State<_DialogoNombrePropio> createState() => _DialogoNombrePropioState();
}

class _DialogoNombrePropioState extends State<_DialogoNombrePropio> {
  late final TextEditingController _controlador =
      TextEditingController(text: widget.inicial);
  String? _error;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _guardar() {
    final error = AutorizacionesDeLaClienta.validarNombrePropio(_controlador.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controlador.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Con qué nombre quieres aparecer?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controlador,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Nombre',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _guardar(),
          ),
          const Text(
            'El salón lo revisará antes de publicarlo. Mientras tanto, tu '
            'reseña no se verá en su página.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
