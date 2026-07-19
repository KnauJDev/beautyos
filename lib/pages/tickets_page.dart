import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_summary.dart';
import '../models/ticket_service_option.dart';
import '../models/ticket_service_management_item.dart';
import '../models/ticket_service_correction_option.dart';
import '../models/ticket_payment.dart';
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

      final formData = await showDialog<_TicketFormData>(
        context: context,
        builder: (context) => _CreateTicketDialog(
          clients: clients,
          clientsService: clientsService,
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando ticket: ${_friendlyError(error)}'),
        ),
      );
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
        SnackBar(
          content: Text(
            'No se pudo agregar el servicio: ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _openManageTicketServicesDialog(TicketSummary ticket) async {
    try {
      final itemsFuture = ticketsService.getTicketServicesForManagement(
        ticket.id,
      );
      final optionsFuture = ticketsService.getTicketServiceOptions();
      final items = await itemsFuture;
      final options = await optionsFuture;

      if (!mounted) {
        return;
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay servicios activos para gestionar.'),
          ),
        );
        return;
      }

      final action = await showDialog<_TicketServiceManagementAction>(
        context: context,
        builder: (context) => _ManageTicketServicesDialog(items: items),
      );

      if (action == null || !mounted) {
        return;
      }

      late final bool succeeded;
      late final String successMessage;

      if (action.type == _TicketServiceManagementActionType.edit) {
        final formData = await showDialog<_EditTicketServiceFormData>(
          context: context,
          builder: (context) =>
              _EditTicketServiceDialog(item: action.item, options: options),
        );

        if (formData == null) {
          return;
        }

        succeeded = await ticketsService.updateTicketServiceAssignment(
          ticketServiceId: action.item.ticketServiceId,
          serviceId: formData.serviceId,
          stylistId: formData.stylistId,
          reason: formData.reason,
        );
        successMessage = 'Servicio y asignacion actualizados.';
      } else {
        final formData = await showDialog<_RemoveTicketServiceFormData>(
          context: context,
          builder: (context) => _RemoveTicketServiceDialog(item: action.item),
        );

        if (formData == null) {
          return;
        }

        succeeded = await ticketsService.removeTicketService(
          ticketServiceId: action.item.ticketServiceId,
          reason: formData.reason,
        );
        successMessage = 'Servicio retirado sin borrar su historial.';
      }

      if (!mounted) {
        return;
      }

      if (!succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la operacion.')),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo gestionar el servicio: ${_friendlyError(error)}',
          ),
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo reprogramar: ${_friendlyError(error)}'),
        ),
      );
    }
  }

  Future<void> _openChangeTicketStatusDialog(TicketSummary ticket) async {
    final formData = await showDialog<_TicketStatusFormData>(
      context: context,
      builder: (context) => _ChangeTicketStatusDialog(ticket: ticket),
    );

    if (formData == null) {
      return;
    }

    try {
      final changed = await ticketsService.changeTicketStatus(
        ticketId: ticket.id,
        newStatus: formData.newStatus,
        reason: formData.reason,
      );

      if (!mounted) {
        return;
      }

      if (!changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el estado del ticket.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado del ticket actualizado.')),
      );
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el estado: ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _openCorrectCompletionDialog(TicketSummary ticket) async {
    try {
      final options = await ticketsService.getTicketServicesForCorrection(
        ticket.id,
      );

      if (!mounted) {
        return;
      }

      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay servicios finalizados para corregir.'),
          ),
        );
        return;
      }

      final formData = await showDialog<_CorrectionFormData>(
        context: context,
        builder: (context) => _CorrectCompletionDialog(options: options),
      );

      if (formData == null) {
        return;
      }

      final corrected = await ticketsService.reopenFinishedTicketService(
        ticketServiceId: formData.ticketServiceId,
        reason: formData.reason,
      );

      if (!mounted) {
        return;
      }

      if (!corrected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo corregir la finalización.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio reabierto correctamente.')),
      );
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo corregir: ${_friendlyError(error)}'),
        ),
      );
    }
  }

  Future<void> _openPaymentsDialog(TicketSummary ticket) async {
    try {
      final summaryFuture = ticketsService.getTicketPaymentSummary(ticket.id);
      final paymentsFuture = ticketsService.getTicketPayments(ticket.id);
      final summary = await summaryFuture;
      final payments = await paymentsFuture;

      if (!mounted) {
        return;
      }

      final dialogResult = await showDialog<Object>(
        context: context,
        builder: (context) => _PaymentsDialog(
          ticket: ticket,
          summary: summary,
          payments: payments,
        ),
      );

      if (dialogResult == null) {
        return;
      }

      late final bool succeeded;
      late final String successMessage;

      if (dialogResult is _PaymentFormData) {
        succeeded = await ticketsService.registerTicketPayment(
          ticketId: ticket.id,
          amount: dialogResult.amount,
          method: dialogResult.method,
          reference: dialogResult.reference,
          notes: dialogResult.notes,
        );
        successMessage = 'Pago registrado correctamente.';
      } else if (dialogResult is _VoidPaymentFormData) {
        succeeded = await ticketsService.voidTicketPayment(
          paymentId: dialogResult.paymentId,
          reason: dialogResult.reason,
        );
        successMessage = 'Pago anulado y saldo actualizado.';
      } else {
        return;
      }

      if (!mounted) {
        return;
      }

      if (!succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la operación.')),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      _refreshTickets();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo gestionar el pago: ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  bool _canAddServices(TicketSummary ticket) {
    return {
      'solicitado',
      'cotizado',
      'apartado',
      'confirmado',
      'en_espera',
    }.contains(ticket.status);
  }

  bool _canManageServices(TicketSummary ticket) {
    return _canAddServices(ticket) && ticket.totalDurationMinutes > 0;
  }

  bool _canReschedule(TicketSummary ticket) {
    return ticket.scheduledAt != null &&
        {
          'solicitado',
          'cotizado',
          'apartado',
          'confirmado',
          'en_espera',
        }.contains(ticket.status);
  }

  bool _canChangeStatus(TicketSummary ticket) {
    return _availableNextStatuses(ticket.status).isNotEmpty;
  }

  bool _canCorrectCompletion(TicketSummary ticket) {
    return {'en_proceso', 'finalizado'}.contains(ticket.status);
  }

  bool _canManagePayments(TicketSummary ticket) {
    return {'finalizado', 'cerrado'}.contains(ticket.status);
  }

  static List<String> _availableNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'solicitado':
        return ['cotizado', 'apartado', 'confirmado', 'cancelado'];
      case 'cotizado':
        return ['apartado', 'confirmado', 'cancelado'];
      case 'apartado':
        return ['confirmado', 'cancelado'];
      case 'confirmado':
        return ['en_espera', 'en_proceso', 'cancelado', 'no_asistio'];
      case 'en_espera':
        return ['en_proceso', 'cancelado', 'no_asistio'];
      default:
        return [];
    }
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
                        onManageServices: _canManageServices(ticket)
                            ? () => _openManageTicketServicesDialog(ticket)
                            : null,
                        onReschedule: _canReschedule(ticket)
                            ? () => _openRescheduleTicketDialog(ticket)
                            : null,
                        onChangeStatus: _canChangeStatus(ticket)
                            ? () => _openChangeTicketStatusDialog(ticket)
                            : null,
                        onCorrectCompletion: _canCorrectCompletion(ticket)
                            ? () => _openCorrectCompletionDialog(ticket)
                            : null,
                        onManagePayments: _canManagePayments(ticket)
                            ? () => _openPaymentsDialog(ticket)
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
  const _CreateTicketDialog({
    required this.clients,
    required this.clientsService,
  });

  final List<ClientSummary> clients;
  final ClientsService clientsService;

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController();

  late final List<ClientSummary> clients;
  String? selectedClientId;
  DateTime? scheduledAt;
  String channel = 'manual';
  bool isCreatingClient = false;

  @override
  void initState() {
    super.initState();
    clients = [...widget.clients]
      ..sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
  }

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

  Future<void> _openQuickCreateClientDialog() async {
    final formData = await showDialog<_QuickClientFormData>(
      context: context,
      builder: (context) => const _QuickCreateClientDialog(),
    );

    if (formData == null || !mounted) {
      return;
    }

    setState(() {
      isCreatingClient = true;
    });

    try {
      final createdClient = await widget.clientsService.createClient(
        name: formData.name,
        phone: formData.phone,
        email: formData.email,
        notes: formData.notes,
      );

      if (!mounted) {
        return;
      }

      if (createdClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo crear el cliente. Verifica tus permisos.',
            ),
          ),
        );
        return;
      }

      setState(() {
        clients.add(createdClient);
        clients.sort(
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        );
        selectedClientId = createdClient.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente creado y seleccionado correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando cliente: ${_friendlyError(error)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isCreatingClient = false;
        });
      }
    }
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
                  key: ValueKey(selectedClientId),
                  initialValue: selectedClientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: clients
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: isCreatingClient
                        ? null
                        : _openQuickCreateClientDialog,
                    icon: isCreatingClient
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                      isCreatingClient
                          ? 'Guardando cliente...'
                          : 'Crear cliente rápido',
                    ),
                  ),
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

class _QuickCreateClientDialog extends StatefulWidget {
  const _QuickCreateClientDialog();

  @override
  State<_QuickCreateClientDialog> createState() =>
      _QuickCreateClientDialogState();
}

class _QuickCreateClientDialogState extends State<_QuickCreateClientDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _QuickClientFormData(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear cliente rápido'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el nombre del cliente'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el teléfono del cliente'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email opcional',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
          label: const Text('Guardar cliente'),
        ),
      ],
    );
  }
}

class _QuickClientFormData {
  const _QuickClientFormData({
    required this.name,
    required this.phone,
    this.email,
    this.notes,
  });

  final String name;
  final String phone;
  final String? email;
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

String _friendlyError(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }
  return error.toString();
}

class _TicketServiceFormData {
  const _TicketServiceFormData({
    required this.serviceId,
    required this.stylistId,
  });

  final String serviceId;
  final String? stylistId;
}

enum _TicketServiceManagementActionType { edit, remove }

class _TicketServiceManagementAction {
  const _TicketServiceManagementAction({
    required this.type,
    required this.item,
  });

  final _TicketServiceManagementActionType type;
  final TicketServiceManagementItem item;
}

class _ManageTicketServicesDialog extends StatelessWidget {
  const _ManageTicketServicesDialog({required this.items});

  final List<TicketServiceManagementItem> items;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar servicios'),
      content: SizedBox(
        width: 620,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.content_cut_outlined,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.serviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D1B69),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estilista: ${item.stylistName ?? 'Sin asignar'}',
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.formattedPrice} · ${item.durationMinutes} min',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(
                            _TicketServiceManagementAction(
                              type: _TicketServiceManagementActionType.edit,
                              item: item,
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(
                            _TicketServiceManagementAction(
                              type: _TicketServiceManagementActionType.remove,
                              item: item,
                            ),
                          ),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                          ),
                          label: const Text('Retirar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _EditTicketServiceDialog extends StatefulWidget {
  const _EditTicketServiceDialog({required this.item, required this.options});

  final TicketServiceManagementItem item;
  final List<TicketServiceOption> options;

  @override
  State<_EditTicketServiceDialog> createState() =>
      _EditTicketServiceDialogState();
}

class _EditTicketServiceDialogState extends State<_EditTicketServiceDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  String? selectedServiceId;
  String selectedStylistId = '';

  List<TicketServiceOption> get services {
    final uniqueServices = <String, TicketServiceOption>{};

    for (final option in widget.options) {
      uniqueServices.putIfAbsent(option.serviceId, () => option);
    }

    final result = uniqueServices.values.toList();
    result.sort((a, b) => a.serviceName.compareTo(b.serviceName));
    return result;
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
    for (final option in services) {
      if (option.serviceId == selectedServiceId) {
        return option;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    selectedServiceId =
        widget.options.any(
          (option) => option.serviceId == widget.item.serviceId,
        )
        ? widget.item.serviceId
        : null;

    final currentStylistId = widget.item.stylistId;
    if (currentStylistId != null &&
        widget.options.any(
          (option) =>
              option.serviceId == selectedServiceId &&
              option.stylistId == currentStylistId,
        )) {
      selectedStylistId = currentStylistId;
    }
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _EditTicketServiceFormData(
        serviceId: selectedServiceId!,
        stylistId: selectedStylistId.isEmpty ? null : selectedStylistId,
        reason: reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = selectedService;

    return AlertDialog(
      title: const Text('Editar servicio asignado'),
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
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecciona un servicio'
                      : null,
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del cambio',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  minLines: 2,
                  maxLines: 3,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Indica por que realizas el cambio'
                      : null,
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
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar cambio'),
        ),
      ],
    );
  }
}

class _EditTicketServiceFormData {
  const _EditTicketServiceFormData({
    required this.serviceId,
    required this.stylistId,
    required this.reason,
  });

  final String serviceId;
  final String? stylistId;
  final String reason;
}

class _RemoveTicketServiceDialog extends StatefulWidget {
  const _RemoveTicketServiceDialog({required this.item});

  final TicketServiceManagementItem item;

  @override
  State<_RemoveTicketServiceDialog> createState() =>
      _RemoveTicketServiceDialogState();
}

class _RemoveTicketServiceDialogState
    extends State<_RemoveTicketServiceDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(
      context,
    ).pop(_RemoveTicketServiceFormData(reason: reasonController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Retirar servicio'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.serviceName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El servicio dejará de contar en el ticket y la agenda. '
                'Su historial se conservará para auditoría.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo del retiro',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                minLines: 2,
                maxLines: 3,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Indica por que retiras el servicio'
                    : null,
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
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Retirar servicio'),
        ),
      ],
    );
  }
}

class _RemoveTicketServiceFormData {
  const _RemoveTicketServiceFormData({required this.reason});

  final String reason;
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

class _ChangeTicketStatusDialog extends StatefulWidget {
  const _ChangeTicketStatusDialog({required this.ticket});

  final TicketSummary ticket;

  @override
  State<_ChangeTicketStatusDialog> createState() =>
      _ChangeTicketStatusDialogState();
}

class _ChangeTicketStatusDialogState extends State<_ChangeTicketStatusDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  late final List<String> availableStatuses;
  String? selectedStatus;

  @override
  void initState() {
    super.initState();
    availableStatuses = _TicketsPageState._availableNextStatuses(
      widget.ticket.status,
    );
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  bool get requiresReason {
    return selectedStatus == 'cancelado' || selectedStatus == 'no_asistio';
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _TicketStatusFormData(
        newStatus: selectedStatus!,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Actualizar estado'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Estado actual: ${widget.ticket.statusLabel}'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Nuevo estado',
                  prefixIcon: Icon(Icons.swap_horiz_outlined),
                ),
                items: availableStatuses
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(_ticketStatusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecciona el nuevo estado';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: requiresReason
                      ? 'Motivo obligatorio'
                      : 'Motivo opcional',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) {
                  if (requiresReason &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Indica el motivo de esta decisión';
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
          icon: const Icon(Icons.save_outlined),
          label: const Text('Actualizar estado'),
        ),
      ],
    );
  }
}

class _TicketStatusFormData {
  const _TicketStatusFormData({required this.newStatus, required this.reason});

  final String newStatus;
  final String? reason;
}

class _CorrectCompletionDialog extends StatefulWidget {
  const _CorrectCompletionDialog({required this.options});

  final List<TicketServiceCorrectionOption> options;

  @override
  State<_CorrectCompletionDialog> createState() =>
      _CorrectCompletionDialogState();
}

class _CorrectCompletionDialogState extends State<_CorrectCompletionDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  String? selectedTicketServiceId;

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CorrectionFormData(
        ticketServiceId: selectedTicketServiceId!,
        reason: reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir finalización'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'El servicio seleccionado y su ticket volverán a '
                  '“En proceso”. La corrección quedará registrada.',
                  style: TextStyle(color: Color(0xFF9A3412)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTicketServiceId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Servicio finalizado',
                  prefixIcon: Icon(Icons.task_alt_outlined),
                ),
                items: widget.options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.ticketServiceId,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTicketServiceId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecciona el servicio que deseas reabrir';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Indica por qué se corrige la finalización';
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
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('Reabrir servicio'),
        ),
      ],
    );
  }
}

class _CorrectionFormData {
  const _CorrectionFormData({
    required this.ticketServiceId,
    required this.reason,
  });

  final String ticketServiceId;
  final String reason;
}

class _PaymentsDialog extends StatefulWidget {
  const _PaymentsDialog({
    required this.ticket,
    required this.summary,
    required this.payments,
  });

  final TicketSummary ticket;
  final TicketPaymentSummary summary;
  final List<TicketPaymentRecord> payments;

  @override
  State<_PaymentsDialog> createState() => _PaymentsDialogState();
}

class _PaymentsDialogState extends State<_PaymentsDialog> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  String method = 'efectivo';

  bool get canRegisterPayment {
    return widget.ticket.status == 'finalizado' &&
        widget.summary.balanceAmount > 0;
  }

  @override
  void initState() {
    super.initState();
    amountController.text = widget.summary.balanceAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  num? _parseAmount(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    return num.tryParse(normalized);
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _PaymentFormData(
        amount: _parseAmount(amountController.text)!,
        method: method,
        reference: referenceController.text.trim().isEmpty
            ? null
            : referenceController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      ),
    );
  }

  Future<void> _requestVoid(TicketPaymentRecord payment) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _VoidPaymentDialog(payment: payment),
    );

    if (reason == null || !mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pop(_VoidPaymentFormData(paymentId: payment.paymentId, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pagos y saldo'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      _PaymentMetric(
                        label: 'Total',
                        value: formatMoney(widget.summary.totalAmount),
                      ),
                      _PaymentMetric(
                        label: 'Pagado',
                        value: formatMoney(widget.summary.paidAmount),
                      ),
                      _PaymentMetric(
                        label: 'Saldo',
                        value: formatMoney(widget.summary.balanceAmount),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Movimientos registrados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (widget.payments.isEmpty)
                  const Text('Aún no hay pagos registrados.')
                else
                  ...widget.payments.map(
                    (payment) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(
                        '${formatMoney(payment.amount)} · '
                        '${payment.methodLabel}',
                      ),
                      subtitle: Text(
                        [
                          payment.receivedAtText,
                          if (payment.reference != null &&
                              payment.reference!.trim().isNotEmpty)
                            'Ref: ${payment.reference}',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(payment.status),
                          if (payment.status == 'registrado') ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Anular pago',
                              onPressed: () => _requestVoid(payment),
                              icon: const Icon(Icons.undo_outlined),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (canRegisterPayment) ...[
                  const Divider(height: 32),
                  const Text(
                    'Registrar nuevo pago',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor del pago',
                      prefixIcon: Icon(Icons.attach_money_outlined),
                    ),
                    validator: (value) {
                      final amount = _parseAmount(value ?? '');

                      if (amount == null || amount <= 0) {
                        return 'Escribe un valor mayor que cero';
                      }

                      if (amount > widget.summary.balanceAmount) {
                        return 'El pago no puede superar el saldo';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'tarjeta',
                        child: Text('Tarjeta'),
                      ),
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferencia'),
                      ),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          method = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Referencia opcional',
                      prefixIcon: Icon(Icons.tag_outlined),
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
                    maxLines: 3,
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
          child: Text(canRegisterPayment ? 'Cancelar' : 'Cerrar'),
        ),
        if (canRegisterPayment)
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Registrar pago'),
          ),
      ],
    );
  }
}

class _PaymentMetric extends StatelessWidget {
  const _PaymentMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PaymentFormData {
  const _PaymentFormData({
    required this.amount,
    required this.method,
    required this.reference,
    required this.notes,
  });

  final num amount;
  final String method;
  final String? reference;
  final String? notes;
}

class _VoidPaymentDialog extends StatefulWidget {
  const _VoidPaymentDialog({required this.payment});

  final TicketPaymentRecord payment;

  @override
  State<_VoidPaymentDialog> createState() => _VoidPaymentDialogState();
}

class _VoidPaymentDialogState extends State<_VoidPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular pago'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatMoney(widget.payment.amount)} · '
                '${widget.payment.methodLabel}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El movimiento se conservará como anulado y el saldo del '
                'ticket se restaurará.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Indica por qué se anula el pago';
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
          child: const Text('Volver'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.undo_outlined),
          label: const Text('Anular pago'),
        ),
      ],
    );
  }
}

class _VoidPaymentFormData {
  const _VoidPaymentFormData({required this.paymentId, required this.reason});

  final String paymentId;
  final String reason;
}

String _ticketStatusLabel(String status) {
  switch (status) {
    case 'solicitado':
      return 'Solicitado';
    case 'cotizado':
      return 'Cotizado';
    case 'apartado':
      return 'Apartado';
    case 'confirmado':
      return 'Confirmado';
    case 'en_espera':
      return 'En espera';
    case 'en_proceso':
      return 'En proceso';
    case 'finalizado':
      return 'Finalizado';
    case 'cancelado':
      return 'Cancelado';
    case 'no_asistio':
      return 'No asistió';
    default:
      return status;
  }
}

class TicketRow extends StatelessWidget {
  final TicketSummary ticket;
  final VoidCallback? onAddService;
  final VoidCallback? onManageServices;
  final VoidCallback? onReschedule;
  final VoidCallback? onChangeStatus;
  final VoidCallback? onCorrectCompletion;
  final VoidCallback? onManagePayments;

  const TicketRow({
    super.key,
    required this.ticket,
    required this.onAddService,
    required this.onManageServices,
    required this.onReschedule,
    required this.onChangeStatus,
    required this.onCorrectCompletion,
    required this.onManagePayments,
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
                if (ticket.showsPaymentInfo) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pagado: ${ticket.formattedPaidAmount} · '
                    'Saldo: ${ticket.formattedBalanceAmount}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ticket.balanceAmount == 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ],
                if (onAddService != null ||
                    onManageServices != null ||
                    onReschedule != null ||
                    onChangeStatus != null ||
                    onCorrectCompletion != null ||
                    onManagePayments != null) ...[
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
                      if (onManageServices != null)
                        OutlinedButton.icon(
                          onPressed: onManageServices,
                          icon: const Icon(Icons.tune_outlined),
                          label: const Text('Gestionar servicios'),
                        ),
                      if (onReschedule != null)
                        OutlinedButton.icon(
                          onPressed: onReschedule,
                          icon: const Icon(Icons.event_repeat_outlined),
                          label: const Text('Reprogramar'),
                        ),
                      if (onChangeStatus != null)
                        OutlinedButton.icon(
                          onPressed: onChangeStatus,
                          icon: const Icon(Icons.swap_horiz_outlined),
                          label: const Text('Cambiar estado'),
                        ),
                      if (onCorrectCompletion != null)
                        OutlinedButton.icon(
                          onPressed: onCorrectCompletion,
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text('Corregir finalización'),
                        ),
                      if (onManagePayments != null)
                        FilledButton.icon(
                          onPressed: onManagePayments,
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(
                            ticket.status == 'cerrado'
                                ? 'Ver pagos'
                                : 'Pagos y saldo',
                          ),
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
