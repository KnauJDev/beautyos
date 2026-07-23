import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_policy.dart';
import '../models/business_hour.dart';
import '../models/business_settings.dart';
import '../models/commission_policy.dart';
import '../services/appointment_policy_service.dart';
import '../services/business_hours_service.dart';
import '../services/business_settings_service.dart';
import '../services/commission_policy_service.dart';
import '../widgets/app_widgets.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final BusinessSettingsService businessSettingsService =
      const BusinessSettingsService();

  late final BusinessHoursService businessHoursService;
  late final AppointmentPolicyService appointmentPolicyService;
  late final CommissionPolicyService commissionPolicyService;

  late final Future<BusinessSettings> businessSettingsFuture;
  late Future<List<BusinessHour>> businessHoursFuture;
  late Future<AppointmentPolicy> appointmentPolicyFuture;
  late Future<CommissionPolicy> commissionPolicyFuture;

  @override
  void initState() {
    super.initState();
    businessHoursService = BusinessHoursService(branchId: widget.branchId);
    appointmentPolicyService = AppointmentPolicyService(
      branchId: widget.branchId,
    );
    commissionPolicyService = CommissionPolicyService(
      branchId: widget.branchId,
    );
    businessSettingsFuture = businessSettingsService.getBusinessSettings();
    businessHoursFuture = businessHoursService.getBusinessHours();
    appointmentPolicyFuture = appointmentPolicyService.getAppointmentPolicy();
    commissionPolicyFuture = commissionPolicyService.getCommissionPolicy();
  }

  void _reloadHours() {
    setState(() {
      businessHoursFuture = businessHoursService.getBusinessHours();
    });
  }

  void _reloadAppointmentPolicy() {
    setState(() {
      appointmentPolicyFuture = appointmentPolicyService
          .getAppointmentPolicy();
    });
  }

  void _reloadCommissionPolicy() {
    setState(() {
      commissionPolicyFuture = commissionPolicyService.getCommissionPolicy();
    });
  }

  Future<void> _openEditHoursDialog(List<BusinessHour> hours) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditBusinessHoursDialog(
        hours: hours,
        businessHoursService: businessHoursService,
      ),
    );

    if (saved == true) _reloadHours();
  }

  Future<void> _openEditAppointmentPolicyDialog(
    AppointmentPolicy policy,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditAppointmentPolicyDialog(
        policy: policy,
        appointmentPolicyService: appointmentPolicyService,
      ),
    );

    if (saved == true) _reloadAppointmentPolicy();
  }

  Future<void> _openEditCommissionPolicyDialog(CommissionPolicy policy) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditCommissionPolicyDialog(
        policy: policy,
        commissionPolicyService: commissionPolicyService,
      ),
    );

    if (saved == true) _reloadCommissionPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Configuración',
      subtitle: 'Reglas generales del centro de estética.',
      children: [
        const InfoPanel(
          icon: Icons.settings_outlined,
          title: 'Módulo base de Configuración',
          description:
              'Aquí configuraremos datos del negocio, horarios, políticas de agenda, anticipos, comisiones y reglas futuras de WhatsApp e IA.',
        ),
        const SizedBox(height: 16),
        const SectionTitle('Datos del negocio'),
        FutureBuilder<BusinessSettings>(
          future: businessSettingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los datos',
                description:
                    'Revisa la conexión con Supabase o la función get_business_settings.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin datos del negocio',
                description:
                    'Todavía no hay información activa para mostrar en Configuración.',
              );
            }

            return BusinessSettingsCard(settings: snapshot.data!);
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Reserva pública'),
        PublicBookingLinkCard(branchId: widget.branchId),
        const SizedBox(height: 16),
        const SectionTitle('Horarios de atención'),
        FutureBuilder<List<BusinessHour>>(
          future: businessHoursFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los horarios',
                description:
                    'Revisa la conexión con Supabase o el acceso a la sede seleccionada.',
              );
            }

            final hours = snapshot.data ?? [];

            if (hours.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin horarios registrados',
                description:
                    'Todavía no hay horarios activos para mostrar en Configuración.',
              );
            }

            return BusinessHoursCard(
              hours: hours,
              onEdit: () => _openEditHoursDialog(hours),
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Políticas de agenda'),
        FutureBuilder<AppointmentPolicy>(
          future: appointmentPolicyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar las políticas',
                description:
                    'Revisa la conexión con Supabase o el acceso a la sede seleccionada.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin políticas registradas',
                description:
                    'Todavía no hay políticas activas para mostrar en Configuración.',
              );
            }

            return AppointmentPolicyCard(
              policy: snapshot.data!,
              onEdit: () => _openEditAppointmentPolicyDialog(snapshot.data!),
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Comisiones'),
        FutureBuilder<CommissionPolicy>(
          future: commissionPolicyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar las comisiones',
                description:
                    'Revisa la conexión con Supabase o la función get_commission_policy.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin comisiones registradas',
                description:
                    'Todavía no hay reglas activas de comisión para mostrar en Configuración.',
              );
            }

            return CommissionPolicyCard(
              policy: snapshot.data!,
              onEdit: () => _openEditCommissionPolicyDialog(snapshot.data!),
            );
          },
        ),
      ],
    );
  }
}

class BusinessSettingsCard extends StatelessWidget {
  final BusinessSettings settings;

  const BusinessSettingsCard({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SettingsLine(
              label: 'Tipo de negocio',
              value: settings.businessType,
            ),
            _SettingsLine(label: 'Correo', value: settings.contactEmail),
            _SettingsLine(label: 'Teléfono', value: settings.contactPhone),
            _SettingsLine(label: 'WhatsApp', value: settings.whatsapp),
            _SettingsLine(label: 'Instagram', value: settings.instagram),
            _SettingsLine(label: 'Facebook', value: settings.facebook),
          ],
        ),
      ),
    );
  }
}

class PublicBookingLinkCard extends StatelessWidget {
  const PublicBookingLinkCard({super.key, required this.branchId});

  final String branchId;

  String get _link => '${Uri.base.origin}/?reservar=$branchId';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte este enlace por WhatsApp, redes o un código QR '
              'generado a partir de él. Tus clientes reservan sin crear '
              'cuenta ni contraseña; la reserva queda pendiente de tu '
              'confirmación.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _link,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar enlace',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => _copyLink(context),
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

class BusinessHoursCard extends StatelessWidget {
  final List<BusinessHour> hours;
  final VoidCallback onEdit;

  const BusinessHoursCard({super.key, required this.hours, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final hour in hours) _BusinessHourRow(hour: hour),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar horario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentPolicyCard extends StatelessWidget {
  final AppointmentPolicy policy;
  final VoidCallback onEdit;

  const AppointmentPolicyCard({
    super.key,
    required this.policy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsLine(label: 'Anticipo', value: policy.depositText),
            _SettingsLine(label: 'Cancelación', value: policy.cancellationText),
            _SettingsLine(
              label: 'Reagendamiento',
              value: policy.rescheduleText,
            ),
            _SettingsLine(
              label: 'Confirmación',
              value: policy.manualConfirmationText,
            ),
            _SettingsLine(
              label: 'Cliente',
              value: policy.customerRescheduleText,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar política'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommissionPolicyCard extends StatelessWidget {
  final CommissionPolicy policy;
  final VoidCallback onEdit;

  const CommissionPolicyCard({
    super.key,
    required this.policy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsLine(label: 'Tipo', value: policy.commissionTypeText),
            _SettingsLine(label: 'Comisión', value: policy.commissionValueText),
            _SettingsLine(label: 'Descuentos', value: policy.discountText),
            _SettingsLine(label: 'Notas', value: policy.notes),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar comisión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditBusinessHoursDialog extends StatefulWidget {
  const _EditBusinessHoursDialog({
    required this.hours,
    required this.businessHoursService,
  });

  final List<BusinessHour> hours;
  final BusinessHoursService businessHoursService;

  @override
  State<_EditBusinessHoursDialog> createState() =>
      _EditBusinessHoursDialogState();
}

class _EditBusinessHoursDialogState extends State<_EditBusinessHoursDialog> {
  late final List<_EditableDay> days = widget.hours
      .map((hour) => _EditableDay.fromBusinessHour(hour))
      .toList()
    ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

  bool isSaving = false;
  String? errorMessage;

  Future<void> _pickTime(_EditableDay day, {required bool isOpening}) async {
    final initial = isOpening ? day.opensAt : day.closesAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked == null) return;

    setState(() {
      if (isOpening) {
        day.opensAt = picked;
      } else {
        day.closesAt = picked;
      }
    });
  }

  Future<void> save() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final updated = days
          .map(
            (day) => BusinessHour(
              id: day.id,
              dayOfWeek: day.dayOfWeek,
              opensAt: day.isOpen ? _formatTime(day.opensAt) : null,
              closesAt: day.isOpen ? _formatTime(day.closesAt) : null,
              isOpen: day.isOpen,
            ),
          )
          .toList();

      await widget.businessHoursService.updateBusinessHours(updated);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar horario de atención'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in days) _DayRow(day: day, onPickTime: _pickTime),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onPickTime});

  final _EditableDay day;
  final void Function(_EditableDay day, {required bool isOpening}) onPickTime;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 90, child: Text(day.dayName)),
              Switch(
                value: day.isOpen,
                onChanged: (value) => setLocalState(() => day.isOpen = value),
              ),
              if (day.isOpen) ...[
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      onPickTime(day, isOpening: true);
                    },
                    child: Text(day.opensAt?.format(context) ?? 'Apertura'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      onPickTime(day, isOpening: false);
                    },
                    child: Text(day.closesAt?.format(context) ?? 'Cierre'),
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'Cerrado',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EditableDay {
  _EditableDay({
    required this.id,
    required this.dayOfWeek,
    required this.dayName,
    required this.isOpen,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final int dayOfWeek;
  final String dayName;
  bool isOpen;
  TimeOfDay? opensAt;
  TimeOfDay? closesAt;

  factory _EditableDay.fromBusinessHour(BusinessHour hour) {
    return _EditableDay(
      id: hour.id,
      dayOfWeek: hour.dayOfWeek,
      dayName: hour.dayName,
      isOpen: hour.isOpen,
      opensAt: _parseTime(hour.opensAt),
      closesAt: _parseTime(hour.closesAt),
    );
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.length < 5) return null;
    final hour = int.tryParse(value.substring(0, 2));
    final minute = int.tryParse(value.substring(3, 5));
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _EditAppointmentPolicyDialog extends StatefulWidget {
  const _EditAppointmentPolicyDialog({
    required this.policy,
    required this.appointmentPolicyService,
  });

  final AppointmentPolicy policy;
  final AppointmentPolicyService appointmentPolicyService;

  @override
  State<_EditAppointmentPolicyDialog> createState() =>
      _EditAppointmentPolicyDialogState();
}

class _EditAppointmentPolicyDialogState
    extends State<_EditAppointmentPolicyDialog> {
  late bool requiresDeposit = widget.policy.requiresDeposit;
  late final depositController = TextEditingController(
    text: widget.policy.depositPercentage.toStringAsFixed(0),
  );
  late final cancellationController = TextEditingController(
    text: widget.policy.cancellationHours.toString(),
  );
  late final rescheduleController = TextEditingController(
    text: widget.policy.rescheduleHours.toString(),
  );
  late bool manualConfirmationRequired =
      widget.policy.manualConfirmationRequired;
  late bool customerRescheduleAllowed =
      widget.policy.customerRescheduleAllowed;
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    depositController.dispose();
    cancellationController.dispose();
    rescheduleController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final deposit = num.tryParse(depositController.text.trim());
    final cancellation = int.tryParse(cancellationController.text.trim());
    final reschedule = int.tryParse(rescheduleController.text.trim());

    if (deposit == null || deposit < 0 || deposit > 100) {
      setState(() => errorMessage = 'El anticipo debe ser entre 0 y 100.');
      return;
    }
    if (cancellation == null || cancellation < 0) {
      setState(() => errorMessage = 'Las horas de cancelación no son válidas.');
      return;
    }
    if (reschedule == null || reschedule < 0) {
      setState(
        () => errorMessage = 'Las horas de reagendamiento no son válidas.',
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.appointmentPolicyService.updateAppointmentPolicy(
        requiresDeposit: requiresDeposit,
        depositPercentage: deposit,
        cancellationHours: cancellation,
        rescheduleHours: reschedule,
        manualConfirmationRequired: manualConfirmationRequired,
        customerRescheduleAllowed: customerRescheduleAllowed,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar política de citas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere anticipo'),
              value: requiresDeposit,
              onChanged: (value) => setState(() => requiresDeposit = value),
            ),
            if (requiresDeposit)
              TextField(
                controller: depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Anticipo (%)'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: cancellationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Horas mínimas para cancelar',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rescheduleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Horas mínimas para reagendar',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere confirmación manual'),
              value: manualConfirmationRequired,
              onChanged: (value) =>
                  setState(() => manualConfirmationRequired = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('El cliente puede reagendar'),
              value: customerRescheduleAllowed,
              onChanged: (value) =>
                  setState(() => customerRescheduleAllowed = value),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _EditCommissionPolicyDialog extends StatefulWidget {
  const _EditCommissionPolicyDialog({
    required this.policy,
    required this.commissionPolicyService,
  });

  final CommissionPolicy policy;
  final CommissionPolicyService commissionPolicyService;

  @override
  State<_EditCommissionPolicyDialog> createState() =>
      _EditCommissionPolicyDialogState();
}

class _EditCommissionPolicyDialogState
    extends State<_EditCommissionPolicyDialog> {
  late String commissionType = widget.policy.commissionType;
  late final percentageController = TextEditingController(
    text: widget.policy.commissionPercentage.toStringAsFixed(0),
  );
  late final fixedController = TextEditingController(
    text: widget.policy.fixedCommissionAmount.toStringAsFixed(0),
  );
  late bool appliesAfterDiscount = widget.policy.appliesAfterDiscount;
  late final notesController = TextEditingController(
    text: widget.policy.notes == 'Sin notas' ? '' : widget.policy.notes,
  );
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    percentageController.dispose();
    fixedController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final percentage = num.tryParse(percentageController.text.trim());
    final fixed = num.tryParse(fixedController.text.trim());

    if (percentage == null || percentage < 0 || percentage > 100) {
      setState(() => errorMessage = 'El porcentaje debe ser entre 0 y 100.');
      return;
    }
    if (fixed == null || fixed < 0) {
      setState(() => errorMessage = 'El valor fijo no es válido.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.commissionPolicyService.updateCommissionPolicy(
        commissionType: commissionType,
        commissionPercentage: percentage,
        fixedCommissionAmount: fixed,
        appliesAfterDiscount: appliesAfterDiscount,
        notes: notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar política de comisión'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: commissionType,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Porcentaje')),
                DropdownMenuItem(value: 'fixed', child: Text('Valor fijo')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => commissionType = value);
              },
            ),
            const SizedBox(height: 12),
            if (commissionType == 'percentage')
              TextField(
                controller: percentageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Porcentaje de comisión (%)',
                ),
              )
            else
              TextField(
                controller: fixedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor fijo por servicio (COP)',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Calcular después de descuentos'),
              value: appliesAfterDiscount,
              onChanged: (value) =>
                  setState(() => appliesAfterDiscount = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 2,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _BusinessHourRow extends StatelessWidget {
  final BusinessHour hour;

  const _BusinessHourRow({required this.hour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              hour.dayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(hour.scheduleText)),
        ],
      ),
    );
  }
}

class _SettingsLine extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
