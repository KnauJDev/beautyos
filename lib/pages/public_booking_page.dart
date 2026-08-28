import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

import '../models/available_appointment_slot.dart';
import '../models/public_booking_result.dart';
import '../models/public_branch_info.dart';
import '../models/public_service_option.dart';
import '../services/public_booking_service.dart';
import 'agenda_page.dart' show buildWhatsAppUri;

/// Pagina publica de reserva (web/QR), D-005. No requiere sesion: usa el
/// cliente Supabase con el rol "anon" y solo llama a las RPC public_* que
/// exigen sede y tenant activos. Se llega aqui via
/// "?reservar=`branch_id`" (ver main.dart) o empujada desde la pagina del
/// negocio (D-165), no por AuthGate.
class PublicBookingPage extends StatefulWidget {
  const PublicBookingPage({
    super.key,
    required this.branchId,
    this.preselectedServiceId,
  });

  final String branchId;

  /// Si viene de "Reservar" sobre un servicio puntual de la página del
  /// negocio (D-165), precarga ese servicio. El profesional queda en
  /// "Cualquiera disponible" (D-166) -- la persona lo puede acotar a mano.
  final String? preselectedServiceId;

  @override
  State<PublicBookingPage> createState() => _PublicBookingPageState();
}

/// Un horario disponible ya resuelto a un estilista concreto (D-166).
///
/// Con "Cualquiera disponible" se consultan TODOS los estilistas que
/// ofrecen el servicio y se combinan sus horarios en una sola lista; cada
/// hora recuerda de qué estilista salió, para poder reservar con el
/// correcto aunque en pantalla solo se vea la hora.
class _SlotOption {
  const _SlotOption({
    required this.slot,
    required this.stylistId,
    required this.stylistName,
  });

  final AvailableAppointmentSlot slot;
  final String stylistId;
  final String stylistName;
}

class _PublicBookingPageState extends State<PublicBookingPage> {
  final PublicBookingService bookingService = const PublicBookingService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final notesController = TextEditingController();

  bool isLoading = true;
  String? loadError;

  PublicBranchInfo? branchInfo;
  List<PublicServiceOption> services = [];

  String? selectedServiceId;

  /// `null` significa "Cualquiera disponible" (D-166).
  String? selectedStylistId;

  DateTime? selectedDate;
  List<_SlotOption> slotOptions = [];
  bool slotsLoading = false;
  _SlotOption? selectedSlotOption;

  bool isSubmitting = false;
  String? submitError;
  PublicBookingResult? bookingResult;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final info = await bookingService.getBranchInfo(widget.branchId);
      final serviceOptions = await bookingService.getBookableServices(
        widget.branchId,
      );

      // D-093d: el cliente que reserva ve los colores de SU salon, no los de
      // Salon y Mas. Se aplica antes del setState para que la pantalla se
      // pinte ya con el tema del negocio y no cambie de color a la vista.
      AppBrand.aplicar(info.themeKey, info.brandColor);

      if (!mounted) return;
      setState(() {
        branchInfo = info;
        services = serviceOptions;
        isLoading = false;
        if (widget.preselectedServiceId != null &&
            serviceOptions.any(
              (option) => option.serviceId == widget.preselectedServiceId,
            )) {
          selectedServiceId = widget.preselectedServiceId;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = _friendlyError(error);
        isLoading = false;
      });
    }
  }

  /// Un servicio distinto por `serviceId`, con el primer nombre/precio/
  /// duración que aparezca -- todos los estilistas que ofrecen el mismo
  /// servicio comparten esos datos (vienen de la misma fila de
  /// `branch_services`).
  List<PublicServiceOption> get _distinctServices {
    final seen = <String>{};
    final result = <PublicServiceOption>[];
    for (final option in services) {
      if (seen.add(option.serviceId)) result.add(option);
    }
    return result;
  }

  List<PublicServiceOption> get _stylistsForSelectedService {
    if (selectedServiceId == null) return const [];
    final seen = <String>{};
    final result = <PublicServiceOption>[];
    for (final option in services) {
      if (option.serviceId == selectedServiceId && seen.add(option.stylistId)) {
        result.add(option);
      }
    }
    return result;
  }

  PublicServiceOption? get _selectedServiceInfo {
    for (final option in services) {
      if (option.serviceId == selectedServiceId) return option;
    }
    return null;
  }

  void _selectService(String? serviceId) {
    setState(() {
      selectedServiceId = serviceId;
      selectedStylistId = null; // "Cualquiera disponible" por defecto.
      selectedDate = null;
      slotOptions = [];
      selectedSlotOption = null;
      bookingResult = null;
    });
  }

  void _selectStylist(String? stylistId) {
    setState(() {
      selectedStylistId = stylistId;
      selectedDate = null;
      slotOptions = [];
      selectedSlotOption = null;
    });
  }

  Future<void> _selectDate() async {
    if (selectedServiceId == null) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      selectedDate = picked;
      slotOptions = [];
      selectedSlotOption = null;
      slotsLoading = true;
    });

    try {
      // "Cualquiera disponible": se consulta a cada estilista que ofrece el
      // servicio y se combinan los horarios (D-166). Con un estilista
      // puntual, es la misma consulta de siempre con un solo destino.
      final targets = selectedStylistId == null
          ? _stylistsForSelectedService
          : _stylistsForSelectedService
              .where((option) => option.stylistId == selectedStylistId)
              .toList();

      final results = await Future.wait(
        targets.map(
          (target) => bookingService.getAvailableSlots(
            branchId: widget.branchId,
            serviceId: selectedServiceId!,
            stylistId: target.stylistId,
            date: picked,
          ),
        ),
      );

      final merged = <_SlotOption>[];
      final seenTimes = <DateTime>{};
      for (var i = 0; i < targets.length; i++) {
        for (final slot in results[i]) {
          // Si dos estilistas coinciden en la misma hora, se muestra una
          // sola vez -- son "Cualquiera disponible", no un listado por
          // persona.
          if (seenTimes.add(slot.startsAt)) {
            merged.add(
              _SlotOption(
                slot: slot,
                stylistId: targets[i].stylistId,
                stylistName: targets[i].stylistName,
              ),
            );
          }
        }
      }
      merged.sort((a, b) => a.slot.startsAt.compareTo(b.slot.startsAt));

      if (!mounted) return;
      setState(() {
        slotOptions = merged;
        slotsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        slotsLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar la disponibilidad: ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _submitBooking() async {
    final serviceId = selectedServiceId;
    final serviceInfo = _selectedServiceInfo;
    final slotOption = selectedSlotOption;

    if (serviceId == null || serviceInfo == null || slotOption == null) {
      setState(() {
        submitError = 'Selecciona un servicio, una fecha y un horario.';
      });
      return;
    }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      setState(() {
        submitError = 'Escribe tu nombre.';
      });
      return;
    }

    if (phone.isEmpty) {
      setState(() {
        submitError = 'Escribe tu numero de celular.';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      submitError = null;
    });

    try {
      final result = await bookingService.createBooking(
        branchId: widget.branchId,
        serviceId: serviceId,
        stylistId: slotOption.stylistId,
        scheduledAt: slotOption.slot.startsAt,
        clientName: name,
        clientPhone: phone,
        clientEmail: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        bookingResult = result;
        isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        submitError = _friendlyError(error);
        isSubmitting = false;
      });
    }
  }

  String get _selectedDateText {
    final date = selectedDate;
    if (date == null) return 'Elegir fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
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
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final result = bookingResult;
    if (result != null) {
      return _BookingSuccessCard(
        result: result,
        branchInfo: branchInfo!,
        clientName: nameController.text.trim(),
        durationMinutes: _selectedServiceInfo?.durationMinutes ?? 60,
      );
    }

    return _buildForm();
  }

  Widget _buildForm() {
    final info = branchInfo!;
    final locationLine = [info.branchName, info.address, info.city]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (info.coverPhotoUrl != null)
            Image.network(
              info.coverPhotoUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            if (info.logoUrl != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    info.logoUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              info.businessName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDeep,
              ),
            ),
            if (locationLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                locationLine,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '1. Elige un servicio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (services.isEmpty)
              const Text(
                'Este negocio aun no tiene servicios disponibles para '
                'reservar en linea.',
              )
            else
              DropdownButtonFormField<String>(
                initialValue: selectedServiceId,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Selecciona un servicio'),
                items: _distinctServices
                    .map(
                      (service) => DropdownMenuItem(
                        value: service.serviceId,
                        child: Text(
                          '${service.serviceName} · ${service.durationMinutes} min · '
                          '${service.formattedPrice}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _selectService,
              ),
            if (selectedServiceId != null) ...[
              const SizedBox(height: 20),
              const Text(
                '2. Elige profesional',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: selectedStylistId,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Cualquiera disponible'),
                  ),
                  ..._stylistsForSelectedService.map(
                    (stylist) => DropdownMenuItem<String?>(
                      value: stylist.stylistId,
                      child: Text(
                        stylist.stylistName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _selectStylist,
              ),
              const SizedBox(height: 20),
              const Text(
                'Elige una fecha',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_selectedDateText),
              ),
            ],
            if (selectedDate != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Elige un horario',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (slotsLoading)
                const Center(child: CircularProgressIndicator())
              else if (slotOptions.isEmpty)
                const Text(
                  'No hay horarios disponibles ese dia. Elige otra fecha.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slotOptions.map((option) {
                    final selected = selectedSlotOption?.slot.startsAt ==
                        option.slot.startsAt;
                    return ChoiceChip(
                      label: Text(
                        selectedStylistId == null
                            ? '${option.slot.label} · ${option.stylistName}'
                            : option.slot.label,
                      ),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => selectedSlotOption = option),
                    );
                  }).toList(),
                ),
            ],
            if (selectedSlotOption != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Tus datos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas para el negocio (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  submitError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: isSubmitting ? null : _submitBooking,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(isSubmitting ? 'Enviando...' : 'Solicitar cita'),
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

class _BookingSuccessCard extends StatelessWidget {
  const _BookingSuccessCard({
    required this.result,
    required this.branchInfo,
    required this.clientName,
    required this.durationMinutes,
  });

  final PublicBookingResult result;
  final PublicBranchInfo branchInfo;
  final String clientName;
  final int durationMinutes;

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String get _dateText {
    final date = result.scheduledAt;
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year} '
        '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  /// `YYYYMMDDTHHMMSSZ`, el formato que exige Google Calendar en su enlace
  /// de plantilla -- siempre en UTC, sin separadores.
  String _googleCalendarStamp(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${_twoDigits(utc.month)}${_twoDigits(utc.day)}T'
        '${_twoDigits(utc.hour)}${_twoDigits(utc.minute)}${_twoDigits(utc.second)}Z';
  }

  Future<void> _abrir(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  void _avisarPorWhatsApp(BuildContext context) {
    final whatsapp = branchInfo.whatsapp;
    if (whatsapp == null || whatsapp.trim().isEmpty) return;

    final mensaje =
        'Hola, soy $clientName. Acabo de solicitar una cita para '
        '${result.serviceName} el $_dateText. ¿Me confirman?';

    _abrir(context, buildWhatsAppUri(whatsapp, text: mensaje));
  }

  void _guardarEnGoogleCalendar(BuildContext context) {
    final start = result.scheduledAt;
    final end = start.add(Duration(minutes: durationMinutes));
    final location = [branchInfo.address, branchInfo.city]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': '${result.serviceName} en ${branchInfo.businessName}',
      'dates': '${_googleCalendarStamp(start)}/${_googleCalendarStamp(end)}',
      'details': 'Cita con ${result.stylistName} en ${branchInfo.businessName}.',
      if (location.isNotEmpty) 'location': location,
    });

    _abrir(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 56,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              'Solicitud enviada a ${branchInfo.businessName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.serviceName} con ${result.stylistName}\n$_dateText',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu reserva quedo pendiente de confirmacion. El negocio te '
              'contactara para confirmarla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (branchInfo.whatsapp != null &&
                branchInfo.whatsapp!.trim().isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _avisarPorWhatsApp(context),
                  icon: const Text('📲', style: TextStyle(fontSize: 16)),
                  label: const Text('Avisar al salón por WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.whatsapp,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _guardarEnGoogleCalendar(context),
                icon: const Text('📅', style: TextStyle(fontSize: 16)),
                label: const Text('Guardar en Google Calendar'),
              ),
            ),
            if (canPop) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Text('🏠', style: TextStyle(fontSize: 16)),
                  label: const Text('Volver a la página del salón'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }
  return error.toString();
}
