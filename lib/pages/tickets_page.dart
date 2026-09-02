import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

import '../models/client_summary.dart';
import '../models/available_appointment_slot.dart';
import '../models/ticket_service_option.dart';
import '../models/ticket_service_management_item.dart';
import '../models/ticket_service_correction_option.dart';
import '../models/ticket_payment.dart';
import '../models/acciones_de_ticket.dart';
import '../models/ticket_summary.dart';
import '../services/clients_service.dart';
import '../services/tickets_service.dart';
import '../widgets/add_work_photo_dialog.dart';
import '../widgets/app_widgets.dart';
import '../widgets/candado_de_plan.dart';
import 'agenda_page.dart' show buildWhatsAppUri;

/// Abre el diálogo de crear cita para [branchId] y devuelve `true` si la
/// cita se creó. Compartido entre [TicketsPage] (su propio botón "Nueva
/// cita") y la acción rápida "+ Nueva Cita" del header (`main.dart`), para
/// que ambos abran exactamente el mismo diálogo sin duplicar la lógica de
/// carga de clientes/servicios.
Future<bool> openCreateAppointmentDialog(
  BuildContext context,
  String branchId,
) async {
  final clientsService = const ClientsService();
  final ticketsService = TicketsService(branchId: branchId);

  try {
    final clientsFuture = clientsService.getClientsSummary();
    final optionsFuture = ticketsService.getTicketServiceOptions();
    final clients = await clientsFuture;
    final options = await optionsFuture;

    if (!context.mounted) {
      return false;
    }

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay servicios activos disponibles.'),
        ),
      );
      return false;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => CreateAppointmentDialog(
        clients: clients,
        clientsService: clientsService,
        ticketsService: ticketsService,
        options: options,
      ),
    );

    if (created != true) {
      return false;
    }

    if (!context.mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Reserva creada correctamente y pendiente de confirmación.',
        ),
      ),
    );
    return true;
  } catch (error) {
    if (!context.mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se pudo crear la reserva: ${_friendlyError(error)}',
        ),
      ),
    );
    return false;
  }
}

class TicketsPage extends StatefulWidget {
  const TicketsPage({
    super.key,
    required this.branchId,
    required this.isOwnerOrAdmin,
    this.puedePortafolio = true,
    this.puedeResenas = true,
    this.openTicketId,
    this.onTicketOpened,
    this.collectTicketId,
    this.onCollectTicketOpened,
  });

  final String branchId;

  /// Espeja el `array['tenant_owner','admin']` del backend (D-095). Dos
  /// acciones de esta pantalla revierten dinero ya registrado y estan
  /// reservadas: anular un pago y corregir un servicio ya finalizado. El
  /// asistente cobra y atiende, pero no deshace.
  final bool isOwnerOrAdmin;

  /// Lo que el plan del negocio cubre (paso 8.14, D-187). Por defecto `true`:
  /// si no se pudo consultar no se bloquea nada, mismo criterio que D-184 --
  /// quien impide de verdad la operacion es el backend.
  final bool puedePortafolio;
  final bool puedeResenas;

  /// Ticket que hay que abrir apenas cargue la lista, sin que el usuario lo
  /// busque (D-163: navegacion directa desde el Tablero de Agenda). Lo pone
  /// el shell (`main.dart`) cuando se toca una tarjeta en Agenda.
  final String? openTicketId;

  /// Avisa al shell que ya se consumio `openTicketId`, para que no lo vuelva
  /// a mandar en el proximo build y reabra el mismo ticket.
  final VoidCallback? onTicketOpened;

  /// Ticket que hay que abrir directo en el dialogo de pago, sin pasar por
  /// la Ficha Completa (UX-03/UX-05, bloque de velocidad de mostrador). Lo
  /// pone el shell cuando se toca "Cobrar" en la tarjeta de Agenda -- mismo
  /// mecanismo que [openTicketId], pero saltandose la hoja de detalle.
  final String? collectTicketId;

  /// Avisa al shell que ya se consumio `collectTicketId`.
  final VoidCallback? onCollectTicketOpened;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final ClientsService clientsService = const ClientsService();
  late final TicketsService ticketsService;
  late Future<List<TicketSummary>> ticketsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDateFilter = 'todos'; // 'hoy', 'semana', 'mes', 'todos', 'personalizado'
  DateTimeRange? _customDateRange;
  String _selectedStateFilter = 'todos'; // 'todos', 'por_confirmar', 'confirmado', 'en_proceso', 'por_cobrar', 'cerrado', 'cancelado'
  String _selectedStylist = 'todos';

  @override
  void initState() {
    super.initState();
    ticketsService = TicketsService(branchId: widget.branchId);
    ticketsFuture = ticketsService.getTicketsSummary();
    _maybeOpenPendingTicket();
    _maybeOpenPendingCollectTicket();
  }

  @override
  void didUpdateWidget(covariant TicketsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openTicketId != null &&
        widget.openTicketId != oldWidget.openTicketId) {
      _maybeOpenPendingTicket();
    }
    if (widget.collectTicketId != null &&
        widget.collectTicketId != oldWidget.collectTicketId) {
      _maybeOpenPendingCollectTicket();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Abre la Ficha Completa de `widget.openTicketId` sin que el usuario lo
  /// busque (D-163: navegacion directa desde el Tablero de Agenda). El
  /// `await` deja pasar el build en curso antes de avisarle al shell que ya
  /// se consumio -- llamar `onTicketOpened` de forma sincrona aqui rompería
  /// con "setState() called during build".
  Future<void> _maybeOpenPendingTicket() async {
    final ticketId = widget.openTicketId;
    if (ticketId == null) {
      return;
    }

    final tickets = await ticketsFuture;
    if (!mounted) {
      return;
    }

    widget.onTicketOpened?.call();

    TicketSummary? ticket;
    for (final t in tickets) {
      if (t.id == ticketId) {
        ticket = t;
        break;
      }
    }

    if (ticket != null) {
      await _openTicketDetailSheet(ticket);
    }
  }

  /// Abre el dialogo de pago de `widget.collectTicketId` directo, sin la
  /// Ficha Completa de por medio (bloque de velocidad de mostrador). Si el
  /// ticket ya no admite gestionar pagos -- cancelado o no asistio, ver
  /// `AccionesDeTicket.puedeGestionarPagos` -- cae a la Ficha Completa en
  /// vez de no hacer nada, para que el toque en Agenda siempre lleve a
  /// algun sitio util.
  Future<void> _maybeOpenPendingCollectTicket() async {
    final ticketId = widget.collectTicketId;
    if (ticketId == null) {
      return;
    }

    final tickets = await ticketsFuture;
    if (!mounted) {
      return;
    }

    widget.onCollectTicketOpened?.call();

    TicketSummary? ticket;
    for (final t in tickets) {
      if (t.id == ticketId) {
        ticket = t;
        break;
      }
    }

    if (ticket == null) {
      return;
    }

    if (_canManagePayments(ticket)) {
      await _openPaymentsDialog(ticket);
    } else {
      await _openTicketDetailSheet(ticket);
    }
  }

  void _refreshTickets() {
    setState(() {
      ticketsFuture = ticketsService.getTicketsSummary();
    });
  }

  Future<void> _openCreateAppointmentDialog() async {
    final created = await openCreateAppointmentDialog(context, widget.branchId);
    if (created) {
      _refreshTickets();
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
          canVoid: widget.isOwnerOrAdmin,
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

  // Las reglas viven en `AccionesDeTicket` para poder probarlas sin abrir un
  // navegador (H-03). Aqui solo se conectan con el ticket que toca.
  bool _canAddServices(TicketSummary ticket) =>
      AccionesDeTicket.puedeAgregarServicios(ticket.status);

  bool _canManageServices(TicketSummary ticket) =>
      AccionesDeTicket.puedeGestionarServicios(
        ticket.status,
        ticket.totalDurationMinutes,
      );

  bool _canReschedule(TicketSummary ticket) =>
      AccionesDeTicket.puedeReprogramar(
        ticket.status,
        tieneFecha: ticket.scheduledAt != null,
      );

  bool _canChangeStatus(TicketSummary ticket) =>
      AccionesDeTicket.puedeCambiarEstado(ticket.status);

  bool _canCorrectCompletion(TicketSummary ticket) =>
      AccionesDeTicket.puedeCorregirFinalizacion(
        ticket.status,
        esDuenoOAdmin: widget.isOwnerOrAdmin,
      );

  bool _canManagePayments(TicketSummary ticket) =>
      AccionesDeTicket.puedeGestionarPagos(ticket.status);

  bool _canCopyReviewLink(TicketSummary ticket) =>
      AccionesDeTicket.puedeCopiarEnlaceResena(ticket.status);

  /// Paso 8.14 (D-187). El enlace de resena es el caso mas feo de los dos:
  /// si el plan no cubre `reviews`, el salon copia el enlace, se lo manda a la
  /// clienta por WhatsApp, y **es la clienta** quien se estrella contra el
  /// error de `public_create_review`. El dano no lo recibe quien tiene el plan.
  Future<void> _copyReviewLinkOCandado(TicketSummary ticket) async {
    if (!widget.puedeResenas) {
      await mostrarCandadoDePlan(
        context,
        titulo: 'Resenas',
        explicacion:
            'Las resenas dejan que tu clienta califique el servicio y que esa '
            'calificacion se vea en la pagina publica de tu salon. Tu plan '
            'actual todavia no las incluye, asi que el enlace no le funcionaria '
            'a ella.',
        planSugerido: 'Profesional',
      );
      return;
    }

    await _copyReviewLink(ticket);
  }

  Future<void> _agregarFotoOCandado(TicketSummary ticket) async {
    if (!widget.puedePortafolio) {
      await mostrarCandadoDePlan(
        context,
        titulo: 'Fotos de trabajos',
        explicacion:
            'Las fotos de trabajos arman el portafolio de tu salon: lo que '
            'hiciste, con que clienta y con que estilista, listo para ensenarlo '
            'en tu pagina publica.',
        planSugerido: 'Profesional',
      );
      return;
    }

    await _openAddWorkPhotoDialog(ticket);
  }

  Future<void> _copyReviewLink(TicketSummary ticket) async {
    final link = '${Uri.base.origin}/?resena=${ticket.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace de reseña copiado.')),
    );
  }

  bool _canAddWorkPhoto(TicketSummary ticket) =>
      AccionesDeTicket.puedeAgregarFoto(ticket.status);

  Future<void> _openAddWorkPhotoDialog(TicketSummary ticket) async {
    List<TicketServiceManagementItem> stylistOptions;
    try {
      stylistOptions = await ticketsService.getTicketServicesForManagement(
        ticket.id,
      );
    } catch (_) {
      stylistOptions = const [];
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AddWorkPhotoDialog(
        branchId: widget.branchId,
        ticketId: ticket.id,
        stylistOptions: stylistOptions,
      ),
    );

    if (saved != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto agregada correctamente.')),
    );
  }

  List<TicketSummary> _filterTickets(List<TicketSummary> allTickets) {
    return allTickets.where((ticket) {
      // 1. Buscador de texto: ticketCode, saleCode, clientName, clientPhone, serviceNames, stylistNames
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final code = ticket.ticketCode.toLowerCase();
        final sale = (ticket.saleCode ?? '').toLowerCase();
        final client = ticket.clientName.toLowerCase();
        final phone = ticket.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final queryPhone = query.replaceAll(RegExp(r'[^0-9]'), '');
        final services = ticket.serviceNames.toLowerCase();
        final stylists = ticket.stylistNames.toLowerCase();

        final matches = code.contains(query) ||
            sale.contains(query) ||
            client.contains(query) ||
            (queryPhone.isNotEmpty && phone.contains(queryPhone)) ||
            services.contains(query) ||
            stylists.contains(query);

        if (!matches) return false;
      }

      // 2. Filtro de fecha
      if (ticket.scheduledAt != null) {
        final sched = ticket.scheduledAt!.toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final schedDay = DateTime(sched.year, sched.month, sched.day);

        if (_selectedDateFilter == 'hoy') {
          if (schedDay != today) return false;
        } else if (_selectedDateFilter == 'semana') {
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          if (schedDay.isBefore(startOfWeek) || schedDay.isAfter(endOfWeek)) return false;
        } else if (_selectedDateFilter == 'mes') {
          if (sched.year != now.year || sched.month != now.month) return false;
        } else if (_selectedDateFilter == 'personalizado' && _customDateRange != null) {
          final start = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day,
          );
          final end = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
          );
          if (schedDay.isBefore(start) || schedDay.isAfter(end)) return false;
        }
      }

      // 3. Filtro de estado
      if (_selectedStateFilter != 'todos') {
        final st = ticket.ticketStatus;
        switch (_selectedStateFilter) {
          case 'por_confirmar':
            if (st != TicketStatus.solicitado &&
                st != TicketStatus.cotizado &&
                st != TicketStatus.apartado) {
              return false;
            }
            break;
          case 'confirmado':
            if (st != TicketStatus.confirmado &&
                st != TicketStatus.enEspera) {
              return false;
            }
            break;
          case 'en_proceso':
            if (st != TicketStatus.enProceso) return false;
            break;
          case 'por_cobrar':
            if (st != TicketStatus.finalizado) return false;
            break;
          case 'cerrado':
            if (st != TicketStatus.cerrado) return false;
            break;
          case 'cancelado':
            if (st != TicketStatus.cancelado &&
                st != TicketStatus.noAsistio) {
              return false;
            }
            break;
        }
      }

      // 4. Filtro por estilista
      if (_selectedStylist != 'todos') {
        if (!ticket.stylistNames
            .toLowerCase()
            .contains(_selectedStylist.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _openTicketDetailSheet(TicketSummary ticket) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailSheet(
        ticket: ticket,
        isOwnerOrAdmin: widget.isOwnerOrAdmin,
        branchId: widget.branchId,
        ticketsService: ticketsService,
        onAddService: _canAddServices(ticket)
            ? () {
                Navigator.of(context).pop();
                _openAddTicketServiceDialog(ticket);
              }
            : null,
        onManageServices: _canManageServices(ticket)
            ? () {
                Navigator.of(context).pop();
                _openManageTicketServicesDialog(ticket);
              }
            : null,
        onReschedule: _canReschedule(ticket)
            ? () {
                Navigator.of(context).pop();
                _openRescheduleTicketDialog(ticket);
              }
            : null,
        onChangeStatus: _canChangeStatus(ticket)
            ? () {
                Navigator.of(context).pop();
                _openChangeTicketStatusDialog(ticket);
              }
            : null,
        onCorrectCompletion: _canCorrectCompletion(ticket)
            ? () {
                Navigator.of(context).pop();
                _openCorrectCompletionDialog(ticket);
              }
            : null,
        onManagePayments: _canManagePayments(ticket)
            ? () {
                Navigator.of(context).pop();
                _openPaymentsDialog(ticket);
              }
            : null,
        onCopyReviewLink: _canCopyReviewLink(ticket)
            ? () => _copyReviewLinkOCandado(ticket)
            : null,
        onAddWorkPhoto: _canAddWorkPhoto(ticket)
            ? () {
                Navigator.of(context).pop();
                _agregarFotoOCandado(ticket);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tickets de Atención',
      subtitle:
          'Control operativo de citas, sala de espera, servicios, pagos y trazabilidad contable.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _openCreateAppointmentDialog,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Nueva cita'),
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

            final allTickets = snapshot.data ?? [];
            final filteredTickets = _filterTickets(allTickets);

            // Obtener lista de estilistas únicos para el filtro
            final stylistsSet = <String>{};
            for (final t in allTickets) {
              if (t.stylistNames.isNotEmpty && t.stylistNames != 'Sin estilista') {
                for (final s in t.stylistNames.split(',')) {
                  final trimmed = s.trim();
                  if (trimmed.isNotEmpty) stylistsSet.add(trimmed);
                }
              }
            }
            final availableStylists = stylistsSet.toList()..sort();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel de Búsqueda y Filtros Rápidos (Nivel 2)
                Card(
                  elevation: 1,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Buscador universal
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por cliente, teléfono, #cita o venta...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // 2. Filtro de Fechas Rápido
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildDateFilterChip('todos', 'Todas las fechas'),
                              const SizedBox(width: 8),
                              _buildDateFilterChip('hoy', 'Hoy'),
                              const SizedBox(width: 8),
                              _buildDateFilterChip('semana', 'Esta semana'),
                              const SizedBox(width: 8),
                              _buildDateFilterChip('mes', 'Este mes'),
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: const Icon(Icons.date_range, size: 16),
                                label: Text(
                                  _selectedDateFilter == 'personalizado' &&
                                          _customDateRange != null
                                      ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                                      : 'Rango...',
                                ),
                                backgroundColor:
                                    _selectedDateFilter == 'personalizado'
                                        ? AppColors.brandTint
                                        : null,
                                onPressed: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                    initialDateRange: _customDateRange ??
                                        DateTimeRange(
                                          start: DateTime.now().subtract(
                                            const Duration(days: 7),
                                          ),
                                          end: DateTime.now(),
                                        ),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedDateFilter = 'personalizado';
                                      _customDateRange = picked;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 3. Chips de Estado Semánticos
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStateFilterChip(
                                'todos',
                                'Todos (${allTickets.length})',
                                null,
                              ),
                              const SizedBox(width: 8),
                              _buildStateFilterChip(
                                'por_confirmar',
                                'Por confirmar',
                                AppColors.statePending,
                              ),
                              const SizedBox(width: 8),
                              _buildStateFilterChip(
                                'confirmado',
                                'Confirmados',
                                AppColors.stateConfirmed,
                              ),
                              const SizedBox(width: 8),
                              _buildStateFilterChip(
                                'en_proceso',
                                'En proceso',
                                AppColors.stateInProgress,
                              ),
                              const SizedBox(width: 8),
                              _buildStateFilterChip(
                                'por_cobrar',
                                'Por cobrar',
                                AppColors.stateToCollect,
                              ),
                              const SizedBox(width: 8),
                              _buildStateFilterChip(
                                'cerrado',
                                'Cerrados',
                                AppColors.stateClosed,
                              ),
                              const SizedBox(width: 8),
                              _buildStateFilterChip(
                                'cancelado',
                                'Cancelados',
                                AppColors.danger,
                              ),
                            ],
                          ),
                        ),

                        // 4. Filtro por Estilista (si hay estilistas registrados)
                        if (availableStylists.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Estilista:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              DropdownButton<String>(
                                value: _selectedStylist,
                                isDense: true,
                                underline: const SizedBox.shrink(),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'todos',
                                    child: Text('Todos los estilistas'),
                                  ),
                                  ...availableStylists.map(
                                    (st) => DropdownMenuItem(
                                      value: st,
                                      child: Text(st),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedStylist = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Tickets (Nivel 2)
                if (filteredTickets.isEmpty)
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron tickets con los filtros actuales.',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _selectedDateFilter = 'todos';
                                  _selectedStateFilter = 'todos';
                                  _selectedStylist = 'todos';
                                  _customDateRange = null;
                                });
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Limpiar filtros'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Tickets (${filteredTickets.length})',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandDeep,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Toca un ticket para ver su ficha',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...filteredTickets.map(
                            (ticket) => TicketRow(
                              ticket: ticket,
                              onTap: () => _openTicketDetailSheet(ticket),
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
                              onCopyReviewLink: _canCopyReviewLink(ticket)
                                  ? () => _copyReviewLinkOCandado(ticket)
                                  : null,
                              onAddWorkPhoto: _canAddWorkPhoto(ticket)
                                  ? () => _agregarFotoOCandado(ticket)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateFilterChip(String value, String label) {
    final isSelected = _selectedDateFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTint,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDateFilter = value;
          });
        }
      },
    );
  }

  Widget _buildStateFilterChip(String value, String label, Color? color) {
    final isSelected = _selectedStateFilter == value;
    return ChoiceChip(
      avatar: color != null
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
      label: Text(label),
      selected: isSelected,
      selectedColor: color?.withValues(alpha: 0.18) ?? AppColors.brandTint,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStateFilter = value;
          });
        }
      },
    );
  }
}

/// Un horario disponible ya resuelto a un estilista concreto.
///
/// Mismo patrón de "Cualquiera disponible" que `PublicBookingPage` (D-166):
/// sin estilista elegido a mano se consultan todos los que ofrecen el
/// servicio y se combinan sus horarios en una sola lista, recordando de cuál
/// salió cada uno para poder reservar con el correcto (hallazgo C-01, la
/// lógica ya estaba escrita y probada, solo no se reutilizaba aquí).
class _ExpressSlotOption {
  const _ExpressSlotOption({
    required this.slot,
    required this.stylistId,
    required this.stylistName,
  });

  final AvailableAppointmentSlot slot;
  final String stylistId;
  final String stylistName;
}

class CreateAppointmentDialog extends StatefulWidget {
  const CreateAppointmentDialog({
    super.key,
    required this.clients,
    required this.clientsService,
    required this.ticketsService,
    required this.options,
  });

  final List<ClientSummary> clients;
  final ClientsService clientsService;
  final TicketsService ticketsService;
  final List<TicketServiceOption> options;

  @override
  State<CreateAppointmentDialog> createState() =>
      CreateAppointmentDialogState();
}

class CreateAppointmentDialogState extends State<CreateAppointmentDialog> {
  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController();

  late final List<ClientSummary> clients;
  String? selectedServiceId;
  String? selectedStylistId;

  /// El estilista real al que se le va a agendar la hora elegida. Coincide
  /// con [selectedStylistId] cuando se elige uno a mano; en modo "Cualquiera
  /// disponible" ([selectedStylistId] queda en `null`) es el estilista del
  /// que salió el horario que se seleccionó de la lista combinada.
  String? _bookingStylistId;
  String? selectedClientId;
  DateTime? selectedDate;
  DateTime? scheduledAt;
  List<_ExpressSlotOption>? _availableSlots;
  bool isCreatingClient = false;
  bool isLoadingSlots = false;
  bool isSaving = false;
  String? bookingError;
  String? slotsError;
  bool repeats = false;
  String repeatFrequency = 'daily';
  DateTime? repeatUntil;

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

  List<TicketServiceOption> get services {
    final uniqueServices = <String, TicketServiceOption>{};
    for (final option in widget.options) {
      uniqueServices.putIfAbsent(option.serviceId, () => option);
    }
    final result = uniqueServices.values.toList();
    result.sort(
      (first, second) => first.serviceName.compareTo(second.serviceName),
    );
    return result;
  }

  List<TicketServiceOption> get stylists {
    if (selectedServiceId == null) {
      return [];
    }

    final result = widget.options
        .where(
          (option) =>
              option.serviceId == selectedServiceId && option.stylistId != null,
        )
        .toList();
    result.sort(
      (first, second) =>
          (first.stylistName ?? '').compareTo(second.stylistName ?? ''),
    );
    return result;
  }

  TicketServiceOption? get selectedService {
    for (final service in services) {
      if (service.serviceId == selectedServiceId) {
        return service;
      }
    }
    return null;
  }

  TicketServiceOption? _stylistById(String? id) {
    if (id == null) {
      return null;
    }
    for (final stylist in stylists) {
      if (stylist.stylistId == id) {
        return stylist;
      }
    }
    return null;
  }

  String get scheduledAtText {
    if (scheduledAt == null) {
      return 'Selecciona fecha y hora';
    }

    final date = scheduledAt!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  String get selectedDateText {
    if (selectedDate == null) {
      return 'Selecciona el día para ver las horas disponibles';
    }

    final date = selectedDate!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? today,
      firstDate: today,
      lastDate: DateTime(now.year + 3),
    );

    if (date == null || !mounted) {
      return;
    }

    setState(() {
      selectedDate = DateTime(date.year, date.month, date.day);
      scheduledAt = null;
      _bookingStylistId = null;
      _availableSlots = null;
      slotsError = null;
    });

    await _loadAvailableSlots();
  }

  Future<void> _loadAvailableSlots() async {
    if (selectedServiceId == null || selectedDate == null) {
      return;
    }

    setState(() {
      isLoadingSlots = true;
      slotsError = null;
      _availableSlots = null;
    });

    try {
      // "Cualquiera disponible": sin estilista elegido a mano se consulta a
      // cada uno que ofrece el servicio y se combinan los horarios (D-166,
      // C-01). Con un estilista puntual es la misma consulta de siempre,
      // con un solo destino.
      final targets = selectedStylistId == null
          ? stylists
          : stylists
              .where((option) => option.stylistId == selectedStylistId)
              .toList();

      final results = await Future.wait(
        targets.map(
          (target) => widget.ticketsService.getAvailableAppointmentSlots(
            serviceId: selectedServiceId!,
            stylistId: target.stylistId!,
            date: selectedDate!,
          ),
        ),
      );

      final merged = <_ExpressSlotOption>[];
      final seenTimes = <DateTime>{};
      for (var i = 0; i < targets.length; i++) {
        for (final slot in results[i]) {
          // Si dos estilistas coinciden en la misma hora se muestra una
          // sola vez: son "Cualquiera disponible", no un listado por
          // persona.
          if (seenTimes.add(slot.startsAt)) {
            merged.add(
              _ExpressSlotOption(
                slot: slot,
                stylistId: targets[i].stylistId!,
                stylistName: targets[i].stylistName ?? 'Sin estilista',
              ),
            );
          }
        }
      }
      merged.sort((a, b) => a.slot.startsAt.compareTo(b.slot.startsAt));

      if (!mounted) {
        return;
      }
      setState(() {
        _availableSlots = merged;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        slotsError = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSlots = false;
        });
      }
    }
  }

  /// Cita de paso ("walk-in", UX-01): sin dejar de calcular disponibilidad
  /// real, encadena en un solo toque lo que antes eran tres pasos manuales
  /// -- estilista en "Cualquiera disponible", fecha de hoy, y el primer
  /// horario libre desde ahora. El cliente sigue siendo un campo aparte, no
  /// bloqueado (matiz de la auditoría de UX del 01-sep): se puede elegir
  /// antes o después de tocar este botón.
  Future<void> _atenderYa() async {
    if (selectedServiceId == null) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      selectedStylistId = null; // Cualquiera disponible.
      selectedDate = today;
      scheduledAt = null;
      _bookingStylistId = null;
      _availableSlots = null;
      slotsError = null;
    });

    await _loadAvailableSlots();

    if (!mounted) {
      return;
    }

    final slots = _availableSlots;
    if (slots == null || slots.isEmpty) {
      // El aviso de "no quedan horarios" ya lo muestra la sección de abajo.
      return;
    }

    final proximo = slots.firstWhere(
      (option) => !option.slot.startsAt.isBefore(now),
      orElse: () => slots.first,
    );

    setState(() {
      scheduledAt = proximo.slot.startsAt;
      _bookingStylistId = proximo.stylistId;
    });
  }

  String? get _resolvedStylistName =>
      _stylistById(_bookingStylistId)?.stylistName;

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
          const SnackBar(content: Text('No se pudo crear el cliente.')),
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

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    if (scheduledAt == null || !scheduledAt!.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha y hora futura para la reserva.'),
        ),
      );
      return;
    }

    if (repeats && repeatUntil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona hasta qué fecha se repite la cita.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
      bookingError = null;
    });

    if (repeats) {
      await _submitRecurring();
      return;
    }

    try {
      final created = await widget.ticketsService
          .createScheduledTicketWithService(
            clientId: selectedClientId!,
            serviceId: selectedServiceId!,
            stylistId: _bookingStylistId!,
            scheduledAt: scheduledAt!,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );

      if (!mounted) {
        return;
      }

      if (!created) {
        setState(() {
          bookingError = 'No se pudo guardar la reserva. Intenta nuevamente.';
        });
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        bookingError = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _submitRecurring() async {
    try {
      final results = await widget.ticketsService
          .createRecurringScheduledTicketWithService(
            clientId: selectedClientId!,
            serviceId: selectedServiceId!,
            stylistId: _bookingStylistId!,
            scheduledAt: scheduledAt!,
            repeatFrequency: repeatFrequency,
            repeatUntil: repeatUntil!,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );

      if (!mounted) {
        return;
      }

      final succeeded = results.where((r) => r.success).length;
      final failed = results.where((r) => !r.success).toList();

      Navigator.of(context).pop(true);

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Serie de citas creada'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$succeeded de ${results.length} citas se crearon '
                    'correctamente.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (failed.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron crear:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    for (final item in failed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${_formatDateTime(item.scheduledAt)}: '
                          '${item.errorMessage ?? "Error desconocido"}',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        bookingError = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final service = selectedService;
    final resolvedStylistName = _resolvedStylistName;

    return AlertDialog(
      title: const Text('Nueva cita'),
      content: SizedBox(
        width: 560,
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
                    labelText: '1. Servicio',
                    prefixIcon: Icon(Icons.content_cut_outlined),
                  ),
                  items: services
                      .map(
                        (option) => DropdownMenuItem(
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
                      selectedStylistId = null;
                      scheduledAt = null;
                      _bookingStylistId = null;
                      _availableSlots = null;
                      slotsError = null;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecciona un servicio'
                      : null,
                ),
                if (selectedServiceId != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: isLoadingSlots ? null : _atenderYa,
                      icon: const Icon(Icons.bolt_outlined),
                      label: const Text('Atender ya (walk-in)'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('appointment-stylist-$selectedServiceId'),
                  initialValue: selectedStylistId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '2. Estilista (o cualquiera disponible)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('⚡ Cualquiera disponible'),
                    ),
                    ...stylists.map(
                      (option) => DropdownMenuItem<String?>(
                        value: option.stylistId,
                        child: Text(option.stylistName ?? 'Sin estilista'),
                      ),
                    ),
                  ],
                  onChanged: selectedServiceId == null
                      ? null
                      : (value) {
                          setState(() {
                            selectedStylistId = value;
                            scheduledAt = null;
                            _bookingStylistId = null;
                            _availableSlots = null;
                            slotsError = null;
                          });
                          _loadAvailableSlots();
                        },
                  validator: (_) {
                    if (selectedServiceId != null && stylists.isEmpty) {
                      return 'Este servicio no tiene estilistas habilitados';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                FormField<DateTime>(
                  validator: (_) => scheduledAt == null
                      ? 'Selecciona una hora disponible'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('3. Fecha y hora disponible'),
                        subtitle: Text(
                          scheduledAt == null
                              ? selectedDateText
                              : scheduledAtText,
                        ),
                        trailing: IconButton(
                          tooltip: 'Elegir fecha',
                          onPressed: _selectDate,
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                        onTap: _selectDate,
                      ),
                      if (selectedServiceId != null &&
                          selectedDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          isLoadingSlots
                              ? 'Calculando disponibilidad...'
                              : 'Horas disponibles para $selectedDateText',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isLoadingSlots)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (slotsError != null)
                          Text(
                            slotsError!,
                            style: const TextStyle(color: AppColors.danger),
                          )
                        else if (_availableSlots != null &&
                            _availableSlots!.isEmpty)
                          const Text(
                            'No quedan horarios disponibles para este día. Elige otra fecha o estilista.',
                            style: TextStyle(color: AppColors.warning),
                          )
                        else if (_availableSlots != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSlots!
                                .map(
                                  (option) => ChoiceChip(
                                    label: Text(
                                      selectedStylistId == null
                                          ? '${option.slot.label} · ${option.stylistName}'
                                          : option.slot.label,
                                    ),
                                    selected:
                                        (scheduledAt?.isAtSameMomentAs(
                                              option.slot.startsAt,
                                            ) ??
                                            false) &&
                                        _bookingStylistId == option.stylistId,
                                    onSelected: (_) {
                                      setState(() {
                                        scheduledAt = option.slot.startsAt;
                                        _bookingStylistId = option.stylistId;
                                        bookingError = null;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('appointment-client-$selectedClientId'),
                  initialValue: selectedClientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '4. Cliente',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: clients
                      .map(
                        (client) => DropdownMenuItem(
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
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecciona un cliente'
                      : null,
                ),
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
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas opcionales',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repetir esta cita'),
                  subtitle: const Text(
                    'Crea una serie con el mismo cliente, servicio, '
                    'estilista y hora. Solo agenda interna.',
                  ),
                  value: repeats,
                  onChanged: isSaving
                      ? null
                      : (value) => setState(() => repeats = value),
                ),
                if (repeats) ...[
                  DropdownButtonFormField<String>(
                    initialValue: repeatFrequency,
                    decoration: const InputDecoration(labelText: 'Frecuencia'),
                    items: const [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('Diariamente'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Semanalmente'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => repeatFrequency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final base = scheduledAt ?? DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: repeatUntil ?? base,
                              firstDate: base,
                              lastDate: base.add(const Duration(days: 180)),
                            );
                            if (picked != null) {
                              setState(() => repeatUntil = picked);
                            }
                          },
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: Text(
                      repeatUntil == null
                          ? 'Hasta: seleccionar'
                          : 'Hasta: ${_formatDateTime(repeatUntil!)}',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Si una fecha choca con otra cita, se avisa cuál y se '
                    'crean las demás. Máximo 180 días.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
                if (service != null &&
                    resolvedStylistName != null &&
                    scheduledAt != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandTintSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${service.serviceName} con $resolvedStylistName\\n'
                      '$scheduledAtText · ${service.formattedPrice} · '
                      '${service.durationMinutes} min',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandDark,
                      ),
                    ),
                  ),
                ],
                if (bookingError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.dangerTint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.dangerTint),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bookingError!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : _submit,
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.event_available_outlined),
          label: Text(isSaving ? 'Guardando...' : 'Crear reserva'),
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
                      color: AppColors.brandTintSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${service.category} · ${service.formattedPrice} · '
                      '${service.durationMinutes} min',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandDark,
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.content_cut_outlined,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.serviceName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estilista: ${item.stylistName ?? 'Sin asignar'}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.formattedPrice} · ${item.durationMinutes} min',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
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
                      color: AppColors.brandTintSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${service.category} · ${service.formattedPrice} · '
                      '${service.durationMinutes} min',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandDark,
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandDeep,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El servicio dejará de contar en el ticket y la agenda. '
                'Su historial se conservará para auditoría.',
                style: TextStyle(color: AppColors.textSecondary),
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
    availableStatuses = AccionesDeTicket.siguientesEstados(
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
                  color: AppColors.warningTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'El servicio seleccionado y su ticket volverán a '
                  '“En proceso”. La corrección quedará registrada.',
                  style: TextStyle(color: AppColors.warning),
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
    required this.canVoid,
  });

  final TicketSummary ticket;
  final TicketPaymentSummary summary;
  final List<TicketPaymentRecord> payments;

  /// Anular un pago revierte dinero, asi que `void_ticket_payment_v2` solo
  /// admite owner y admin (D-095). El asistente cobra pero no anula. Sin esta
  /// bandera veia el boton y recibia un error al pulsarlo.
  final bool canVoid;

  @override
  State<_PaymentsDialog> createState() => _PaymentsDialogState();
}

class _PaymentsDialogState extends State<_PaymentsDialog> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  String method = 'efectivo';

  // D-163: el servidor ya acepta abonos en cualquier estado activo
  // (`register_ticket_payment`); el formulario tiene que reflejar la misma
  // regla que `AccionesDeTicket.puedeGestionarPagos`, no solo 'finalizado'.
  bool get canRegisterPayment {
    return !{'cancelado', 'no_asistio'}.contains(widget.ticket.status) &&
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
                    color: AppColors.brandTintSoft,
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
                          if (widget.canVoid &&
                              payment.status == 'registrado') ...[
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
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

String _ticketStatusLabel(String status) =>
    TicketStatus.desde(status).etiqueta;

class TicketRow extends StatelessWidget {
  final TicketSummary ticket;
  final VoidCallback? onTap;
  final VoidCallback? onAddService;
  final VoidCallback? onManageServices;
  final VoidCallback? onReschedule;
  final VoidCallback? onChangeStatus;
  final VoidCallback? onCorrectCompletion;
  final VoidCallback? onManagePayments;
  final VoidCallback? onCopyReviewLink;
  final VoidCallback? onAddWorkPhoto;

  const TicketRow({
    super.key,
    required this.ticket,
    this.onTap,
    required this.onAddService,
    required this.onManageServices,
    required this.onReschedule,
    required this.onChangeStatus,
    required this.onCorrectCompletion,
    required this.onManagePayments,
    required this.onCopyReviewLink,
    required this.onAddWorkPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Consecutivos y StatusPill
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (ticket.ticketCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '#${ticket.ticketCode}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (ticket.saleCode != null && ticket.saleCode!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successTint,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.receipt_outlined,
                                size: 12,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                ticket.saleCode!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      StatusPill(status: ticket.ticketStatus),
                    ],
                  ),
                ),
                Text(
                  ticket.scheduledAtText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Cliente y WhatsApp
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.clientName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
                if (ticket.clientPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.whatsapp,
                      size: 20,
                    ),
                    tooltip: 'WhatsApp a ${ticket.clientName}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      launchUrl(
                        buildWhatsAppUri(ticket.clientPhone),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Servicios y Estilista
            Text(
              ticket.serviceNames,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  ticket.stylistNames,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${ticket.totalDurationMinutes} min',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Finanzas
            Row(
              children: [
                Text(
                  ticket.formattedPrice,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                if (ticket.showsPaymentInfo) ...[
                  const SizedBox(width: 10),
                  Text(
                    '·  Pagado: ${ticket.formattedPaidAmount}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (ticket.hasPendingBalance) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Saldo: ${ticket.formattedBalanceAmount}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.stateToCollect,
                      ),
                    ),
                  ],
                ],
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),

            if (onManagePayments != null ||
                onChangeStatus != null ||
                onAddService != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Ver ficha'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (onManagePayments != null)
                    FilledButton.tonalIcon(
                      onPressed: onManagePayments,
                      icon: const Icon(Icons.payments_outlined, size: 15),
                      label: Text(
                        ticket.status == 'cerrado'
                            ? 'Ver pagos'
                            : 'Pagos y saldo',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (onChangeStatus != null)
                    OutlinedButton.icon(
                      onPressed: onChangeStatus,
                      icon: const Icon(Icons.swap_horiz_outlined, size: 15),
                      label: const Text('Estado'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketDetailSheet extends StatelessWidget {
  const _TicketDetailSheet({
    required this.ticket,
    required this.isOwnerOrAdmin,
    required this.branchId,
    required this.ticketsService,
    required this.onAddService,
    required this.onManageServices,
    required this.onReschedule,
    required this.onChangeStatus,
    required this.onCorrectCompletion,
    required this.onManagePayments,
    required this.onCopyReviewLink,
    required this.onAddWorkPhoto,
  });

  final TicketSummary ticket;
  final bool isOwnerOrAdmin;
  final String branchId;
  final TicketsService ticketsService;
  final VoidCallback? onAddService;
  final VoidCallback? onManageServices;
  final VoidCallback? onReschedule;
  final VoidCallback? onChangeStatus;
  final VoidCallback? onCorrectCompletion;
  final VoidCallback? onManagePayments;
  final VoidCallback? onCopyReviewLink;
  final VoidCallback? onAddWorkPhoto;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.90,
        maxWidth: isDesktop ? 650 : double.infinity,
      ),
      margin: isDesktop ? const EdgeInsets.symmetric(vertical: 24) : null,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: isDesktop
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (ticket.ticketCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Cita #${ticket.ticketCode}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (ticket.saleCode != null && ticket.saleCode!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successTint,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.receipt_outlined,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ticket.saleCode!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (onChangeStatus != null)
                        InkWell(
                          onTap: onChangeStatus,
                          borderRadius: BorderRadius.circular(20),
                          child: Tooltip(
                            message: 'Cambiar estado',
                            child: StatusPill(status: ticket.ticketStatus),
                          ),
                        )
                      else
                        StatusPill(status: ticket.ticketStatus),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Cliente Card
                  _buildSectionCard(
                    title: 'Cliente',
                    icon: Icons.person_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.clientName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (ticket.clientPhone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            ticket.clientPhone,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  launchUrl(
                                    buildWhatsAppUri(ticket.clientPhone),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: AppColors.whatsapp,
                                ),
                                label: const Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.whatsapp,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  launchUrl(
                                    Uri.parse('tel:${ticket.clientPhone}'),
                                  );
                                },
                                icon: const Icon(Icons.phone_outlined, size: 16),
                                label: const Text('Llamar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Horario & Canal Card
                  _buildSectionCard(
                    title: 'Programación y Canal',
                    icon: Icons.calendar_today_outlined,
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Fecha agendada:',
                          ticket.scheduledAtText,
                        ),
                        if (ticket.closedAtText.isNotEmpty)
                          _buildDetailRow(
                            'Cierre contable:',
                            ticket.closedAtText,
                          ),
                        _buildDetailRow(
                          'Canal de reserva:',
                          ticket.channel.toUpperCase(),
                        ),
                        _buildDetailRow(
                          'Duración total estimada:',
                          '${ticket.totalDurationMinutes} min',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Servicios y Estilista Card
                  _buildSectionCard(
                    title: 'Servicios y Equipo',
                    icon: Icons.content_cut_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Servicios:', ticket.serviceNames),
                        _buildDetailRow(
                          'Estilista asignado:',
                          ticket.stylistNames,
                        ),
                        if (onAddService != null ||
                            onManageServices != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (onAddService != null)
                                OutlinedButton.icon(
                                  onPressed: onAddService,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agregar servicio'),
                                ),
                              if (onManageServices != null)
                                OutlinedButton.icon(
                                  onPressed: onManageServices,
                                  icon: const Icon(
                                    Icons.tune_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Gestionar'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Finanzas y Pagos Card
                  _buildSectionCard(
                    title: 'Finanzas y Pagos',
                    icon: Icons.payments_outlined,
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Total servicios:',
                          ticket.formattedPrice,
                          isBold: true,
                        ),
                        _buildDetailRow(
                          'Total abonado:',
                          ticket.formattedPaidAmount,
                          color: AppColors.success,
                        ),
                        _buildDetailRow(
                          'Saldo pendiente:',
                          ticket.formattedBalanceAmount,
                          isBold: true,
                          color: ticket.hasPendingBalance
                              ? AppColors.stateToCollect
                              : AppColors.success,
                        ),
                        if (onManagePayments != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: onManagePayments,
                              icon: const Icon(Icons.payment_outlined),
                              label: Text(
                                ticket.isClosed ||
                                        (ticket.paidAmount > 0 &&
                                            !ticket.hasPendingBalance)
                                    ? 'Ver historial de pagos'
                                    : 'Registrar pago / Abono',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Galería de Fotos del Trabajo
                  _buildSectionCard(
                    title: 'Fotos del Trabajo',
                    icon: Icons.camera_alt_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registro visual del antes y después del servicio prestado.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (onAddWorkPhoto != null)
                          OutlinedButton.icon(
                            onPressed: onAddWorkPhoto,
                            icon: const Icon(
                              Icons.add_a_photo_outlined,
                              size: 16,
                            ),
                            label: const Text('Agregar foto del trabajo'),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Botonera de Acciones
                  const Text(
                    'Acciones del Ticket',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (onChangeStatus != null)
                        FilledButton.tonalIcon(
                          onPressed: onChangeStatus,
                          icon: const Icon(Icons.swap_horiz_outlined),
                          label: const Text('Cambiar estado'),
                        ),
                      if (onReschedule != null)
                        OutlinedButton.icon(
                          onPressed: onReschedule,
                          icon: const Icon(Icons.event_repeat_outlined),
                          label: const Text('Reprogramar'),
                        ),
                      if (onCorrectCompletion != null)
                        OutlinedButton.icon(
                          onPressed: onCorrectCompletion,
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text('Corregir finalización'),
                        ),
                      if (onCopyReviewLink != null)
                        OutlinedButton.icon(
                          onPressed: onCopyReviewLink,
                          icon: const Icon(Icons.link_outlined),
                          label: const Text('Copiar enlace de reseña'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
