import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_stylist_agenda_item.dart';
import '../models/stylist_time_off.dart';
import '../services/my_stylist_agenda_service.dart';
import '../services/stylist_time_off_service.dart';
import '../widgets/add_work_photo_dialog.dart';
import '../widgets/app_widgets.dart';
import '../widgets/create_time_off_dialog.dart';

class MyStylistAgendaPage extends StatefulWidget {
  const MyStylistAgendaPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<MyStylistAgendaPage> createState() => _MyStylistAgendaPageState();
}

class _MyStylistAgendaPageState extends State<MyStylistAgendaPage> {
  late final MyStylistAgendaService agendaService;
  late final StylistTimeOffService timeOffService;

  late DateTime selectedDate;
  late Future<List<MyStylistAgendaItem>> agendaFuture;
  late Future<List<StylistTimeOff>> timeOffFuture;

  @override
  void initState() {
    super.initState();
    agendaService = MyStylistAgendaService(branchId: widget.branchId);
    timeOffService = StylistTimeOffService(branchId: widget.branchId);
    selectedDate = DateUtils.dateOnly(DateTime.now());
    agendaFuture = agendaService.getMyStylistAgenda(selectedDate);
    timeOffFuture = timeOffService.getMyTimeOff();
  }

  void _refreshAgenda() {
    setState(() {
      agendaFuture = agendaService.getMyStylistAgenda(selectedDate);
    });
  }

  void _refreshTimeOff() {
    setState(() {
      timeOffFuture = timeOffService.getMyTimeOff();
    });
  }

  Future<void> _openCreateTimeOffDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => CreateTimeOffDialog(branchId: widget.branchId),
    );

    if (created != true || !mounted) return;

    _refreshTimeOff();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bloqueo de agenda creado.')),
    );
  }

  Future<void> _cancelTimeOff(StylistTimeOff timeOff) async {
    try {
      await timeOffService.cancelTimeOff(timeOff.id);
      _refreshTimeOff();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cancelar: $error')));
    }
  }

  void _changeDate(DateTime date) {
    setState(() {
      selectedDate = DateUtils.dateOnly(date);
      agendaFuture = agendaService.getMyStylistAgenda(selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      helpText: 'Selecciona el dia de la agenda',
      cancelText: 'Cancelar',
      confirmText: 'Ver agenda',
    );

    if (pickedDate != null) {
      _changeDate(pickedDate);
    }
  }

  Future<void> _updateServiceStatus(
    MyStylistAgendaItem item,
    String newStatus,
  ) async {
    try {
      final updated = await agendaService.changeTicketServiceStatus(
        ticketServiceId: item.ticketServiceId,
        newStatus: newStatus,
      );

      if (!mounted) {
        return;
      }

      if (!updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el servicio.')),
        );
        return;
      }

      final message = newStatus == 'en_proceso'
          ? 'Servicio iniciado correctamente.'
          : 'Servicio finalizado correctamente.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _refreshAgenda();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el servicio: $error')),
      );
    }
  }

  Future<void> _confirmAndUpdateServiceStatus(
    MyStylistAgendaItem item,
    String newStatus,
  ) async {
    if (newStatus == 'finalizado') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finalizar servicio'),
          content: Text(
            '¿Confirmas que terminaste ${item.serviceName} para '
            '${item.clientName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, finalizar'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    await _updateServiceStatus(item, newStatus);
  }

  Future<void> _openAddWorkPhotoDialog(MyStylistAgendaItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AddWorkPhotoDialog(
        branchId: widget.branchId,
        ticketId: item.ticketId,
      ),
    );

    if (saved != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto agregada correctamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mi agenda',
      subtitle: 'Citas y servicios asignados a tu usuario estilista.',
      children: [
        _TimeOffSection(
          timeOffFuture: timeOffFuture,
          onCreate: _openCreateTimeOffDialog,
          onCancel: _cancelTimeOff,
        ),
        const SizedBox(height: 18),
        _AgendaDateNavigator(
          selectedDate: selectedDate,
          onPreviousDay: () =>
              _changeDate(selectedDate.subtract(const Duration(days: 1))),
          onToday: () => _changeDate(DateTime.now()),
          onNextDay: () =>
              _changeDate(selectedDate.add(const Duration(days: 1))),
          onPickDate: _pickDate,
          onRefresh: _refreshAgenda,
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<MyStylistAgendaItem>>(
          future: agendaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No pudimos cargar tu agenda',
                description: snapshot.error.toString(),
              );
            }

            final items = snapshot.data ?? <MyStylistAgendaItem>[];

            if (items.isEmpty) {
              return InfoPanel(
                icon: Icons.event_busy_outlined,
                title: 'Sin citas ni solicitudes',
                description:
                    'No tienes servicios asignados para ${_formatLongDate(selectedDate)}.',
              );
            }

            final requestedItems = items
                .where((item) => item.ticketStatus == 'solicitado')
                .toList();
            final confirmedItems = items
                .where((item) => item.ticketStatus != 'solicitado')
                .toList();
            final totalValue = confirmedItems.fold<double>(
              0,
              (sum, item) => sum + item.price,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (requestedItems.isNotEmpty) ...[
                  const SectionTitle('Solicitudes pendientes de confirmación'),
                  const SizedBox(height: 6),
                  const Text(
                    'Estas solicitudes ya están asignadas a ti, pero administración todavía debe confirmarlas.',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 12),
                  _AgendaTable(
                    items: requestedItems,
                    onUpdateServiceStatus: _confirmAndUpdateServiceStatus,
                    onAddWorkPhoto: _openAddWorkPhotoDialog,
                  ),
                  const SizedBox(height: 24),
                ],
                if (confirmedItems.isNotEmpty) ...[
                  _AgendaSummary(
                    itemsCount: confirmedItems.length,
                    totalValue: totalValue,
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('Servicios confirmados'),
                  const SizedBox(height: 12),
                  _AgendaTable(
                    items: confirmedItems,
                    onUpdateServiceStatus: _confirmAndUpdateServiceStatus,
                    onAddWorkPhoto: _openAddWorkPhotoDialog,
                  ),
                ] else
                  InfoPanel(
                    icon: Icons.event_available_outlined,
                    title: 'Sin citas confirmadas',
                    description:
                        'Todavía no tienes servicios confirmados para ${_formatLongDate(selectedDate)}.',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AgendaDateNavigator extends StatelessWidget {
  const _AgendaDateNavigator({
    required this.selectedDate,
    required this.onPreviousDay,
    required this.onToday,
    required this.onNextDay,
    required this.onPickDate,
    required this.onRefresh,
  });

  final DateTime selectedDate;
  final VoidCallback onPreviousDay;
  final VoidCallback onToday;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(selectedDate, today);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Dia anterior',
              onPressed: onPreviousDay,
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_formatLongDate(selectedDate)),
            ),
            IconButton.outlined(
              tooltip: 'Dia siguiente',
              onPressed: onNextDay,
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton.icon(
              onPressed: isToday ? null : onToday,
              icon: const Icon(Icons.today_outlined),
              label: Text(isToday ? 'Hoy seleccionado' : 'Ir a hoy'),
            ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Actualizar agenda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOffSection extends StatelessWidget {
  const _TimeOffSection({
    required this.timeOffFuture,
    required this.onCreate,
    required this.onCancel,
  });

  final Future<List<StylistTimeOff>> timeOffFuture;
  final VoidCallback onCreate;
  final void Function(StylistTimeOff timeOff) onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bloqueos de mi agenda',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Bloquear agenda'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Cuando no puedas atender (vacaciones, incapacidad), bloquea '
              'ese rango: desaparece de tus horarios disponibles en todas '
              'tus sedes.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<StylistTimeOff>>(
              future: timeOffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'No pudimos cargar tus bloqueos: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  );
                }

                final items = snapshot.data ?? <StylistTimeOff>[];

                if (items.isEmpty) {
                  return const Text(
                    'No tienes bloqueos activos.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  );
                }

                return Column(
                  children: items
                      .map(
                        (timeOff) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.block_outlined,
                                size: 18,
                                color: Color(0xFF9A3412),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${timeOff.rangeText} · ${timeOff.reasonText}',
                                ),
                              ),
                              TextButton(
                                onPressed: () => onCancel(timeOff),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLongDate(DateTime date) {
  const weekdays = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return '${weekdays[date.weekday - 1]}, ${date.day} de '
      '${months[date.month - 1]} de ${date.year}';
}

class _AgendaSummary extends StatefulWidget {
  const _AgendaSummary({required this.itemsCount, required this.totalValue});

  final int itemsCount;
  final double totalValue;

  @override
  State<_AgendaSummary> createState() => _AgendaSummaryState();
}

class _AgendaSummaryState extends State<_AgendaSummary> {
  bool showMoney = false;

  @override
  Widget build(BuildContext context) {
    final amountText = showMoney ? _formatMoney(widget.totalValue) : '••••••';

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        MetricCard(
          title: 'Servicios',
          value: widget.itemsCount.toString(),
          description: 'Asignados a tu agenda',
          icon: Icons.event_available_outlined,
        ),
        SizedBox(
          width: 260,
          child: Card(
            elevation: 0,
            color: const Color(0xFFF5F3FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Valor servicios',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amountText,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Puedes ocultar o mostrar la cifra',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: showMoney ? 'Ocultar cifra' : 'Mostrar cifra',
                    onPressed: () {
                      setState(() {
                        showMoney = !showMoney;
                      });
                    },
                    icon: Icon(
                      showMoney
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatMoney(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;

      buffer.write(rounded[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }
}

class _AgendaTable extends StatelessWidget {
  const _AgendaTable({
    required this.items,
    required this.onUpdateServiceStatus,
    required this.onAddWorkPhoto,
  });

  final List<MyStylistAgendaItem> items;
  final Future<void> Function(MyStylistAgendaItem item, String newStatus)
  onUpdateServiceStatus;
  final Future<void> Function(MyStylistAgendaItem item) onAddWorkPhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Hora')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Servicio')),
            DataColumn(label: Text('Ticket')),
            DataColumn(label: Text('Servicio estado')),
            DataColumn(label: Text('Duracion')),
            DataColumn(label: Text('Valor')),
            DataColumn(label: Text('Notas')),
            DataColumn(label: Text('Acción')),
          ],
          rows: items
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item.scheduledDateText)),
                    DataCell(Text(item.scheduledTimeText)),
                    DataCell(Text(item.clientName)),
                    DataCell(Text(item.serviceName)),
                    DataCell(Text(item.ticketStatusText)),
                    DataCell(Text(item.serviceStatusText)),
                    DataCell(Text(item.durationText)),
                    DataCell(Text(item.formattedPrice)),
                    DataCell(Text(item.notesText)),
                    DataCell(
                      _ServiceActionButton(
                        item: item,
                        onUpdateServiceStatus: onUpdateServiceStatus,
                        onAddWorkPhoto: onAddWorkPhoto,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ServiceActionButton extends StatelessWidget {
  const _ServiceActionButton({
    required this.item,
    required this.onUpdateServiceStatus,
    required this.onAddWorkPhoto,
  });

  final MyStylistAgendaItem item;
  final Future<void> Function(MyStylistAgendaItem item, String newStatus)
  onUpdateServiceStatus;
  final Future<void> Function(MyStylistAgendaItem item) onAddWorkPhoto;

  @override
  Widget build(BuildContext context) {
    if (item.ticketStatus == 'solicitado') {
      return const Chip(
        avatar: Icon(Icons.hourglass_top_outlined, size: 18),
        label: Text('Esperando confirmación'),
      );
    }

    final canAddPhoto = {
      'en_proceso',
      'finalizado',
    }.contains(item.serviceStatus);

    Widget statusAction;
    switch (item.serviceStatus) {
      case 'pendiente':
        statusAction = FilledButton.icon(
          onPressed: () => onUpdateServiceStatus(item, 'en_proceso'),
          icon: const Icon(Icons.play_arrow_outlined),
          label: const Text('Iniciar'),
        );
      case 'en_proceso':
        statusAction = OutlinedButton.icon(
          onPressed: () => onUpdateServiceStatus(item, 'finalizado'),
          icon: const Icon(Icons.task_alt_outlined),
          label: const Text('Finalizar'),
        );
      default:
        statusAction = const Text('Sin acción');
    }

    if (!canAddPhoto) {
      return statusAction;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        statusAction,
        OutlinedButton.icon(
          onPressed: () => onAddWorkPhoto(item),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Agregar foto'),
        ),
      ],
    );
  }
}
