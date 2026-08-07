import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/available_appointment_slot.dart';
import '../models/public_booking_result.dart';
import '../models/public_branch_info.dart';
import '../models/public_service_option.dart';
import '../services/public_booking_service.dart';

/// Pagina publica de reserva (web/QR), D-005. No requiere sesion: usa el
/// cliente Supabase con el rol "anon" y solo llama a las RPC public_* que
/// exigen sede y tenant activos. Se llega aqui via
/// "?reservar=`branch_id`" (ver main.dart), no por AuthGate.
class PublicBookingPage extends StatefulWidget {
  const PublicBookingPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<PublicBookingPage> createState() => _PublicBookingPageState();
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

  PublicServiceOption? selectedService;
  DateTime? selectedDate;
  List<AvailableAppointmentSlot> slots = [];
  bool slotsLoading = false;
  AvailableAppointmentSlot? selectedSlot;

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

      if (!mounted) return;
      setState(() {
        branchInfo = info;
        services = serviceOptions;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = _friendlyError(error);
        isLoading = false;
      });
    }
  }

  void _selectService(PublicServiceOption option) {
    setState(() {
      selectedService = option;
      selectedDate = null;
      slots = [];
      selectedSlot = null;
      bookingResult = null;
    });
  }

  Future<void> _selectDate() async {
    final service = selectedService;
    if (service == null) return;

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
      slots = [];
      selectedSlot = null;
      slotsLoading = true;
    });

    try {
      final loadedSlots = await bookingService.getAvailableSlots(
        branchId: widget.branchId,
        serviceId: service.serviceId,
        stylistId: service.stylistId,
        date: picked,
      );

      if (!mounted) return;
      setState(() {
        slots = loadedSlots;
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
    final service = selectedService;
    final slot = selectedSlot;

    if (service == null || slot == null) {
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
        serviceId: service.serviceId,
        stylistId: service.stylistId,
        scheduledAt: slot.startsAt,
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
        businessName: branchInfo?.businessName ?? 'el negocio',
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
              style: const TextStyle(
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
            _buildTeamSection(),
            const SizedBox(height: 24),
            const Text(
              'Elige un servicio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (services.isEmpty)
              const Text(
                'Este negocio aun no tiene servicios disponibles para '
                'reservar en linea.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: services.map((service) {
                  final selected =
                      selectedService?.serviceId == service.serviceId &&
                      selectedService?.stylistId == service.stylistId;
                  return ChoiceChip(
                    label: Text(
                      '${service.label} · ${service.formattedPrice}',
                    ),
                    selected: selected,
                    onSelected: (_) => _selectService(service),
                  );
                }).toList(),
              ),
            if (selectedService != null) ...[
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
              else if (slots.isEmpty)
                const Text(
                  'No hay horarios disponibles ese dia. Elige otra fecha.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((slot) {
                    final selected = selectedSlot?.startsAt == slot.startsAt;
                    return ChoiceChip(
                      label: Text(slot.label),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => selectedSlot = slot),
                    );
                  }).toList(),
                ),
            ],
            if (selectedSlot != null) ...[
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
                  label: Text(isSubmitting ? 'Enviando...' : 'Confirmar reserva'),
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

  Widget _buildTeamSection() {
    final seen = <String>{};
    final team = <PublicServiceOption>[];
    for (final service in services) {
      final hasProfile =
          (service.stylistPhotoUrl?.trim().isNotEmpty ?? false) ||
          (service.stylistBio?.trim().isNotEmpty ?? false);
      if (hasProfile && seen.add(service.stylistId)) {
        team.add(service);
      }
    }

    if (team.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conoce a nuestro equipo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: team.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final stylist = team[index];
                return SizedBox(
                  width: 92,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: stylist.stylistPhotoUrl == null
                            ? Container(
                                width: 60,
                                height: 60,
                                color: AppColors.brandTint,
                                child: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.brand,
                                ),
                              )
                            : Image.network(
                                stylist.stylistPhotoUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 60,
                                      height: 60,
                                      color: AppColors.brandTint,
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: AppColors.brand,
                                      ),
                                    ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stylist.stylistName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (stylist.stylistBio != null &&
                          stylist.stylistBio!.trim().isNotEmpty)
                        Text(
                          stylist.stylistBio!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                );
              },
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
    required this.businessName,
  });

  final PublicBookingResult result;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final date = result.scheduledAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

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
              'Solicitud enviada a $businessName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.serviceName} con ${result.stylistName}\n$dateText',
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
