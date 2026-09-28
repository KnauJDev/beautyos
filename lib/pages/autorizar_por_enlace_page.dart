import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_consent.dart';
import '../services/client_consent_service.dart';
import '../services/public_salon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/autorizaciones_de_la_clienta.dart';
import 'public_salon_page.dart';

/// Paso 9.48, Bloque 3 (D-287): la página del enlace directo,
/// `salonymas.com/?autorizar=<token>`.
///
/// La clienta la abre desde el WhatsApp que le manda el salón, sin sesión y
/// sin PIN: el enlace es suyo, único y permanente (D-281). Aquí decide lo
/// mismo que en su portal, con la misma pieza ([AutorizacionesDeLaClienta]).
///
/// Decisiones del propietario (28-sep):
/// - arriba, el nombre del salón y **sus colores**;
/// - un enlace inválido dice qué hacer, **sin botón de reintentar** (con un
///   enlace malo reintentar no sirve, y no se sabe de qué salón es);
/// - al final, lo que ya respondió y un botón a la página del salón.
class AutorizarPorEnlacePage extends StatefulWidget {
  const AutorizarPorEnlacePage({
    super.key,
    required this.token,
    this.service = const ClientConsentService(),
    this.salonService = const PublicSalonService(),
  });

  final String token;
  final ClientConsentService service;
  final PublicSalonService salonService;

  static const enlaceInvalido =
      'Este enlace no es válido. Pídele al salón que te envíe uno nuevo.';
  static const sinConexion =
      'No se pudo abrir. Revisa tu conexión e intenta otra vez.';

  static String botonSalon(String salon) => 'Ver la página de $salon';

  @override
  State<AutorizarPorEnlacePage> createState() => _AutorizarPorEnlacePageState();
}

class _AutorizarPorEnlacePageState extends State<AutorizarPorEnlacePage> {
  bool _cargando = true;
  bool _invalido = false;
  String? _error;
  ClientConsentOverview? _datos;

  ClientConsentCredential get _credencial =>
      ClientConsentCredential.enlace(widget.token);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.service.getOverview(_credencial);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
      _pintarColoresDelSalon(datos.businessSlug);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        // La base responde "Este enlace no es válido." a un token que no es
        // de ninguna clienta activa (beautyos_resolve_consent_client).
        _invalido = error is PostgrestException &&
            error.message.contains('enlace no es válido');
        _error = _invalido ? null : AutorizarPorEnlacePage.sinConexion;
      });
    }
  }

  /// Los colores del salón, con la misma función que su página pública
  /// (D-093d). Si falla, se queda con los de Salón y Más: no es motivo para
  /// no dejarla decidir.
  Future<void> _pintarColoresDelSalon(String? slug) async {
    if (slug == null) return;
    try {
      final perfil = await widget.salonService.getSalonBySlug(slug);
      if (perfil != null) AppBrand.aplicar(perfil.themeKey, perfil.brandColor);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final salon = datos?.businessName ?? 'tu salón';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(datos?.businessName ?? 'Salón y Más'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_invalido)
                  _Aviso(texto: AutorizarPorEnlacePage.enlaceInvalido)
                else if (datos == null)
                  _Aviso(
                    texto: _error ?? AutorizarPorEnlacePage.sinConexion,
                    alReintentar: _cargar,
                  )
                else ...[
                  Text(
                    'Hola, ${datos.clientName.split(' ').first} 👋',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aquí decides qué puede mostrar $salon de tus fotos y de '
                    'tus reseñas. Puedes cambiarlo cuando quieras con este '
                    'mismo enlace.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AutorizacionesDeLaClienta(
                    credencial: _credencial,
                    nombreSalon: salon,
                    whatsappSalon: datos.businessWhatsapp,
                    service: widget.service,
                  ),
                  if (datos.businessSlug != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(AutorizarPorEnlacePage.botonSalon(salon)),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PublicSalonPage(slug: datos.businessSlug!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.alReintentar});

  final String texto;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.link_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
            if (alReintentar != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: alReintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
