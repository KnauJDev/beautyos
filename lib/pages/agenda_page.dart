import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket_board.dart';
import '../services/agenda_board_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Construye el enlace de WhatsApp a partir de un teléfono de cliente.
///
/// wa.me espera solo dígitos con código de país, sin '+' (mismo criterio que
/// `public_plans_page.dart` y el soporte de Configuración) — aunque en este
/// proyecto los teléfonos se guardan con '+', ese carácter se descarta aquí.
Uri buildWhatsAppUri(String phone, {String? text}) {
  final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (text != null && text.trim().isNotEmpty) {
    return Uri.https('wa.me', '/$cleanPhone', {'text': text.trim()});
  }
  return Uri.parse('https://wa.me/$cleanPhone');
}

/// Modos de vista del Tablero de Agenda (D-101 / D-116).
enum AgendaViewMode {
  dia(titulo: 'Día'),
  semana(titulo: 'Semana'),
  mes(titulo: 'Mes');

  final String titulo;
  const AgendaViewMode({required this.titulo});
}

/// Nombres de los meses en español.
const List<String> _meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Nombres cortos de los días de la semana (Lunes = 1 en Dart DateTime).
const List<String> _diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Pantalla principal del Tablero de Agenda (D-101 / D-116 / D-147).
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.branchId, this.agendaService});

  final String branchId;
  final AgendaBoardService? agendaService;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final AgendaBoardService _service;
  RealtimeChannel? _realtimeChannel;

  AgendaViewMode _viewMode = AgendaViewMode.dia;
  DateTime _selectedDate = DateTime.now();
  String _granularity = '15min'; // '15min', '30min', 'hour'
  bool _isLoading = false;
  String? _errorMessage;
  List<TicketBoardCount> _counts = [];

  @override
  void initState() {
    super.initState();
    _service =
        widget.agendaService ?? AgendaBoardService(branchId: widget.branchId);
    _loadData();
    _setupRealtime();
  }

  @override
  void didUpdateWidget(covariant AgendaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _realtimeChannel?.unsubscribe();
      _loadData();
      _setupRealtime();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = _service.subscribeToTickets(
      onTicketChanged: () {
        if (mounted) {
          _loadData(silent: true);
        }
      },
    );
  }

  DateTime _mondayOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  DateTime _sundayOfWeek(DateTime date) {
    return _mondayOfWeek(date).add(const Duration(days: 6));
  }

  DateTime _firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      DateTime start;
      DateTime end;
      String gran;

      switch (_viewMode) {
        case AgendaViewMode.dia:
          start = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          );
          end = start;
          gran = _granularity;
          break;
        case AgendaViewMode.semana:
          start = _mondayOfWeek(_selectedDate);
          end = _sundayOfWeek(_selectedDate);
          gran = 'day';
          break;
        case AgendaViewMode.mes:
          start = _firstDayOfMonth(_selectedDate);
          end = _lastDayOfMonth(_selectedDate);
          gran = 'day';
          break;
      }

      final results = await _service.getBoardCounts(
        startDate: start,
        endDate: end,
        granularity: gran,
      );

      if (mounted) {
        setState(() {
          _counts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _cambiarFecha(int delta) {
    setState(() {
      switch (_viewMode) {
        case AgendaViewMode.dia:
          _selectedDate = _selectedDate.add(Duration(days: delta));
          break;
        case AgendaViewMode.semana:
          _selectedDate = _selectedDate.add(Duration(days: delta * 7));
          break;
        case AgendaViewMode.mes:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + delta,
            1,
          );
          break;
      }
    });
    _loadData();
  }

  void _irAHoy() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadData();
  }

  Future<void> _seleccionarFechaCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      locale: const Locale('es', 'CO'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  String _tituloPeriodo() {
    switch (_viewMode) {
      case AgendaViewMode.dia:
        final diaSem = _diasSemana[_selectedDate.weekday - 1];
        final mes = _meses[_selectedDate.month - 1];
        return '$diaSem, ${_selectedDate.day} de $mes ${_selectedDate.year}';
      case AgendaViewMode.semana:
        final mon = _mondayOfWeek(_selectedDate);
        final sun = _sundayOfWeek(_selectedDate);
        final mesMon = _meses[mon.month - 1];
        final mesSun = _meses[sun.month - 1];
        if (mon.month == sun.month) {
          return 'Semana del ${mon.day} al ${sun.day} de $mesMon ${mon.year}';
        }
        return 'Semana del ${mon.day} $mesMon al ${sun.day} $mesSun ${sun.year}';
      case AgendaViewMode.mes:
        final mes = _meses[_selectedDate.month - 1];
        return '$mes ${_selectedDate.year}';
    }
  }

  /// Abre la lista de Nivel 2 al hacer clic en una casilla o badge (D-101 / D-116).
  void _abrirListaNivel2({
    required String titulo,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? statuses,
    String? bucket,
    String? granularity,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _Level2Sheet(
          service: _service,
          titulo: titulo,
          startDate: startDate,
          endDate: endDate,
          statuses: statuses,
          bucket: bucket,
          granularity: granularity,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDia = _viewMode == AgendaViewMode.dia;
    final int canceladas = _counts
        .where((c) => c.status == 'cancelado')
        .fold(0, (sum, c) => sum + c.ticketCount);
    final int noAsistio = _counts
        .where((c) => c.status == 'no_asistio')
        .fold(0, (sum, c) => sum + c.ticketCount);

    // Sumatoria de regla del cero (todas las columnas salvo Cerrado)
    final int pendientesCierre = _counts
        .where(
          (c) =>
              c.status != 'cerrado' &&
              c.status != 'cancelado' &&
              c.status != 'no_asistio',
        )
        .fold(0, (sum, c) => sum + c.ticketCount);

    return AppPage(
      title: 'Tablero de Agenda',
      subtitle:
          'Control de flujo y cobro de tickets. Regla del cero: al final de la jornada todas las columnas en 0 salvo Cerrado.',
      children: [
        // Barra de Control Superior
        _buildControlBar(isDia),
        const SizedBox(height: AppSpacing.md),

        // Banner Resumen de Cierre y Cancelaciones (D-101)
        _buildSummaryBanner(
          pendientesCierre: pendientesCierre,
          canceladas: canceladas,
          noAsistio: noAsistio,
        ),
        const SizedBox(height: AppSpacing.md),

        // Estado de carga o error
        if (_isLoading)
          const LoadingCard(mensaje: 'Actualizando tablero de agenda...')
        else if (_errorMessage != null)
          ErrorState(
            titulo: 'No se pudo cargar el tablero',
            detalle: _errorMessage!,
            onReintentar: _loadData,
          )
        else
          // Contenido de la vista según el modo
          switch (_viewMode) {
            AgendaViewMode.dia => _buildDayView(),
            AgendaViewMode.semana => _buildWeekView(),
            AgendaViewMode.mes => _buildMonthView(),
          },
      ],
    );
  }

  Widget _buildControlBar(bool isDia) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  // Selector de modo de vista (Día / Semana / Mes)
                  SegmentedButton<AgendaViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: AgendaViewMode.dia,
                        label: Text('Día'),
                        icon: Icon(Icons.view_day_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AgendaViewMode.semana,
                        label: Text('Semana'),
                        icon: Icon(Icons.view_week_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AgendaViewMode.mes,
                        label: Text('Mes'),
                        icon: Icon(Icons.calendar_month_outlined, size: 18),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (set) {
                      setState(() {
                        _viewMode = set.first;
                      });
                      _loadData();
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Granularidad en vista Día (15 min / 30 min / 1 hora)
                  if (isDia)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Intervalos:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _granularity,
                          underline: const SizedBox.shrink(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandDeep,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: '15min',
                              child: Text('Cada 15 min'),
                            ),
                            DropdownMenuItem(
                              value: '30min',
                              child: Text('Cada 30 min'),
                            ),
                            DropdownMenuItem(
                              value: 'hour',
                              child: Text('Cada 1 hora'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null && val != _granularity) {
                              setState(() {
                                _granularity = val;
                              });
                              _loadData();
                            }
                          },
                        ),
                      ],
                    ),

                  // Botón de refresco manual
                  IconButton(
                    onPressed: () => _loadData(),
                    tooltip: 'Actualizar tablero',
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.md),

              // Selector de Fecha
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _irAHoy,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          _viewMode == AgendaViewMode.dia
                              ? 'Hoy'
                              : (_viewMode == AgendaViewMode.semana
                                    ? 'Esta semana'
                                    : 'Este mes'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _cambiarFecha(-1),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Anterior',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () => _cambiarFecha(1),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Siguiente',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _seleccionarFechaCalendario,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tituloPeriodo(),
                            style: TextStyle(
                              fontSize: isNarrow ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBanner({
    required int pendientesCierre,
    required int canceladas,
    required int noAsistio,
  }) {
    final bool alDia = pendientesCierre == 0;

    return Row(
      children: [
        // Indicador de la regla del cero
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: alDia
                  ? AppColors.stateConfirmedTint
                  : AppColors.statePendingTint,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color:
                    (alDia ? AppColors.stateConfirmed : AppColors.statePending)
                        .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  alDia
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: alDia
                      ? AppColors.stateConfirmed
                      : AppColors.statePending,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alDia
                        ? 'Jornada al día — Todas las columnas en cero salvo Cerrado'
                        : '$pendientesCierre tickets pendientes de cierre comercial',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: alDia
                          ? AppColors.stateConfirmed
                          : AppColors.statePending,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Contador de Canceladas y No Asistió (D-101)
        if (canceladas > 0 || noAsistio > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: () {
              DateTime start;
              DateTime end;
              switch (_viewMode) {
                case AgendaViewMode.dia:
                  start = _selectedDate;
                  end = _selectedDate;
                  break;
                case AgendaViewMode.semana:
                  start = _mondayOfWeek(_selectedDate);
                  end = _sundayOfWeek(_selectedDate);
                  break;
                case AgendaViewMode.mes:
                  start = _firstDayOfMonth(_selectedDate);
                  end = _lastDayOfMonth(_selectedDate);
                  break;
              }
              _abrirListaNivel2(
                titulo:
                    'Sin efecto ($canceladas canceladas, $noAsistio no asistió)',
                startDate: start,
                endDate: end,
                statuses: ['cancelado', 'no_asistio'],
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$canceladas canceladas · $noAsistio no asistió',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // VISTA DÍA (D-101 / D-147)
  // ===========================================================================

  Widget _buildDayView() {
    // Generar franjas de tiempo según la granularidad
    final List<String> timeSlots = _generateTimeSlots(_granularity);

    // Asegurarse de incluir buckets con citas fuera del rango 08:00 a 20:00
    for (final c in _counts) {
      if (c.bucket.isNotEmpty && !timeSlots.contains(c.bucket)) {
        timeSlots.add(c.bucket);
      }
    }
    timeSlots.sort();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Encabezado de Columnas del Día (D-101)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 70,
                  child: Text(
                    'HORA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                ...DayBoardColumn.values.map(
                  (col) => Expanded(
                    child: Tooltip(
                      message: col.subtitulo,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            col.titulo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: col.color,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filas por tramo de tiempo
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeSlots.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final slot = timeSlots[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        slot,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ...DayBoardColumn.values.map((col) {
                      final count = _counts
                          .where(
                            (c) => c.bucket == slot && col.contiene(c.status),
                          )
                          .fold(0, (sum, c) => sum + c.ticketCount);

                      return Expanded(
                        child: _DayGridCell(
                          count: count,
                          column: col,
                          onTap: count == 0
                              ? null
                              : () {
                                  _abrirListaNivel2(
                                    titulo:
                                        '$slot · ${col.titulo} (${_selectedDate.day} de ${_meses[_selectedDate.month - 1]})',
                                    startDate: _selectedDate,
                                    endDate: _selectedDate,
                                    statuses: col.estados,
                                    bucket: slot,
                                    granularity: _granularity,
                                  );
                                },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<String> _generateTimeSlots(String gran) {
    final List<String> slots = [];
    int stepMinutes = 15;
    if (gran == '30min') stepMinutes = 30;
    if (gran == 'hour') stepMinutes = 60;

    int totalMinutes = 8 * 60; // 08:00
    final int endMinutes = 20 * 60; // 20:00

    while (totalMinutes <= endMinutes) {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      final strH = h.toString().padLeft(2, '0');
      final strM = m.toString().padLeft(2, '0');
      slots.add('$strH:$strM');
      totalMinutes += stepMinutes;
    }
    return slots;
  }

  // ===========================================================================
  // VISTA SEMANA (D-101)
  // ===========================================================================

  Widget _buildWeekView() {
    final monday = _mondayOfWeek(_selectedDate);
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header de columnas de semana (6 columnas discriminadas)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'DÍA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                ...WeekBoardColumn.values.map(
                  (col) => Expanded(
                    child: Text(
                      col.titulo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: col.color,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7 Filas de Lunes a Domingo
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final dayDate = days[index];
              final strDate =
                  '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
              final isToday =
                  dayDate.year == today.year &&
                  dayDate.month == today.month &&
                  dayDate.day == today.day;
              // Días pasados se atenúan; hoy y los futuros se ven normales (D-101).
              final isPast = dayDate.isBefore(
                DateTime(today.year, today.month, today.day),
              );

              return Opacity(
                opacity: isPast ? 0.55 : 1.0,
                child: Container(
                  color: isToday ? AppColors.brandSurface : null,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _diasSemana[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isToday
                                    ? AppColors.brand
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${dayDate.day} ${_meses[dayDate.month - 1].substring(0, 3)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...WeekBoardColumn.values.map((col) {
                        final count = _counts
                            .where(
                              (c) =>
                                  c.bucket == strDate && col.contiene(c.status),
                            )
                            .fold(0, (sum, c) => sum + c.ticketCount);

                        return Expanded(
                          child: _WeekGridCell(
                            count: count,
                            color: col.color,
                            onTap: count == 0
                                ? null
                                : () {
                                    _abrirListaNivel2(
                                      titulo:
                                          '${_diasSemana[index]} ${dayDate.day} · ${col.titulo}',
                                      startDate: dayDate,
                                      endDate: dayDate,
                                      statuses: col.estados,
                                      bucket: strDate,
                                      granularity: 'day',
                                    );
                                  },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VISTA MES (D-101)
  // ===========================================================================

  Widget _buildMonthView() {
    final firstDay = _firstDayOfMonth(_selectedDate);
    final lastDay = _lastDayOfMonth(_selectedDate);
    final int leadingEmptyDays = firstDay.weekday - 1; // Lunes = 1
    final int totalDays = lastDay.day;
    final today = DateTime.now();

    final List<Widget> dayCells = [];

    // Celdas vacías del mes anterior
    for (int i = 0; i < leadingEmptyDays; i++) {
      dayCells.add(
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      );
    }

    // Celdas de los días del mes
    for (int d = 1; d <= totalDays; d++) {
      final date = DateTime(_selectedDate.year, _selectedDate.month, d);
      final strDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      // Días pasados se atenúan; hoy y los futuros se ven normales (D-101).
      final isPast = date.isBefore(
        DateTime(today.year, today.month, today.day),
      );

      final dayCounts = _counts.where((c) => c.bucket == strDate).toList();
      final totalTickets = dayCounts.fold(0, (sum, c) => sum + c.ticketCount);

      dayCells.add(
        Opacity(
          opacity: isPast ? 0.55 : 1.0,
          child: InkWell(
            onTap: () {
              // Tocar un día en el mes lleva a la vista Día de esa fecha (D-101)
              setState(() {
                _selectedDate = date;
                _viewMode = AgendaViewMode.dia;
              });
              _loadData();
            },
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isToday ? AppColors.brandSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(
                  color: isToday ? AppColors.brand : AppColors.border,
                  width: isToday ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$d',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isToday
                              ? AppColors.brand
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (totalTickets > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalTickets',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandDeep,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (totalTickets > 0)
                    _MonthProportionBar(
                      dayCounts: dayCounts,
                      total: totalTickets,
                    )
                  else
                    const Center(
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          // Días de la semana header
          Row(
            children: const [
              Expanded(child: _MonthHeaderDay('LUN')),
              Expanded(child: _MonthHeaderDay('MAR')),
              Expanded(child: _MonthHeaderDay('MIÉ')),
              Expanded(child: _MonthHeaderDay('JUE')),
              Expanded(child: _MonthHeaderDay('VIE')),
              Expanded(child: _MonthHeaderDay('SÁB')),
              Expanded(child: _MonthHeaderDay('DOM')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Grid de días
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.1,
            children: dayCells,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPONENTES AUXILIARES DEL TABLERO
// =============================================================================

class _MonthHeaderDay extends StatelessWidget {
  final String label;
  const _MonthHeaderDay(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _DayGridCell extends StatelessWidget {
  final int count;
  final DayBoardColumn column;
  final VoidCallback? onTap;

  const _DayGridCell({required this.count, required this.column, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Center(
        child: Text(
          '·',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: column.colorFondo,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: column.color.withValues(alpha: 0.4)),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: column.color,
          ),
        ),
      ),
    );
  }
}

class _WeekGridCell extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _WeekGridCell({required this.count, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Center(
        child: Text(
          '·',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _MonthProportionBar extends StatelessWidget {
  final List<TicketBoardCount> dayCounts;
  final int total;

  const _MonthProportionBar({required this.dayCounts, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    final cerrados = dayCounts
        .where((c) => c.status == 'cerrado')
        .fold(0, (sum, c) => sum + c.ticketCount);
    final confirmados = dayCounts
        .where((c) => c.status == 'confirmado' || c.status == 'en_espera')
        .fold(0, (sum, c) => sum + c.ticketCount);
    final enProceso = dayCounts
        .where((c) => c.status == 'en_proceso')
        .fold(0, (sum, c) => sum + c.ticketCount);
    final porCobrar = dayCounts
        .where((c) => c.status == 'finalizado')
        .fold(0, (sum, c) => sum + c.ticketCount);
    final porConfirmar = dayCounts
        .where(
          (c) =>
              c.status == 'solicitado' ||
              c.status == 'cotizado' ||
              c.status == 'apartado',
        )
        .fold(0, (sum, c) => sum + c.ticketCount);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: Row(
          children: [
            if (cerrados > 0)
              Expanded(
                flex: cerrados,
                child: Container(color: AppColors.stateClosed),
              ),
            if (confirmados > 0)
              Expanded(
                flex: confirmados,
                child: Container(color: AppColors.stateConfirmed),
              ),
            if (enProceso > 0)
              Expanded(
                flex: enProceso,
                child: Container(color: AppColors.stateInProgress),
              ),
            if (porCobrar > 0)
              Expanded(
                flex: porCobrar,
                child: Container(color: AppColors.stateToCollect),
              ),
            if (porConfirmar > 0)
              Expanded(
                flex: porConfirmar,
                child: Container(color: AppColors.statePending),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL DE NIVEL 2: LISTA AMPLIADA DE TICKETS (D-101 / D-116 / D-147)
// =============================================================================

class _Level2Sheet extends StatelessWidget {
  final AgendaBoardService service;
  final String titulo;
  final DateTime startDate;
  final DateTime endDate;
  final List<String>? statuses;
  final String? bucket;
  final String? granularity;

  const _Level2Sheet({
    required this.service,
    required this.titulo,
    required this.startDate,
    required this.endDate,
    this.statuses,
    this.bucket,
    this.granularity,
  });

  Future<void> _abrirWhatsApp(String phone) async {
    final uri = buildWhatsAppUri(phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
          ),
          child: Column(
            children: [
              // Barra de agarre
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Encabezado del modal
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDeep,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Contenido con FutureBuilder
              Expanded(
                child: FutureBuilder<List<TicketBoardItem>>(
                  future: service.getBoardList(
                    startDate: startDate,
                    endDate: endDate,
                    statuses: statuses,
                    bucket: bucket,
                    granularity: granularity,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ErrorState(
                        titulo: 'No se pudieron cargar los tickets',
                        detalle: snapshot.error.toString(),
                      );
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          titulo: 'Sin tickets en esta sección',
                          descripcion:
                              'No se encontraron citas o tickets con este filtro.',
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _TicketCardNivel2(
                          item: item,
                          onWhatsAppTap: item.clientPhone.isNotEmpty
                              ? () => _abrirWhatsApp(item.clientPhone)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketCardNivel2 extends StatelessWidget {
  final TicketBoardItem item;
  final VoidCallback? onWhatsAppTap;

  const _TicketCardNivel2({required this.item, this.onWhatsAppTap});

  @override
  Widget build(BuildContext context) {
    final String timeStr = item.scheduledAt != null
        ? '${item.scheduledAt!.hour.toString().padLeft(2, '0')}:${item.scheduledAt!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Consecutivo #0000701, StatusPill y Hora
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Chip Consecutivo Operativo (D-117)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      item.ticketCode.isNotEmpty
                          ? item.ticketCode
                          : '#${item.ticketNumber ?? "---"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Chip Consecutivo Contable de Venta (D-150 / Hallazgo P)
                  if (item.saleCode != null && item.saleCode!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stateConfirmedTint,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: AppColors.stateConfirmed),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 12,
                            color: AppColors.stateConfirmed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.saleCode!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stateConfirmed,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  StatusPill(status: item.ticketStatus),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Fila 2: Nombre del cliente y Botón WhatsApp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (onWhatsAppTap != null)
                InkWell(
                  onTap: onWhatsAppTap,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(
                        color: AppColors.whatsapp.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: AppColors.whatsapp,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.clientPhone,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.whatsapp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Fila 3: Servicios y Estilistas
          Text(
            '✂️ ${item.serviceNames} · 👤 ${item.stylistNames}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: AppSpacing.md),

          // Fila 4: Dinero (Total, Pagado, Saldo pendiente)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${formatCOP(item.totalPrice)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (item.paidAmount > 0)
                Text(
                  'Abonado: ${formatCOP(item.paidAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              Text(
                item.pendingBalance > 0
                    ? 'Saldo: ${formatCOP(item.pendingBalance)}'
                    : 'Pagado total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: item.pendingBalance > 0
                      ? AppColors.stateToCollect
                      : AppColors.stateConfirmed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
