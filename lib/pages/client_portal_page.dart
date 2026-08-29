import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/client_portal_data.dart';
import '../services/client_portal_service.dart';
import '../widgets/photo_grid_viewer.dart';
import 'agenda_page.dart' show buildWhatsAppUri;
import 'public_review_page.dart';

/// Portal seguro de la clienta: "Mis citas y fotos" (D-167). Sin sesión de
/// Salón y Más -- entra con su celular y el PIN de 4 dígitos que le asignó
/// el salón (nunca se autoasigna uno, ver la decisión de seguridad en la
/// migración de D-167).
class ClientPortalPage extends StatefulWidget {
  const ClientPortalPage({
    super.key,
    required this.tenantId,
    required this.businessName,
    this.businessWhatsapp,
  });

  final String tenantId;
  final String businessName;
  final String? businessWhatsapp;

  @override
  State<ClientPortalPage> createState() => _ClientPortalPageState();
}

class _ClientPortalPageState extends State<ClientPortalPage> {
  final _portalService = const ClientPortalService();

  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _rememberDevice = true;

  bool _isCheckingSavedSession = true;
  bool _isSubmitting = false;
  String? _loginError;

  String? _phone;
  String? _token;
  ClientPortalData? _portalData;
  bool _isRefreshing = false;

  String get _prefsPhoneKey => 'portal_phone_${widget.tenantId}';
  String get _prefsTokenKey => 'portal_token_${widget.tenantId}';

  @override
  void initState() {
    super.initState();
    _tryRestoreSavedSession();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryRestoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString(_prefsPhoneKey);
      final savedToken = prefs.getString(_prefsTokenKey);

      if (savedPhone == null || savedToken == null) {
        if (!mounted) return;
        setState(() => _isCheckingSavedSession = false);
        return;
      }

      final data = await _portalService.getPortalData(
        tenantId: widget.tenantId,
        phone: savedPhone,
        portalToken: savedToken,
      );

      if (!mounted) return;
      setState(() {
        _phone = savedPhone;
        _token = savedToken;
        _portalData = data;
        _isCheckingSavedSession = false;
      });
    } catch (_) {
      // El token guardado ya no sirve (expiró o se restableció el PIN): se
      // limpia y se pide ingresar de nuevo, sin mostrar el error tecnico.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsPhoneKey);
      await prefs.remove(_prefsTokenKey);
      if (!mounted) return;
      setState(() => _isCheckingSavedSession = false);
    }
  }

  Future<void> _submitLogin() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty || pin.length != 4) {
      setState(() {
        _loginError = 'Escribe tu celular y un PIN de 4 dígitos.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loginError = null;
    });

    try {
      final token = await _portalService.authenticate(
        tenantId: widget.tenantId,
        phone: phone,
        pin: pin,
      );

      final data = await _portalService.getPortalData(
        tenantId: widget.tenantId,
        phone: phone,
        portalToken: token,
      );

      if (_rememberDevice) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsPhoneKey, phone);
        await prefs.setString(_prefsTokenKey, token);
      }

      if (!mounted) return;
      setState(() {
        _phone = phone;
        _token = token;
        _portalData = data;
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      setState(() {
        _loginError = message;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _refreshPortalData() async {
    final phone = _phone;
    final token = _token;
    if (phone == null || token == null) return;

    setState(() => _isRefreshing = true);
    try {
      final data = await _portalService.getPortalData(
        tenantId: widget.tenantId,
        phone: phone,
        portalToken: token,
      );
      if (!mounted) return;
      setState(() {
        _portalData = data;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPhoneKey);
    await prefs.remove(_prefsTokenKey);
    if (!mounted) return;
    setState(() {
      _phone = null;
      _token = null;
      _portalData = null;
      _phoneController.clear();
      _pinController.clear();
    });
  }

  void _pedirPinPorWhatsApp() {
    final whatsapp = widget.businessWhatsapp;
    if (whatsapp == null || whatsapp.trim().isEmpty) return;

    launchUrl(
      buildWhatsAppUri(
        whatsapp,
        text: 'Hola, olvidé mi PIN del portal de clientas. ¿Me pueden '
            'asignar uno nuevo?',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        title: Text(widget.businessName),
        backgroundColor: AppColors.brandSurface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_portalData != null) ...[
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _isRefreshing ? null : _refreshPortalData,
              icon: const Icon(Icons.refresh_outlined),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
    if (_isCheckingSavedSession) {
      return const Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final data = _portalData;
    if (data == null) {
      return _buildLoginForm();
    }

    return _buildPortalView(data);
  }

  Widget _buildLoginForm() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 48,
              color: AppColors.brand,
            ),
            const SizedBox(height: 12),
            const Text(
              'Mis citas y fotos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ingresa con tu celular y el PIN de 4 dígitos que te dio el '
              'salón.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN (4 dígitos)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            CheckboxListTile(
              value: _rememberDevice,
              onChanged: (value) =>
                  setState(() => _rememberDevice = value ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text(
                'Recordarme en este dispositivo',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (_loginError != null) ...[
              const SizedBox(height: 8),
              Text(
                _loginError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitLogin,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ingresar'),
              ),
            ),
            if (widget.businessWhatsapp != null &&
                widget.businessWhatsapp!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _pedirPinPorWhatsApp,
                child: const Text(
                  '¿Olvidaste tu PIN? Escríbenos por WhatsApp',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortalView(ClientPortalData data) {
    final pendientesPorCalificar = data.pastAppointments
        .where((a) => !a.alreadyReviewed)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hola, ${data.clientName.split(' ').first} 👋',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _PortalSection(
          title: 'Próximas citas',
          icon: Icons.event_available_outlined,
          isRefreshing: _isRefreshing,
          child: data.upcomingAppointments.isEmpty
              ? const Text(
                  'No tienes citas próximas agendadas.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final cita in data.upcomingAppointments) ...[
                      _UpcomingAppointmentTile(appointment: cita),
                      if (cita != data.upcomingAppointments.last)
                        const Divider(height: 20),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (pendientesPorCalificar.isNotEmpty) ...[
          _PortalSection(
            title: 'Calificar servicios pendientes',
            icon: Icons.star_outline,
            child: Column(
              children: [
                for (final cita in pendientesPorCalificar) ...[
                  _PastAppointmentTile(appointment: cita),
                  if (cita != pendientesPorCalificar.last)
                    const Divider(height: 20),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _PortalSection(
          title: 'Mis fotos de trabajos',
          icon: Icons.photo_library_outlined,
          child: data.photos.isEmpty
              ? const Text(
                  'Todavía no tienes fotos publicadas aquí.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                )
              : PhotoGridViewer(
                  photos: data.photos
                      .map((p) => (url: p.photoUrl, caption: p.caption))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _PortalSection extends StatelessWidget {
  const _PortalSection({
    required this.title,
    required this.icon,
    required this.child,
    this.isRefreshing = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.brand, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDeep,
                  ),
                ),
                if (isRefreshing) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointmentTile extends StatelessWidget {
  const _UpcomingAppointmentTile({required this.appointment});

  final ClientPortalUpcomingAppointment appointment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (appointment.ticketCode != null) ...[
              Text(
                appointment.ticketCode!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              appointment.scheduledAtText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          appointment.serviceNames,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        Text(
          'Con ${appointment.stylistNames}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PastAppointmentTile extends StatelessWidget {
  const _PastAppointmentTile({required this.appointment});

  final ClientPortalPastAppointment appointment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.scheduledAtText,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                appointment.serviceNames,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (!appointment.alreadyReviewed)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PublicReviewPage(ticketId: appointment.ticketId),
                ),
              );
            },
            icon: const Icon(Icons.star_outline, size: 16),
            label: const Text('Calificar'),
          ),
      ],
    );
  }
}
