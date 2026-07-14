import 'package:flutter/material.dart';

import '../models/client_summary.dart';
import '../models/ticket_service_option.dart';
import '../models/ticket_summary.dart';
import '../services/clients_service.dart';
import '../services/tickets_service.dart';
import '../widgets/app_widgets.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final ClientsService clientsService = const ClientsService();
  final TicketsService ticketsService = const TicketsService();
  late Future<List<TicketSummary>> ticketsFuture;

  @override
  void initState() {
    super.initState();
    ticketsFuture = ticketsService.getTicketsSummary();
  }

  void _refreshTickets() {
    setState(() {
      ticketsFuture = ticketsService.getTicketsSummary();
    });
  }

  Future<void> _openCreateTicketDialog() async {
    try {
      final clients = await clientsService.getClientsSummary();

      if (!mounted) {
        return;
      }

      if (clients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primero debes crear al menos un cliente.'),
          ),
        );
        return;
      }

      final formData = await showDialog<_TicketFormData>(
        context: context,
        builder: (context) => _CreateTicketDialog(clients: clients),
      );

      if (formData == null) {
        return;
      }

      final createdTicket = await ticketsService.createTicket(
        clientId: formData.clientId,
        scheduledAt: formData.scheduledAt,
        channel: formData.channel,
        notes: formData.notes,
      );

      if (!mounted) {
        return;
      }

      if (createdTicket == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear el ticket. Verifica tus permisos.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket creado correctamente.')),
      );
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creando ticket: $error')));
    }
  }

  Future<void> _openAddTicketServiceDialog(TicketSummary ticket) async {
    try {
      final options = await ticketsService.getTicketServiceOptions();

      if (!mounted) {
        return;
      }

      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay servicios activos disponibles.'),
          ),
        );
        return;
      }

      final formData = await showDialog<_TicketServiceFormData>(
        context: context,
        builder: (context) => _AddTicketServiceDialog(options: options),
      );

      if (formData == null) {
        return;
      }

      final added = await ticketsService.addTicketService(
        ticketId: ticket.id,
        serviceId: formData.serviceId,
        stylistId: formData.stylistId,
      );

      if (!mounted) {
        return;
      }

      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo agregar el servicio al ticket.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio agregado correctamente.')),
      );
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error agregando servicio: $error')),
      );
    }
  }

  Future<void> _openRescheduleTicketDialog(TicketSummary ticket) async {
    final formData = await showDialog<_RescheduleTicketFormData>(
      context: context,
      builder: (context) => _RescheduleTicketDialog(ticket: ticket),
    );

    if (formData == null) {
      return;
    }

    try {
      final rescheduled = await ticketsService.rescheduleTicket(
        ticketId: ticket.id,
        newScheduledAt: formData.scheduledAt,
        reason: formData.reason,
      );

      if (!mounted) {
        return;
      }

      if (!rescheduled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reprogramar el ticket.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket reprogramado correctamente.')),
      );
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo reprogramar: $error')));
    }
  }

  bool _canAddServices(TicketSummary ticket) {
    return !{
      'finalizado',
      'cerrado',
      'cancelado',
      'no_asistio',
    }.contains(ticket.status);
  }

  bool _canReschedule(TicketSummary ticket) {
    return ticket.scheduledAt != null &&
        {'apartado', 'confirmado', 'en_espera'}.contains(ticket.status);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tickets',
      subtitle:
          'Seguimiento de cada solicitud desde WhatsApp hasta finalizaci\u00f3n.',
      children: [
        const InfoPanel(
          icon: Icons.confirmation_number_outlined,
          title: 'Tickets conectados con Supabase',
          description:
              'Este m\u00f3dulo ahora consulta tickets resumidos mediante una funci\u00f3n segura, sin abrir directamente las tablas sensibles.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _openCreateTicketDialog,
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Nuevo ticket'),
            ),
            OutlinedButton.icon(
              onPressed: _refreshTickets,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Actualizar tickets'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TicketSummary>>(
          future: ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Cargando tickets desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los tickets',
                description: snapshot.error.toString(),
              );
            }

            final tickets = snapshot.data ?? [];

            if (tickets.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin tickets disponibles',
                description: 'No hay tickets para mostrar en este momento.',
              );
            }

            return Card(
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Tickets desde Supabase'),
                    const SizedBox(height: 14),
                    ...tickets.map(
                      (ticket) => TicketRow(
                        ticket: ticket,
                        onAddService: _canAddServices(ticket)
                            ? () => _openAddTicketServiceDialog(ticket)
                            : null,
                        onReschedule: _canReschedule(ticket)
                            ? () => _openRescheduleTicketDialog(ticket)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CreateTicketDialog extends StatefulWidget {
  const _CreateTicketDialog({required this.clients});

  final List<ClientSummary> clients;

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController();

  String? selectedClientId;
  DateTime? scheduledAt;
  String channel = 'manual';

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  String get scheduledAtText {
    if (scheduledAt == null) {
      return 'Sin fecha programada';
    }

    final date = scheduledAt!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  Future<void> _selectDateAndTime() async {
    final now = DateTime.now();
    final initialDate = scheduledAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (date == null || !mounted) {
      return;
    }

    final initialTime = scheduledAt == null
        ? TimeOfDay.fromDateTime(now)
        : TimeOfDay.fromDateTime(scheduledAt!);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null || !mounted) {
      return;
    }

    setState(() {
      scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _TicketFormData(
        clientId: selectedClientId!,
        scheduledAt: scheduledAt,
        channel: channel,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo ticket'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedClientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: widget.clients
                      .map(
                        (client) => DropdownMenuItem<String>(
                          value: client.id,
                          child: Text(
                            '${client.name} · ${client.phone}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClientId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona un cliente';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  decoration: const InputDecoration(
                    labelText: 'Canal',
                    prefixIcon: Icon(Icons.call_split_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        channel = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Fecha y hora opcionales'),
                  subtitle: Text(scheduledAtText),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (scheduledAt != null)
                        IconButton(
                          tooltip: 'Quitar fecha',
                          onPressed: () {
                            setState(() {
                              scheduledAt = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        tooltip: 'Elegir fecha y hora',
                        onPressed: _selectDateAndTime,
                        icon: const Icon(Icons.edit_calendar_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas opcionales',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Crear ticket'),
        ),
      ],
    );
  }
}

class _TicketFormData {
  const _TicketFormData({
    required this.clientId,
    required this.scheduledAt,
    required this.channel,
    required this.notes,
  });

  final String clientId;
  final DateTime? scheduledAt;
  final String channel;
  final String? notes;
}

class _AddTicketServiceDialog extends StatefulWidget {
  const _AddTicketServiceDialog({required this.options});

  final List<TicketServiceOption> options;

  @override
  State<_AddTicketServiceDialog> createState() =>
      _AddTicketServiceDialogState();
}

class _AddTicketServiceDialogState extends State<_AddTicketServiceDialog> {
  final formKey = GlobalKey<FormState>();

  String? selectedServiceId;
  String selectedStylistId = '';

  List<TicketServiceOption> get services {
    final uniqueServices = <String, TicketServiceOption>{};

    for (final option in widget.options) {
      uniqueServices.putIfAbsent(option.serviceId, () => option);
    }

    return uniqueServices.values.toList();
  }

  List<TicketServiceOption> get stylists {
    if (selectedServiceId == null) {
      return [];
    }

    return widget.options
        .where(
          (option) =>
              option.serviceId == selectedServiceId && option.stylistId != null,
        )
        .toList();
  }

  TicketServiceOption? get selectedService {
    if (selectedServiceId == null) {
      return null;
    }

    for (final option in services) {
      if (option.serviceId == selectedServiceId) {
        return option;
      }
    }

    return null;
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _TicketServiceFormData(
        serviceId: selectedServiceId!,
        stylistId: selectedStylistId.isEmpty ? null : selectedStylistId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = selectedService;

    return AlertDialog(
      title: const Text('Agregar servicio'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedServiceId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Servicio',
                    prefixIcon: Icon(Icons.content_cut_outlined),
                  ),
                  items: services
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.serviceId,
                          child: Text(
                            '${option.serviceName} · ${option.formattedPrice}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedServiceId = value;
                      selectedStylistId = '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona un servicio';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedServiceId),
                  initialValue: selectedStylistId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estilista opcional',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Sin asignar'),
                    ),
                    ...stylists.map(
                      (option) => DropdownMenuItem<String>(
                        value: option.stylistId!,
                        child: Text(
                          option.stylistName ?? 'Sin estilista',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: selectedServiceId == null
                      ? null
                      : (value) {
                          setState(() {
                            selectedStylistId = value ?? '';
                          });
                        },
                ),
                if (service != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${service.category} · ${service.formattedPrice} · '
                      '${service.durationMinutes} min',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B21B6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_outlined),
          label: const Text('Agregar servicio'),
        ),
      ],
    );
  }
}

class _TicketServiceFormData {
  const _TicketServiceFormData({
    required this.serviceId,
    required this.stylistId,
  });

  final String serviceId;
  final String? stylistId;
}

class _RescheduleTicketDialog extends StatefulWidget {
  const _RescheduleTicketDialog({required this.ticket});

  final TicketSummary ticket;

  @override
  State<_RescheduleTicketDialog> createState() =>
      _RescheduleTicketDialogState();
}

class _RescheduleTicketDialogState extends State<_RescheduleTicketDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  late DateTime scheduledAt;

  @override
  void initState() {
    super.initState();
    scheduledAt = widget.ticket.scheduledAt!.toLocal();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  String get scheduledAtText {
    final day = scheduledAt.day.toString().padLeft(2, '0');
    final month = scheduledAt.month.toString().padLeft(2, '0');
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');

    return '$day/$month/${scheduledAt.year} $hour:$minute';
  }

  Future<void> _selectDateAndTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledAt.isBefore(now) ? now : scheduledAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
    );

    if (time == null || !mounted) {
      return;
    }

    setState(() {
      scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _RescheduleTicketFormData(
        scheduledAt: scheduledAt,
        reason: reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reprogramar ticket'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('Nueva fecha y hora'),
                subtitle: Text(scheduledAtText),
                trailing: IconButton(
                  tooltip: 'Elegir fecha y hora',
                  onPressed: _selectDateAndTime,
                  icon: const Icon(Icons.edit_calendar_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la reprogramación',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Indica el motivo de la reprogramación';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Reprogramar'),
        ),
      ],
    );
  }
}

class _RescheduleTicketFormData {
  const _RescheduleTicketFormData({
    required this.scheduledAt,
    required this.reason,
  });

  final DateTime scheduledAt;
  final String reason;
}

class TicketRow extends StatelessWidget {
  final TicketSummary ticket;
  final VoidCallback? onAddService;
  final VoidCallback? onReschedule;

  const TicketRow({
    super.key,
    required this.ticket,
    required this.onAddService,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 28,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.clientName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.serviceNames,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estilista: ${ticket.stylistNames}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fecha: ${ticket.scheduledAtText} \u00b7 Canal: ${ticket.channel}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${ticket.formattedPrice} \u00b7 ${ticket.totalDurationMinutes} min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
                if (onAddService != null || onReschedule != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (onAddService != null)
                        OutlinedButton.icon(
                          onPressed: onAddService,
                          icon: const Icon(Icons.add_outlined),
                          label: const Text('Agregar servicio'),
                        ),
                      if (onReschedule != null)
                        OutlinedButton.icon(
                          onPressed: onReschedule,
                          icon: const Icon(Icons.event_repeat_outlined),
                          label: const Text('Reprogramar'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          TicketStatusBadge(label: ticket.statusLabel),
        ],
      ),
    );
  }
}

class TicketStatusBadge extends StatelessWidget {
  final String label;

  const TicketStatusBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6D28D9),
        ),
      ),
    );
  }
}
