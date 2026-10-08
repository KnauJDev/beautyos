import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/pagina_publica.dart';
import '../models/public_salon_blog_post.dart';
import '../models/public_salon_photo_item.dart';
import '../models/public_salon_profile.dart';
import '../models/public_salon_review_item.dart';
import '../models/public_salon_service_item.dart';
import '../models/public_salon_team_member.dart';
import '../models/tipo_de_negocio.dart';
import '../services/public_salon_service.dart';
import '../widgets/photo_grid_viewer.dart' show abrirFotoEnGrande;
import 'agenda_page.dart' show buildWhatsAppUri;
import 'client_portal_page.dart';
import 'public_blog_post_page.dart';
import 'public_booking_page.dart';

/// Página pública del negocio (D-098, D-164, D-165):
/// `salonymas.com/<slug>`. No requiere sesión -- usa el rol "anon". Se
/// llega aquí por el segmento de ruta o por "?salon=`slug`" (ver
/// main.dart), no por AuthGate.
///
/// **Rediseñada el 08-oct (D-320)** con el prototipo que aprobó el
/// propietario (https://claude.ai/artifact/H4GUdBqnaVu1h3rhzTgGPF): la
/// portada manda, "abierto ahora", botones redondos, el trabajo arriba,
/// servicios por categoría, equipo y reseñas en tarjetas, y *Agendar cita*
/// siempre a mano. Usa solo lo que la página ya recibía del servidor.
class PublicSalonPage extends StatefulWidget {
  const PublicSalonPage({super.key, required this.slug});

  final String slug;

  @override
  State<PublicSalonPage> createState() => _PublicSalonPageState();
}

/// Desde este ancho, la página va en dos columnas y la reserva queda fija a
/// la derecha; por debajo, la barra de *Agendar cita* va abajo.
const anchoParaDosColumnas = 1000.0;

Future<void> abrirEnlace(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// El mensaje con que la clienta escribe por WhatsApp desde la página.
const mensajeDesdeLaPagina = 'Hola, vengo de tu página en Salón y Más '
    '¿me cuentas más?';

class _PublicSalonPageState extends State<PublicSalonPage> {
  final PublicSalonService salonService = const PublicSalonService();
  final ScrollController _scroll = ScrollController();

  bool isLoading = true;
  String? loadError;
  PublicSalonFullProfile? fullProfile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    final result = fullProfile;
    if (isLoading || loadError != null || result == null) {
      return Scaffold(
        backgroundColor: AppColors.brandSurface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _buildMensaje(),
              ),
            ),
          ),
        ),
      );
    }

    final salon = result.profile;
    final onBook = salon.primaryBranchId == null
        ? null
        : () => _openBooking(salon.primaryBranchId!);
    final whatsapp = salon.whatsapp?.trim() ?? '';
    final angosta = MediaQuery.sizeOf(context).width < anchoParaDosColumnas;

    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      body: ContenidoDeLaPaginaPublica(
        perfil: result,
        ahora: ahoraEnColombia(),
        scroll: _scroll,
        onBook: onBook,
        onReserve: salon.primaryBranchId == null
            ? null
            : (serviceId) => _openBooking(
                salon.primaryBranchId!,
                preselectedServiceId: serviceId,
              ),
        onOpenPortal: () => _openClientPortal(salon),
      ),
      // En el celular, *Agendar cita* nunca se va (D-320).
      bottomNavigationBar: angosta && onBook != null
          ? BarraDeReserva(
              onBook: onBook,
              onWhatsApp: whatsapp.isEmpty
                  ? null
                  : () => abrirEnlace(
                      buildWhatsAppUri(whatsapp, text: mensajeDesdeLaPagina),
                    ),
            )
          : null,
    );
  }

  Widget _buildMensaje() {
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

    return const _MessageCard(
      icon: Icons.storefront_outlined,
      iconColor: AppColors.textMuted,
      title: 'Este negocio no existe',
      message:
          'El enlace que abriste no corresponde a ningún negocio activo '
          'en Salón y Más. Puede que haya cambiado de dirección.',
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
// LA PÁGINA YA CARGADA
// =============================================================================

/// La página del salón con sus datos, sin consultas: lo que dibuja
/// [PublicSalonPage] cuando llegan. Es pública para poder dibujarla en una
/// prueba a lo ancho de un celular y de un computador.
class ContenidoDeLaPaginaPublica extends StatefulWidget {
  const ContenidoDeLaPaginaPublica({
    super.key,
    required this.perfil,
    required this.ahora,
    this.scroll,
    this.onBook,
    this.onReserve,
    this.onOpenPortal,
    this.onAbrir = abrirEnlace,
  });

  final PublicSalonFullProfile perfil;

  /// La hora en Colombia ([ahoraEnColombia]): de ella sale "abierto ahora".
  final DateTime ahora;
  final ScrollController? scroll;
  final VoidCallback? onBook;
  final void Function(String serviceId)? onReserve;
  final VoidCallback? onOpenPortal;

  /// Abre WhatsApp, el mapa o una red. Las pruebas lo cambian.
  final Future<void> Function(Uri uri) onAbrir;

  @override
  State<ContenidoDeLaPaginaPublica> createState() =>
      _ContenidoDeLaPaginaPublicaState();
}

class _ContenidoDeLaPaginaPublicaState
    extends State<ContenidoDeLaPaginaPublica> {
  /// Para la columna de la reserva que acompaña al bajar (computador).
  final _claveDelContenido = GlobalKey();
  final _claveDePrincipal = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final perfil = widget.perfil;
    final salon = perfil.profile;
    final estado = estadoDeApertura(salon.businessHours, widget.ahora);

    return LayoutBuilder(
      builder: (context, c) {
        final dos = c.maxWidth >= anchoParaDosColumnas;
        final amplia = c.maxWidth >= 760;

        final principal = <Widget>[
          const SizedBox(height: 14),
          _Chips(
            estado: estado,
            resenas: perfil.reviews,
            reservaEnLinea: widget.onBook != null,
          ),
          if (widget.onBook != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _BotonAgendar(onBook: widget.onBook!),
            ),
          ],
          if (_contactos(salon).isNotEmpty) ...[
            const SizedBox(height: 12),
            _Contacto(items: _contactos(salon), onAbrir: widget.onAbrir),
          ],
          if (perfil.portfolio.isNotEmpty)
            _Seccion(
              titulo: 'Nuestro trabajo',
              extra: perfil.portfolio.length > 1 ? 'Desliza →' : null,
              child: _Carrusel(fotos: perfil.portfolio, amplia: amplia),
            ),
          if (perfil.services.isNotEmpty)
            _Servicios(servicios: perfil.services, onReserve: widget.onReserve),
          if (perfil.team.isNotEmpty)
            _Seccion(
              titulo: 'Quién te atiende',
              child: _Equipo(equipo: perfil.team),
            ),
          if (perfil.reviews.totalReviews > 0)
            _Seccion(
              titulo: 'Lo que dicen',
              child: _Resenas(
                resumen: perfil.reviews,
                ahora: widget.ahora,
                amplia: amplia,
              ),
            ),
          if (perfil.blogPosts.isNotEmpty)
            _Seccion(titulo: 'Blog', child: _Blog(posts: perfil.blogPosts)),
          _Seccion(
            titulo: 'Horarios y ubicación',
            child: _Horarios(
              salon: salon,
              ahora: widget.ahora,
              onAbrir: widget.onAbrir,
            ),
          ),
        ];

        final columnaPrincipal = Column(
          key: _claveDePrincipal,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: principal,
        );

        final cuerpo = dos
            ? Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: columnaPrincipal),
                        const SizedBox(width: 28),
                        SizedBox(
                          width: 340,
                          child: _ColumnaQueAcompana(
                            scroll: widget.scroll,
                            claveDelContenido: _claveDelContenido,
                            claveDePrincipal: _claveDePrincipal,
                            child: _Lateral(
                              salon: salon,
                              estado: estado,
                              ahora: widget.ahora,
                              onBook: widget.onBook,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: columnaPrincipal,
              );

        return SingleChildScrollView(
          controller: widget.scroll,
          child: Column(
            key: _claveDelContenido,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Portada(salon: salon, amplia: amplia, dos: dos),
              cuerpo,
              _Pie(onOpenPortal: widget.onOpenPortal),
            ],
          ),
        );
      },
    );
  }

  List<_ItemDeContacto> _contactos(PublicSalonProfile salon) {
    final whatsapp = salon.whatsapp?.trim() ?? '';
    final telefono = salon.contactPhone?.trim() ?? '';
    final mapa = enlaceDeMapa(salon);
    return [
      if (whatsapp.isNotEmpty)
        _ItemDeContacto(
          icono: Icons.chat_bubble_outline,
          etiqueta: 'WhatsApp',
          uri: buildWhatsAppUri(whatsapp, text: mensajeDesdeLaPagina),
          esWhatsApp: true,
        ),
      if (telefono.isNotEmpty)
        _ItemDeContacto(
          icono: Icons.call_outlined,
          etiqueta: 'Llamar',
          uri: Uri.parse('tel:$telefono'),
        ),
      if (mapa != null)
        _ItemDeContacto(
          icono: Icons.location_on_outlined,
          etiqueta: 'Cómo llegar',
          uri: mapa,
        ),
      if (salon.instagramUri != null)
        _ItemDeContacto(
          icono: Icons.camera_alt_outlined,
          etiqueta: 'Instagram',
          uri: salon.instagramUri!,
        ),
      if (salon.facebookUri != null)
        _ItemDeContacto(
          icono: Icons.public_outlined,
          etiqueta: 'Facebook',
          uri: salon.facebookUri!,
        ),
      // D-319: lo pidió David, el primer cliente real.
      if (salon.tiktokUri != null)
        _ItemDeContacto(
          icono: Icons.music_note_outlined,
          etiqueta: 'TikTok',
          uri: salon.tiktokUri!,
        ),
    ];
  }
}

// =============================================================================
// PORTADA
// =============================================================================

class _Portada extends StatelessWidget {
  const _Portada({required this.salon, required this.amplia, required this.dos});

  final PublicSalonProfile salon;
  final bool amplia;
  final bool dos;

  @override
  Widget build(BuildContext context) {
    final portada = salon.coverPhotoUrl?.trim() ?? '';
    final sub = [
      if (salon.businessType != null && salon.businessType!.trim().isNotEmpty)
        etiquetaDelTipoDeNegocio(salon.businessType!),
      if (salon.city != null && salon.city!.trim().isNotEmpty) salon.city!.trim(),
    ].join(' · ');

    return SizedBox(
      height: amplia ? 330 : 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (portada.isEmpty)
            const _FondoDeMarca()
          else
            Image.network(
              portada,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const _FondoDeMarca(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1],
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.62)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dos ? 1120 : double.infinity),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  dos ? 34 : 18,
                  0,
                  18,
                  amplia ? 28 : 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Logo(salon: salon, lado: amplia ? 96 : 72),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salon.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: amplia ? 38 : 26,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              sub,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sin portada, un fondo con los colores del salón.
class _FondoDeMarca extends StatelessWidget {
  const _FondoDeMarca();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandDeep,
            Color.lerp(AppColors.brand, AppColors.brandDeep, 0.3)!,
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.salon, required this.lado});

  final PublicSalonProfile salon;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final logo = salon.logoUrl?.trim() ?? '';
    final letras = Center(
      child: Text(
        iniciales(salon.name),
        style: TextStyle(
          fontSize: lado * 0.3,
          fontWeight: FontWeight.w800,
          color: AppColors.brand,
        ),
      ),
    );
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(lado * 0.24),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(lado * 0.24 - 3),
        child: logo.isEmpty
            ? letras
            : Image.network(
                logo,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => letras,
              ),
      ),
    );
  }
}

// =============================================================================
// CHIPS, BOTÓN Y CONTACTO
// =============================================================================

class _Chips extends StatelessWidget {
  const _Chips({
    required this.estado,
    required this.resenas,
    required this.reservaEnLinea,
  });

  final ({bool abierto, String texto})? estado;
  final PublicSalonReviewsSummary resenas;
  final bool reservaEnLinea;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (estado != null) ChipDeEstado(estado: estado!),
        if (resenas.totalReviews > 0)
          _Chip(
            icono: const Icon(Icons.star, size: 14, color: AppColors.warning),
            texto:
                '${calificacionLegible(resenas.avgRating)} · ${resenas.totalReviews} '
                '${resenas.totalReviews == 1 ? 'reseña' : 'reseñas'}',
          ),
        if (reservaEnLinea) const _Chip(texto: 'Reserva en línea, sin cuenta'),
      ],
    );
  }
}

class ChipDeEstado extends StatelessWidget {
  const ChipDeEstado({super.key, required this.estado});

  final ({bool abierto, String texto}) estado;

  @override
  Widget build(BuildContext context) {
    final color = estado.abierto ? AppColors.success : AppColors.danger;
    return _Chip(
      icono: Icon(Icons.circle, size: 8, color: color),
      texto: estado.texto,
      fondo: estado.abierto ? AppColors.successTint : AppColors.dangerTint,
      color: color,
      sinBorde: true,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    this.icono,
    this.fondo = AppColors.surface,
    this.color = AppColors.textPrimary,
    this.sinBorde = false,
  });

  final String texto;
  final Widget? icono;
  final Color fondo;
  final Color color;
  final bool sinBorde;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(99),
        border: sinBorde ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[icono!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonAgendar extends StatelessWidget {
  const _BotonAgendar({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onBook,
      // Ícono dibujado y no el emoji 📅: en Android el emoji dice "July 17",
      // en inglés, y no toma el color del tema (03-oct, D-316).
      icon: const Icon(Icons.event_available_outlined, size: 20),
      label: const Text('Agendar cita'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ItemDeContacto {
  const _ItemDeContacto({
    required this.icono,
    required this.etiqueta,
    required this.uri,
    this.esWhatsApp = false,
  });

  final IconData icono;
  final String etiqueta;
  final Uri uri;
  final bool esWhatsApp;
}

/// WhatsApp, llamar, cómo llegar y las redes, en botones redondos que se
/// reparten el ancho (con muchos, de a cuatro por fila).
class _Contacto extends StatelessWidget {
  const _Contacto({required this.items, required this.onAbrir});

  final List<_ItemDeContacto> items;
  final Future<void> Function(Uri uri) onAbrir;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const separacion = 8.0;
        final n = items.length;
        var ancho = (c.maxWidth - separacion * (n - 1)) / n;
        if (ancho < 60) ancho = (c.maxWidth - separacion * 3) / 4;
        ancho = ancho.clamp(56.0, 120.0).floorToDouble();
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [
            for (final item in items)
              SizedBox(
                width: ancho,
                child: Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onAbrir(item.uri),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.esWhatsApp
                                  ? AppColors.whatsapp.withValues(alpha: 0.12)
                                  : AppColors.brandTintSoft,
                            ),
                            child: Icon(
                              item.icono,
                              size: 18,
                              color: item.esWhatsApp
                                  ? AppColors.whatsapp
                                  : AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // En un renglón y, si no cabe, un poco más chico:
                          // con cinco botones partía "WhatsAp/p" (08-oct).
                          // Alto fijo: si un texto se achica, los botones no
                          // quedan de alturas distintas.
                          SizedBox(
                            height: 16,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.etiqueta,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECCIONES
// =============================================================================

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child, this.extra});

  final String titulo;
  final String? extra;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
              if (extra != null)
                Text(
                  extra!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Una caja blanca con borde fino: la forma de las tarjetas de la página.
BoxDecoration _caja({double radio = 18}) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(radio),
  border: Border.all(color: AppColors.border),
);

// ----------------------------------------------------------------- el trabajo

class _Carrusel extends StatelessWidget {
  const _Carrusel({required this.fotos, required this.amplia});

  final List<PublicSalonPhotoItem> fotos;
  final bool amplia;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth * (amplia ? 0.31 : 0.72)).floorToDouble();
        return SizedBox(
          height: (ancho * 1.25).floorToDouble(),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fotos.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final foto = fotos[index];
              final pie = foto.caption?.trim() ?? '';
              return SizedBox(
                width: ancho,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Material(
                    color: AppColors.brandTint,
                    child: InkWell(
                      onTap: () => abrirFotoEnGrande(
                        context,
                        (url: foto.photoUrl, caption: foto.caption),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            foto.photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_outlined,
                              color: AppColors.brand,
                            ),
                          ),
                          if (pie.isNotEmpty) ...[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.6, 1],
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: Text(
                                pie,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- servicios

class _Servicios extends StatefulWidget {
  const _Servicios({required this.servicios, required this.onReserve});

  final List<PublicSalonServiceItem> servicios;
  final void Function(String serviceId)? onReserve;

  @override
  State<_Servicios> createState() => _ServiciosState();
}

class _ServiciosState extends State<_Servicios> {
  /// Null = todas.
  String? _categoria;

  @override
  Widget build(BuildContext context) {
    final categorias = categoriasDeServicios(widget.servicios);
    final lista = _categoria == null
        ? widget.servicios
        : widget.servicios
              .where((s) => (s.description?.trim() ?? '') == _categoria)
              .toList();

    return _Seccion(
      titulo: 'Servicios',
      extra: lista.length == 1 ? '1 servicio' : '${lista.length} servicios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categorias.isNotEmpty) ...[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final cat in [null, ...categorias]) ...[
                    _Pildora(
                      texto: cat ?? 'Todas',
                      elegida: _categoria == cat,
                      onTap: () => setState(() => _categoria = cat),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _caja(),
            child: Column(
              children: [
                for (var i = 0; i < lista.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _FilaDeServicio(servicio: lista[i], onReserve: widget.onReserve),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora({required this.texto, required this.elegida, required this.onTap});

  final String texto;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forma = StadiumBorder(
      side: BorderSide(color: elegida ? AppColors.brandDeep : AppColors.border),
    );
    return Material(
      color: elegida ? AppColors.brandDeep : AppColors.surface,
      shape: forma,
      child: InkWell(
        customBorder: forma,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: elegida ? AppColors.textOnBrand : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaDeServicio extends StatelessWidget {
  const _FilaDeServicio({required this.servicio, required this.onReserve});

  final PublicSalonServiceItem servicio;
  final void Function(String serviceId)? onReserve;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  children: [
                    Text(
                      duracionLegible(servicio.durationMinutes),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    Text(
                      servicio.priceLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onReserve != null) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => onReserve!(servicio.id),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.brandTintSoft,
                foregroundColor: AppColors.brandDark,
                side: BorderSide(
                  color: Color.lerp(AppColors.brand, Colors.white, 0.6)!,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('Reservar'),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- equipo

class _Equipo extends StatelessWidget {
  const _Equipo({required this.equipo});

  final List<PublicSalonTeamMember> equipo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: equipo.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = equipo[index];
          final foto = m.photoUrl?.trim() ?? '';
          final inicial = _InicialDeMiembro(nombre: m.name);
          return Container(
            width: 150,
            clipBehavior: Clip.antiAlias,
            decoration: _caja(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: foto.isEmpty
                      ? inicial
                      : Image.network(
                          foto,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => inicial,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (m.bio != null && m.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          m.bio!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InicialDeMiembro extends StatelessWidget {
  const _InicialDeMiembro({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandTint, AppColors.brandTintSoft],
        ),
      ),
      child: Center(
        child: Text(
          nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase(),
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- reseñas

class _Estrellas extends StatelessWidget {
  const _Estrellas({required this.llenas});

  final int llenas;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < llenas ? Icons.star : Icons.star_border,
            size: 16,
            color: AppColors.warning,
          ),
      ],
    );
  }
}

class _Resenas extends StatelessWidget {
  const _Resenas({required this.resumen, required this.ahora, required this.amplia});

  final PublicSalonReviewsSummary resumen;
  final DateTime ahora;
  final bool amplia;

  @override
  Widget build(BuildContext context) {
    final total = resumen.totalReviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _caja(),
          child: Row(
            children: [
              Text(
                calificacionLegible(resumen.avgRating),
                style: TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandDeep,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Estrellas(llenas: resumen.avgRating.round().clamp(0, 5)),
                  const SizedBox(height: 3),
                  Text(
                    total == 1 ? '1 reseña' : '$total reseñas',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (resumen.reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Las tarjetas miden lo que la más larga, no una altura fija: con
          // un comentario corto quedaba media tarjeta en blanco (08-oct).
          LayoutBuilder(
            builder: (context, c) {
              final ancho = (c.maxWidth * (amplia ? 0.46 : 0.8)).floorToDouble();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < resumen.reviews.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        SizedBox(
                          width: ancho,
                          child: _TarjetaDeResena(
                            resena: resumen.reviews[i],
                            ahora: ahora,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _TarjetaDeResena extends StatelessWidget {
  const _TarjetaDeResena({required this.resena, required this.ahora});

  final PublicSalonReviewItem resena;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final comentario = resena.comment?.trim() ?? '';
    final respuesta = resena.businessReply?.trim() ?? '';
    final fecha = resena.createdAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _caja(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Estrellas(llenas: resena.rating.clamp(0, 5)),
          const SizedBox(height: 8),
          Text(
            comentario.isEmpty ? 'Sin comentario.' : '“$comentario”',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: comentario.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              resena.clientName,
              if (fecha != null) haceCuanto(fecha, ahora),
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (respuesta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandTintSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Respuesta del salón: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandDark,
                      ),
                    ),
                    TextSpan(text: respuesta),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textStrong),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- blog

class _Blog extends StatelessWidget {
  const _Blog({required this.posts});

  final List<PublicSalonBlogPost> posts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _caja(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final post in posts) ...[
            _BlogPostCard(post: post),
            if (post != posts.last) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _BlogPostCard extends StatelessWidget {
  const _BlogPostCard({required this.post});

  final PublicSalonBlogPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PublicBlogPostPage(post: post)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.coverPhotoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Image.network(
                  post.coverPhotoUrl!,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(width: 84, height: 84),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- horarios y ubicación

class _Horarios extends StatelessWidget {
  const _Horarios({required this.salon, required this.ahora, required this.onAbrir});

  final PublicSalonProfile salon;
  final DateTime ahora;
  final Future<void> Function(Uri uri) onAbrir;

  @override
  Widget build(BuildContext context) {
    final horas = [...salon.businessHours]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final mapa = enlaceDeMapa(salon);
    final direccion = salon.address?.trim() ?? '';
    final ciudad = salon.city?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (horas.isEmpty)
          const Text(
            'Este negocio todavía no publicó su horario de atención.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: _caja(),
            child: Column(
              children: [
                for (var i = 0; i < horas.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _FilaDeHorario(
                    dia: horas[i].dayName,
                    horario: horas[i].isOpen
                        ? '${horaLegible(horas[i].opensAt)} – ${horaLegible(horas[i].closesAt)}'
                        : 'Cerrado',
                    abierto: horas[i].isOpen,
                    hoy: horas[i].dayOfWeek == ahora.weekday,
                  ),
                ],
              ],
            ),
          ),
        if (direccion.isNotEmpty || ciudad.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _caja(),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandTintSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on_outlined, color: AppColors.brand, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        direccion.isNotEmpty ? direccion : ciudad,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (direccion.isNotEmpty && ciudad.isNotEmpty)
                        Text(
                          ciudad,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (mapa != null)
                  TextButton(
                    onPressed: () => onAbrir(mapa),
                    child: const Text('Cómo llegar'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FilaDeHorario extends StatelessWidget {
  const _FilaDeHorario({
    required this.dia,
    required this.horario,
    required this.abierto,
    required this.hoy,
  });

  final String dia;
  final String horario;
  final bool abierto;
  final bool hoy;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 14,
      fontWeight: hoy ? FontWeight.w800 : FontWeight.w400,
      color: hoy ? AppColors.brandDark : AppColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            Expanded(child: Text(hoy ? '$dia · hoy' : dia, style: estilo)),
            const SizedBox(width: 8),
            // La hora en un renglón: si no cabe (celular angosto, letra
            // grande), se achica un poco en vez de partirse o salirse. Lo
            // cazaron la prueba del celular y la fila de hoy, en negrilla.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.68),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  horario,
                  maxLines: 1,
                  style: abierto || hoy
                      ? estilo
                      : estilo.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// COMPUTADOR: LA COLUMNA DE LA RESERVA
// =============================================================================

class _Lateral extends StatelessWidget {
  const _Lateral({
    required this.salon,
    required this.estado,
    required this.ahora,
    required this.onBook,
  });

  final PublicSalonProfile salon;
  final ({bool abierto, String texto})? estado;
  final DateTime ahora;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final hoy = salon.businessHours
        .where((h) => h.dayOfWeek == ahora.weekday)
        .firstOrNull;
    final ubicacion = salon.locationLine;

    Widget tarjeta(String titulo, List<Widget> hijos) => Container(
      padding: const EdgeInsets.all(16),
      decoration: _caja(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: 12),
          ...hijos,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBook != null)
            tarjeta('Reserva en línea', [
              if (estado != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: ChipDeEstado(estado: estado!),
                ),
                const SizedBox(height: 12),
              ],
              _BotonAgendar(onBook: onBook!),
              const SizedBox(height: 10),
              // Sin "queda confirmada": solo es cierto en los salones sin caja
              // (D-312); con caja, la reserva queda pendiente.
              const Text(
                'Sin crear cuenta ni contraseña.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ]),
          if (hoy != null || ubicacion.isNotEmpty) ...[
            const SizedBox(height: 14),
            tarjeta('Hoy', [
              if (hoy != null)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${hoy.dayName}: '),
                      TextSpan(
                        text: hoy.isOpen
                            ? '${horaLegible(hoy.opensAt)} – ${horaLegible(hoy.closesAt)}'
                            : 'cerrado',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              if (ubicacion.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  ubicacion,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

/// La columna de la reserva acompaña al bajar: se queda arriba de la
/// pantalla mientras haya página al lado, y para al final de ella.
class _ColumnaQueAcompana extends StatefulWidget {
  const _ColumnaQueAcompana({
    required this.scroll,
    required this.claveDelContenido,
    required this.claveDePrincipal,
    required this.child,
  });

  final ScrollController? scroll;
  final GlobalKey claveDelContenido;
  final GlobalKey claveDePrincipal;
  final Widget child;

  @override
  State<_ColumnaQueAcompana> createState() => _ColumnaQueAcompanaState();
}

class _ColumnaQueAcompanaState extends State<_ColumnaQueAcompana> {
  final _ranura = GlobalKey();
  final _hijo = GlobalKey();

  double _desplazamiento() {
    final scroll = widget.scroll;
    if (scroll == null || !scroll.hasClients) return 0;
    final ranura = _ranura.currentContext?.findRenderObject() as RenderBox?;
    final hijo = _hijo.currentContext?.findRenderObject() as RenderBox?;
    final contenido =
        widget.claveDelContenido.currentContext?.findRenderObject() as RenderBox?;
    final principal =
        widget.claveDePrincipal.currentContext?.findRenderObject() as RenderBox?;
    if (ranura == null || hijo == null || contenido == null || principal == null) {
      return 0;
    }
    if (!ranura.hasSize || !hijo.hasSize || !principal.hasSize) return 0;
    // Dónde empieza la columna dentro de la página (no cambia al bajar).
    final arriba = ranura.localToGlobal(Offset.zero, ancestor: contenido).dy;
    const margen = 18.0;
    final dy = scroll.offset + margen - arriba;
    final maximo = principal.size.height - hijo.size.height;
    if (dy <= 0 || maximo <= 0) return 0;
    return dy > maximo ? maximo : dy;
  }

  @override
  Widget build(BuildContext context) {
    final hijo = KeyedSubtree(key: _hijo, child: widget.child);
    final scroll = widget.scroll;
    if (scroll == null) return hijo;
    return SizedBox(
      key: _ranura,
      child: AnimatedBuilder(
        animation: scroll,
        child: hijo,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _desplazamiento()),
          child: child,
        ),
      ),
    );
  }
}

// =============================================================================
// CELULAR: LA BARRA DE ABAJO
// =============================================================================

class BarraDeReserva extends StatelessWidget {
  const BarraDeReserva({super.key, required this.onBook, this.onWhatsApp});

  final VoidCallback onBook;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandSurface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            children: [
              Expanded(child: _BotonAgendar(onBook: onBook)),
              if (onWhatsApp != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  height: 52,
                  child: FilledButton(
                    onPressed: onWhatsApp,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.whatsapp,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      semanticLabel: 'WhatsApp',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PIE
// =============================================================================

class _Pie extends StatelessWidget {
  const _Pie({required this.onOpenPortal});

  final VoidCallback? onOpenPortal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 28),
      child: Column(
        children: [
          if (onOpenPortal != null)
            TextButton.icon(
              onPressed: onOpenPortal,
              // Ícono dibujado: el emoji 👤 salía azul, fuera de los colores
              // del salón (03-oct, D-316).
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Mis citas y fotos'),
            ),
          const SizedBox(height: 4),
          const Text(
            'Página hecha con Salón y Más',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
