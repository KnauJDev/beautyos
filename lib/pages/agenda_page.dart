import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/acciones_de_ticket.dart';
import '../models/agenda_de_tres_estados.dart';
import '../models/mensaje_para_la_clienta.dart';
import '../models/ticket_board.dart';
import '../services/agenda_board_service.dart';
import '../services/tickets_service.dart';
import '../services/invitar_a_volver_service.dart';
import '../widgets/para_invitar_hoy.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/elegir_fecha.dart';

/// Construye el enlace de WhatsApp a partir de un teléfono de cliente.
///
/// wa.me espera solo dígitos **con código de país**, sin '+' (mismo criterio
/// que `public_plans_page.dart` y el soporte de Configuración).
///
/// **CK (03-oct): se le pone el 57 a un celular colombiano.** Desde D-249 los
/// celulares se guardan con sus diez dígitos y sin indicativo (`3506815620`),
/// y este enlace los mandaba tal cual: WhatsApp los leía como internacionales
/// (`350…` es Gibraltar) y no encontraba a nadie. Lo vio el propietario al
/// probar *Invitar a volver* (D-314). Le pasaba a todos los botones de
/// WhatsApp a personas: recordatorios, Clientes, invitaciones, el portal, la
/// reserva y el Panel. Un número que ya trae el 57 (o el '+') no se toca.
Uri buildWhatsAppUri(String phone, {String? text}) {
  var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanPhone.length == 10 && cleanPhone.startsWith('3')) {
    cleanPhone = '57$cleanPhone';
  }
  if (text != null && text.trim().isNotEmpty) {
    return Uri.https('wa.me', '/$cleanPhone', {'text': text.trim()});
  }
  return Uri.parse('https://wa.me/$cleanPhone');
}

/// Mensaje de recordatorio pre-armado para la tarjeta de cita de Agenda
/// (bloque de velocidad de mostrador): solo arma el texto, la persona sigue
/// pudiendo editarlo antes de enviarlo -- wa.me abre el chat con el texto
/// precargado, no lo manda solo.
String buildAppointmentReminderMessage({
  required String clientName,
  required String serviceNames,
  DateTime? scheduledAt,
  String? businessName,
}) {
  final hora = scheduledAt != null
      ? '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}'
      : 'la hora acordada';
  final negocio = businessName?.trim().isNotEmpty == true
      ? businessName!.trim()
      : 'nuestro salón';
  return 'Hola $clientName 👋, te recordamos tu cita de '
      '$serviceNames hoy a las $hora en $negocio.';
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

/// Alto de cada fila del tablero Día (I-20). Fijo, para poder saltar con
/// exactitud a la fila de la hora actual.
const double altoFilaTableroDia = 48;

/// I-20: la fila en la que cae [ahora] -- la última franja que ya empezó.
/// Antes de la primera franja, la primera; después de la última, la última.
/// [franjas] son "HH:MM" ordenadas, como las pinta el tablero.
int indiceDeLaHoraActual(List<String> franjas, DateTime ahora) {
  if (franjas.isEmpty) return 0;
  final actual =
      '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
  var indice = 0;
  for (var i = 0; i < franjas.length; i++) {
    if (franjas[i].compareTo(actual) <= 0) indice = i;
  }
  return indice;
}

/// BT: el aviso del tablero sabe decir el singular. Antes pegaba el número a
/// «tickets» sin mirar si era uno: «1 tickets pendientes».
///
/// D-312: con la agenda de tres estados no hay "cierre comercial" -- el
/// negocio no cobra en la app --, así que habla de citas sin cerrar.
String textoDePendientesDeCierre(int pendientes, {bool tresEstados = false}) {
  if (tresEstados) {
    return pendientes == 1 ? '1 cita sin cerrar' : '$pendientes citas sin cerrar';
  }
  return pendientes == 1
      ? '1 ticket pendiente de cierre comercial'
      : '$pendientes tickets pendientes de cierre comercial';
}

/// Las citas sin efecto del periodo, con su singular: decía "1 canceladas"
/// (03-oct, lo vio el propietario en el espejo de David).
String textoDeSinEfecto(int canceladas, int noAsistio) =>
    '${canceladas == 1 ? '1 cancelada' : '$canceladas canceladas'} · '
    '$noAsistio no asistió';

/// El subtítulo del tablero. D-312: la frase de siempre habla de cobro de
/// tickets, que a un negocio sin caja no le dice nada.
String subtituloDelTablero({required bool tresEstados}) => tresEstados
    ? 'Tus citas pasan de Confirmado a En proceso y a Cerrado. Al final del '
          'día, todas deberían quedar en Cerrado.'
    : 'Control de flujo y cobro de tickets. Regla del cero: al final de la '
          'jornada todas las columnas en 0 salvo Cerrado.';

/// El aviso verde de "todo en orden".
String textoDeJornadaAlDia({required bool tresEstados}) => tresEstados
    ? 'Jornada al día — todas las citas cerradas'
    : 'Jornada al día — Todas las columnas en cero salvo Cerrado';

/// Pantalla principal del Tablero de Agenda (D-101 / D-116 / D-147).
class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    required this.branchId,
    this.agendaService,
    this.businessName,
    this.onOpenTicket,
    this.onCollectTicket,
    this.reloj,
    this.tresEstados = false,
    this.ejecutarAccion,
    this.paraInvitar,
    this.esSedePrincipal = false,
  });

  /// D-314 (paso 4B): la tarjeta "Para invitar hoy" arriba del tablero. Solo
  /// la monta el shell (`main.dart`); sin ella, no hay tarjeta (las pruebas
  /// montan la agenda sin servidor).
  final InvitarAVolverService? paraInvitar;

  /// Para el enlace de la invitación (D-313).
  final bool esSedePrincipal;

  final String branchId;
  final AgendaBoardService? agendaService;

  /// D-312: el negocio tiene la caja apagada por la plataforma, y su agenda
  /// va Confirmado -> En proceso -> Cerrado, con los botones en la propia
  /// cita. Lo decide el shell (`main.dart`) con
  /// `TenantEntitlements.apagadoPorLaPlataforma(cajaYCobros)`.
  final bool tresEstados;

  /// Ejecuta un botón de la agenda de tres estados. Solo lo cambian las
  /// pruebas; por defecto llama al servidor con `TicketsService`.
  final Future<void> Function(
    TicketBoardItem cita,
    AccionDeTresEstados accion,
    String? motivo,
  )?
  ejecutarAccion;

  /// La hora "de ahora" (I-20). Solo lo cambian las pruebas, para que el
  /// tablero no dependa del reloj de la máquina donde corren.
  final DateTime Function()? reloj;

  /// Nombre del negocio (`BranchContext.tenantName`), para el mensaje de
  /// WhatsApp pre-armado de la tarjeta de cita.
  final String? businessName;

  /// Abre la Ficha Completa Nivel 3 de un ticket sin pasar por la pestaña de
  /// Tickets (D-163). Vive en el shell (`main.dart`), que es quien puede
  /// cambiar de pestaña y avisarle a `TicketsPage` cual ticket abrir.
  final void Function(String ticketId)? onOpenTicket;

  /// Abre el diálogo de pago del ticket directo, sin pasar por la Ficha
  /// Completa (bloque de velocidad de mostrador). Igual que [onOpenTicket],
  /// vive en el shell.
  final void Function(String ticketId)? onCollectTicket;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final AgendaBoardService _service;
  RealtimeChannel? _realtimeChannel;

  AgendaViewMode _viewMode = AgendaViewMode.dia;
  late DateTime _selectedDate = _ahora();
  // I-18 (decisión del propietario, 29-sep): siempre abre en «Cada 1 hora».
  // Con 15 minutos el día eran 56 filas y había que buscar la cita.
  String _granularity = 'hour'; // '15min', '30min', 'hour'

  /// I-20: el tablero Día se desplaza por dentro, con los encabezados fijos,
  /// y al abrir el día de HOY salta a la hora actual.
  final ScrollController _scrollDia = ScrollController();

  DateTime _ahora() => (widget.reloj ?? DateTime.now)();
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
    _scrollDia.dispose();
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
        // I-20: solo en una carga que pidió la persona (abrir, cambiar de
        // fecha o de intervalo). La recarga silenciosa de tiempo real no la
        // mueve de donde esté mirando.
        if (!silent) _saltarAHoraActual();
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
      _selectedDate = _ahora();
    });
    _loadData();
  }

  /// I-20 (decisión del propietario, 29-sep): en la vista Día de HOY, la
  /// fila de la hora actual queda la primera visible. Otro día, arriba.
  void _saltarAHoraActual() {
    if (_viewMode != AgendaViewMode.dia) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollDia.hasClients) return;
      final ahora = _ahora();
      final esHoy =
          _selectedDate.year == ahora.year &&
          _selectedDate.month == ahora.month &&
          _selectedDate.day == ahora.day;
      final indice = esHoy ? indiceDeLaHoraActual(_franjasDelDia(), ahora) : 0;
      final destino = (indice * altoFilaTableroDia).clamp(
        0.0,
        _scrollDia.position.maxScrollExtent,
      );
      _scrollDia.jumpTo(destino);
    });
  }

  Future<void> _seleccionarFechaCalendario() async {
    // CJ: al tocar el día queda elegido, sin "OK".
    final picked = await elegirFechaDeUnToque(
      context,
      fechaInicial: _selectedDate,
      primeraFecha: DateTime(2025, 1, 1),
      ultimaFecha: DateTime(2030, 12, 31),
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
          businessName: widget.businessName,
          onOpenTicket: widget.onOpenTicket,
          onCollectTicket: widget.onCollectTicket,
          tresEstados: widget.tresEstados,
          ejecutarAccion: widget.tresEstados ? _ejecutarAccion : null,
        );
      },
    );
  }

  /// D-312: las columnas que pinta el tablero.
  List<ColumnaDeAgenda> get _columnasDia =>
      ColumnaDeAgenda.delDia(tresEstados: widget.tresEstados);
  /// El selector Día / Semana / Mes en una pantalla de celular (D-317).
  bool _selectorAngosto(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 420;

  List<ColumnaDeAgenda> get _columnasSemana =>
      ColumnaDeAgenda.deLaSemana(tresEstados: widget.tresEstados);

  /// D-312: lo que hace un botón de la agenda de tres estados. Lee los
  /// servicios de la cita, arma los pasos (`AgendaDeTresEstados.pasos`) y los
  /// da en orden con las funciones de siempre, que dejan su historial y no
  /// tocan dinero. Al terminar recarga el tablero.
  Future<void> _ejecutarAccion(
    TicketBoardItem cita,
    AccionDeTresEstados accion,
    String? motivo,
  ) async {
    final propio = widget.ejecutarAccion;
    if (propio != null) {
      await propio(cita, accion, motivo);
    } else {
      final tickets = TicketsService(branchId: widget.branchId);
      final servicios = await tickets.getTicketServicesForManagement(cita.id);
      final pasos = AgendaDeTresEstados.pasos(
        accion,
        estadoDelTicket: cita.status,
        servicios: [
          for (final s in servicios)
            (id: s.ticketServiceId, estado: s.serviceStatus),
        ],
        motivo: motivo,
      );
      for (final paso in pasos) {
        if (paso.esDelTicket) {
          await tickets.changeTicketStatus(
            ticketId: cita.id,
            newStatus: paso.nuevoEstado,
            reason: paso.motivo,
          );
        } else {
          await tickets.changeTicketServiceStatus(
            ticketServiceId: paso.servicioId!,
            newStatus: paso.nuevoEstado,
          );
        }
      }
    }
    if (mounted) await _loadData(silent: true);
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

    // Sumatoria de regla del cero (todas las columnas salvo Cerrado). D-312:
    // en la agenda de tres estados, "finalizado" ya es Cerrado.
    final int pendientesCierre = _counts
        .where(
          (c) => widget.tresEstados
              ? AgendaDeTresEstados.pendienteAlFinalDelDia(c.status)
              : c.status != 'cerrado' &&
                    c.status != 'cancelado' &&
                    c.status != 'no_asistio',
        )
        .fold(0, (sum, c) => sum + c.ticketCount);

    return AppPage(
      title: 'Tablero de Agenda',
      subtitle: subtituloDelTablero(tresEstados: widget.tresEstados),
      children: [
        if (widget.paraInvitar != null)
          ParaInvitarHoyCard(
            servicio: widget.paraInvitar!,
            nombreDelSalon: widget.businessName,
            esSedePrincipal: widget.esSedePrincipal,
          ),
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
                  // Selector de modo de vista (Día / Semana / Mes).
                  // Paso 5 (D-317): en el celular "Semana" se partía en dos
                  // renglones. Angosto, sin íconos ni chulo, y el texto en
                  // una sola línea.
                  SegmentedButton<AgendaViewMode>(
                    showSelectedIcon: !_selectorAngosto(context),
                    segments: [
                      ButtonSegment(
                        value: AgendaViewMode.dia,
                        label: const Text('Día', maxLines: 1, softWrap: false),
                        icon: _selectorAngosto(context)
                            ? null
                            : const Icon(Icons.view_day_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AgendaViewMode.semana,
                        label: const Text('Semana', maxLines: 1, softWrap: false),
                        icon: _selectorAngosto(context)
                            ? null
                            : const Icon(Icons.view_week_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AgendaViewMode.mes,
                        label: const Text('Mes', maxLines: 1, softWrap: false),
                        icon: _selectorAngosto(context)
                            ? null
                            : const Icon(Icons.calendar_month_outlined, size: 18),
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
                        ? textoDeJornadaAlDia(tresEstados: widget.tresEstados)
                        : textoDePendientesDeCierre(
                            pendientesCierre,
                            tresEstados: widget.tresEstados,
                          ),
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
                    'Sin efecto (${textoDeSinEfecto(canceladas, noAsistio)})',
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
                    textoDeSinEfecto(canceladas, noAsistio),
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

  /// Las franjas del día: las del intervalo elegido, más las de cualquier
  /// cita fuera de 08:00-20:00. Una sola fuente para pintar y para saltar a
  /// la hora actual (I-20).
  List<String> _franjasDelDia() {
    final List<String> timeSlots = _generateTimeSlots(_granularity);
    for (final c in _counts) {
      if (c.bucket.isNotEmpty && !timeSlots.contains(c.bucket)) {
        timeSlots.add(c.bucket);
      }
    }
    timeSlots.sort();
    return timeSlots;
  }

  Widget _buildDayView() {
    final List<String> timeSlots = _franjasDelDia();
    // I-20: el tablero ocupa el alto de la pantalla y se desplaza por
    // dentro, así los encabezados de las columnas no se pierden al bajar.
    final double altoTablero = (MediaQuery.sizeOf(context).height * 0.62).clamp(
      320.0,
      900.0,
    );

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
                ..._columnasDia.map(
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

          // Filas por tramo de tiempo. Alto fijo por fila (itemExtent) para
          // poder saltar con exactitud a la hora actual (I-20).
          SizedBox(
            height: altoTablero,
            child: Scrollbar(
              controller: _scrollDia,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollDia,
                itemExtent: altoFilaTableroDia,
                itemCount: timeSlots.length,
                itemBuilder: (context, index) {
                  final slot = timeSlots[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
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
                        ..._columnasDia.map((col) {
                          final count = _counts
                              .where(
                                (c) =>
                                    c.bucket == slot && col.contiene(c.status),
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
            ),
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
                ..._columnasSemana.map(
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
                      ..._columnasSemana.map((col) {
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
                      tresEstados: widget.tresEstados,
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
  final ColumnaDeAgenda column;
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

  /// D-312: en la agenda de tres estados, lo terminado es Cerrado (gris) y
  /// lo que nacio por confirmar es Confirmado (verde): no hay ambar ni coral.
  final bool tresEstados;

  const _MonthProportionBar({
    required this.dayCounts,
    required this.total,
    this.tresEstados = false,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    if (tresEstados) {
      int contar(List<String> estados) => dayCounts
          .where((c) => estados.contains(c.status))
          .fold(0, (sum, c) => sum + c.ticketCount);
      final partes = [
        for (final col in ColumnaDeAgenda.deTresEstados)
          (contar(col.estados), col.color),
      ];
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 4,
          child: Row(
            children: [
              for (final (n, color) in partes)
                if (n > 0)
                  Expanded(flex: n, child: Container(color: color)),
            ],
          ),
        ),
      );
    }

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

class _Level2Sheet extends StatefulWidget {
  final AgendaBoardService service;
  final String titulo;
  final DateTime startDate;
  final DateTime endDate;
  final List<String>? statuses;
  final String? bucket;
  final String? granularity;
  final String? businessName;
  final void Function(String ticketId)? onOpenTicket;
  final void Function(String ticketId)? onCollectTicket;

  /// D-312: agenda de tres estados. La cita lleva sus botones y no enseña
  /// montos: este negocio no cobra en la app.
  final bool tresEstados;
  final Future<void> Function(
    TicketBoardItem cita,
    AccionDeTresEstados accion,
    String? motivo,
  )?
  ejecutarAccion;

  const _Level2Sheet({
    required this.service,
    required this.titulo,
    required this.startDate,
    required this.endDate,
    this.statuses,
    this.bucket,
    this.granularity,
    this.businessName,
    this.onOpenTicket,
    this.onCollectTicket,
    this.tresEstados = false,
    this.ejecutarAccion,
  });

  @override
  State<_Level2Sheet> createState() => _Level2SheetState();
}

class _Level2SheetState extends State<_Level2Sheet> {
  late Future<List<TicketBoardItem>> _boardListFuture;

  /// D-312: la cita cuyo botón se está ejecutando, para no pulsarlo dos veces.
  String? _ocupada;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _boardListFuture = widget.service.getBoardList(
      startDate: widget.startDate,
      endDate: widget.endDate,
      statuses: widget.statuses,
      bucket: widget.bucket,
      granularity: widget.granularity,
    );
  }

  /// D-312: un botón de la agenda de tres estados. Cancelar y No asistió
  /// piden el motivo antes, porque el servidor lo exige y queda en el
  /// historial de la cita.
  ///
  /// **Si sale bien, la hoja se cierra** y el aviso se ve sobre el tablero,
  /// que ya se recargó. Antes se quedaba abierta y, como la cita ya no
  /// pertenecía a esa casilla, decía *"Sin tickets en esta sección"*: parecía
  /// un error sin serlo, y el aviso quedaba escondido detrás de la hoja (lo
  /// vio el propietario el 03-oct en el espejo de David). **Si falla**, el
  /// motivo sale en una ventana encima de la hoja, para que se lea.
  Future<void> _alPulsar(TicketBoardItem cita, AccionDeTresEstados accion) async {
    final ejecutar = widget.ejecutarAccion;
    if (ejecutar == null || _ocupada != null) return;

    String? motivo;
    if (accion.pideMotivo) {
      motivo = await pedirMotivoDeLaCita(context, accion);
      if (motivo == null || !mounted) return;
    }

    final avisos = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _ocupada = cita.id);
    try {
      await ejecutar(cita, accion, motivo);
      navegador.pop();
      avisos.showSnackBar(
        SnackBar(content: Text(avisoDeAccionHecha(accion, cita.clientName))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ocupada = null;
        _cargar();
      });
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('No se pudo'),
          content: Text(mensajeParaLaClienta(error)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _abrirWhatsApp(String phone, String message) async {
    final uri = buildWhatsAppUri(phone, text: message);
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
                        widget.titulo,
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
                  future: _boardListFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const ErrorState(
                        titulo: 'No se pudieron cargar los tickets',
                        detalle:
                            'Revisa tu conexión a internet o intenta nuevamente más tarde.',
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
                          tresEstados: widget.tresEstados,
                          acciones: widget.ejecutarAccion == null
                              ? const []
                              : AgendaDeTresEstados.acciones(item.status),
                          ocupada: _ocupada == item.id,
                          onAccion: (accion) => _alPulsar(item, accion),
                          onWhatsAppTap: item.clientPhone.isNotEmpty
                              ? () => _abrirWhatsApp(
                                  item.clientPhone,
                                  buildAppointmentReminderMessage(
                                    clientName: item.clientName,
                                    serviceNames: item.serviceNames,
                                    scheduledAt: item.scheduledAt,
                                    businessName: widget.businessName,
                                  ),
                                )
                              : null,
                          onTap: widget.onOpenTicket != null
                              ? () {
                                  Navigator.of(context).pop();
                                  widget.onOpenTicket!(item.id);
                                }
                              : null,
                          onCollectTap:
                              widget.onCollectTicket != null &&
                                  item.pendingBalance > 0 &&
                                  AccionesDeTicket.puedeGestionarPagos(
                                    item.status,
                                  )
                              ? () {
                                  Navigator.of(context).pop();
                                  widget.onCollectTicket!(item.id);
                                }
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
  final VoidCallback? onTap;
  final VoidCallback? onCollectTap;

  /// D-312: agenda de tres estados.
  final bool tresEstados;
  final List<AccionDeTresEstados> acciones;
  final bool ocupada;
  final void Function(AccionDeTresEstados accion)? onAccion;

  const _TicketCardNivel2({
    required this.item,
    this.onWhatsAppTap,
    this.onTap,
    this.onCollectTap,
    this.tresEstados = false,
    this.acciones = const [],
    this.ocupada = false,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final String timeStr = item.scheduledAt != null
        ? '${item.scheduledAt!.hour.toString().padLeft(2, '0')}:${item.scheduledAt!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
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
                  StatusPill(
                    status: tresEstados
                        ? AgendaDeTresEstados.comoSeMuestra(item.status)
                        : item.ticketStatus,
                  ),
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

          // D-312: en la agenda de tres estados, en vez del dinero, los
          // botones de la cita.
          if (tresEstados)
            _BotonesDeLaCita(
              acciones: acciones,
              ocupada: ocupada,
              onAccion: onAccion,
            )
          else
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

          // Botón de cobro primario: abre el diálogo de pago directo, sin
          // pasar por la Ficha Completa (bloque de velocidad de mostrador).
          if (onCollectTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCollectTap,
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text('Cobrar ${formatCOP(item.pendingBalance)}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// D-312: los botones de una cita en la agenda de tres estados.
class _BotonesDeLaCita extends StatelessWidget {
  const _BotonesDeLaCita({
    required this.acciones,
    required this.ocupada,
    this.onAccion,
  });

  final List<AccionDeTresEstados> acciones;
  final bool ocupada;
  final void Function(AccionDeTresEstados accion)? onAccion;

  @override
  Widget build(BuildContext context) {
    if (acciones.isEmpty) return const SizedBox.shrink();
    if (ocupada) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: LinearProgressIndicator(),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final accion in acciones)
          switch (accion) {
            AccionDeTresEstados.iniciar => FilledButton.tonalIcon(
              onPressed: () => onAccion?.call(accion),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(accion.etiqueta),
            ),
            AccionDeTresEstados.cerrar => FilledButton.icon(
              onPressed: () => onAccion?.call(accion),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(accion.etiqueta),
            ),
            _ => TextButton(
              onPressed: () => onAccion?.call(accion),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(accion.etiqueta),
            ),
          },
      ],
    );
  }
}

/// D-312: lo que se le dice a quien pulsó el botón, cuando salió bien.
String avisoDeAccionHecha(AccionDeTresEstados accion, String cliente) =>
    switch (accion) {
      AccionDeTresEstados.iniciar => 'La cita de $cliente está en proceso.',
      AccionDeTresEstados.cerrar => 'La cita de $cliente quedó cerrada.',
      AccionDeTresEstados.cancelar => 'La cita de $cliente quedó cancelada.',
      AccionDeTresEstados.noAsistio =>
        'Quedó anotado que $cliente no asistió.',
    };

/// D-312: el motivo de Cancelar o No asistió. Devuelve `null` si la persona
/// se arrepiente; el botón de confirmar no se habilita con el motivo vacío,
/// porque el servidor lo rechazaría.
Future<String?> pedirMotivoDeLaCita(
  BuildContext context,
  AccionDeTresEstados accion,
) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogo) => StatefulBuilder(
      builder: (dialogo, setDialogState) {
        final motivo = controller.text.trim();
        return AlertDialog(
          title: Text(
            accion == AccionDeTresEstados.cancelar
                ? '¿Cancelar la cita?'
                : '¿Marcar que no asistió?',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Por ejemplo: avisó que no podía venir',
            ),
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: motivo.isEmpty
                  ? null
                  : () => Navigator.of(dialogo).pop(motivo),
              child: Text(accion.etiqueta),
            ),
          ],
        );
      },
    ),
  );
}
