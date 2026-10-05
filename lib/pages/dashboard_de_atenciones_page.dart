import 'package:flutter/material.dart';

import '../models/branch_context.dart';
import '../models/dashboard_de_atenciones.dart';
import '../models/invitacion_a_volver.dart';
import '../models/periodo_dashboard.dart';
import '../services/dashboard_service.dart';
import '../services/invitar_a_volver_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/graficos_de_atenciones.dart';
import 'dashboard_page.dart' show ControlesDelDashboard, sedesDelDashboard;

/// El Dashboard de atenciones (paso 5 del plan de David, D-317).
///
/// El de los negocios con la caja apagada: cuenta la historia del negocio en
/// **citas, clientas, servicios y equipo**, sin un solo peso. Sale del
/// prototipo que aprobó el propietario el 04-oct
/// (https://claude.ai/artifact/Ptnrpy3N23NbSATn2n3BP3), con las mismas
/// preguntas en el mismo orden. Tocar un servicio o una estilista filtra todo
/// el tablero, como en Power BI.
///
/// Los negocios con caja siguen con `DashboardPage` (D-311).
class DashboardDeAtencionesPage extends StatefulWidget {
  const DashboardDeAtencionesPage({
    super.key,
    required this.branchId,
    this.branches = const <BranchContext>[],
    this.paraInvitar,
    this.onIrAAgenda,
    this.onIrAClientes,
  });

  final String branchId;

  /// Las sedes que se pueden consultar. Con una sola, no hay selector.
  final List<BranchContext> branches;

  /// La lista de Invitar a volver (D-314), la misma de la Agenda y Clientes.
  final InvitarAVolverService? paraInvitar;

  final VoidCallback? onIrAAgenda;
  final VoidCallback? onIrAClientes;

  @override
  State<DashboardDeAtencionesPage> createState() =>
      _DashboardDeAtencionesPageState();
}

class _DashboardDeAtencionesPageState extends State<DashboardDeAtencionesPage> {
  late final DashboardService _servicio;
  PeriodoDashboard _periodo = PeriodoDashboard.esteMes;
  bool _consolidado = false;
  ({String id, String nombre})? _estilista;
  ({String id, String nombre})? _servicioElegido;
  late Future<ResumenDeAtenciones> _datos;
  Future<List<InvitacionAVolver>>? _invitaciones;

  @override
  void initState() {
    super.initState();
    _servicio = DashboardService(branchId: widget.branchId);
    _cargar();
    _invitaciones = widget.paraInvitar?.listar();
  }

  void _cargar() {
    _datos = _servicio.getAtenciones(
      periodo: _periodo,
      branchIds: sedesDelDashboard(
        consolidado: _consolidado,
        branchId: widget.branchId,
      ),
      estilistaId: _estilista?.id,
      servicioId: _servicioElegido?.id,
    );
  }

  void _cambiar(VoidCallback cambio) {
    setState(() {
      cambio();
      _cargar();
    });
  }

  void _tocarEstilista(EstilistaAtendiendo e) => _cambiar(() {
    _estilista = _estilista?.id == e.id ? null : (id: e.id, nombre: e.nombre);
  });

  void _tocarServicio(ServicioAtendido s) => _cambiar(() {
    _servicioElegido =
        _servicioElegido?.id == s.id ? null : (id: s.id, nombre: s.nombre);
  });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Dashboard',
      subtitle: 'La historia de tu negocio, en citas y clientas.',
      children: [
        FutureBuilder<ResumenDeAtenciones>(
          future: _datos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LoadingCard(mensaje: 'Contando tus citas...');
            }
            if (snapshot.hasError) {
              return ErrorState(
                titulo: 'No se pudo cargar el Dashboard',
                detalle:
                    'Revisa tu conexión a internet o intenta nuevamente más tarde.',
                onReintentar: () => _cambiar(() {}),
              );
            }
            return TableroDeAtenciones(
              resumen: snapshot.data!,
              periodo: _periodo,
              branches: widget.branches,
              consolidado: _consolidado,
              estilista: _estilista,
              servicio: _servicioElegido,
              invitaciones: _invitaciones,
              onPeriodo: (p) => _cambiar(() => _periodo = p),
              onAmbito: (c) => _cambiar(() => _consolidado = c),
              onTocarEstilista: _tocarEstilista,
              onTocarServicio: _tocarServicio,
              onQuitarEstilista: () => _cambiar(() => _estilista = null),
              onQuitarServicio: () => _cambiar(() => _servicioElegido = null),
              onIrAAgenda: widget.onIrAAgenda,
              onIrAClientes: widget.onIrAClientes,
            );
          },
        ),
      ],
    );
  }
}

/// El tablero ya cargado, sin consultas: lo que dibuja
/// [DashboardDeAtencionesPage] cuando llegan los datos.
///
/// Es público para poder dibujarlo en una prueba con datos de ejemplo, a lo
/// ancho de un celular y de un computador, sin sesión de Supabase de por
/// medio (la lección de D-203 y D-204).
class TableroDeAtenciones extends StatelessWidget {
  const TableroDeAtenciones({
    super.key,
    required this.resumen,
    required this.periodo,
    this.branches = const <BranchContext>[],
    this.consolidado = false,
    this.estilista,
    this.servicio,
    this.invitaciones,
    required this.onPeriodo,
    required this.onAmbito,
    required this.onTocarEstilista,
    required this.onTocarServicio,
    required this.onQuitarEstilista,
    required this.onQuitarServicio,
    this.onIrAAgenda,
    this.onIrAClientes,
  });

  final ResumenDeAtenciones resumen;
  final PeriodoDashboard periodo;
  final List<BranchContext> branches;
  final bool consolidado;

  /// Los filtros puestos al tocar una estilista o un servicio.
  final ({String id, String nombre})? estilista;
  final ({String id, String nombre})? servicio;

  final Future<List<InvitacionAVolver>>? invitaciones;
  final ValueChanged<PeriodoDashboard> onPeriodo;
  final ValueChanged<bool> onAmbito;
  final ValueChanged<EstilistaAtendiendo> onTocarEstilista;
  final ValueChanged<ServicioAtendido> onTocarServicio;
  final VoidCallback onQuitarEstilista;
  final VoidCallback onQuitarServicio;
  final VoidCallback? onIrAAgenda;
  final VoidCallback? onIrAClientes;

  @override
  Widget build(BuildContext context) {
    final r = resumen;
    final d = r.datos;
    final sinNada = d.actual.atendidas == 0 &&
        d.actual.perdidas == 0 &&
        d.anterior.atendidas == 0 &&
        d.hoy.citas == 0 &&
        estilista == null &&
        servicio == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ControlesDelDashboard(
          periodo: periodo,
          hoy: d.hoyEnLaSede,
          branches: branches,
          consolidado: consolidado,
          onPeriodo: onPeriodo,
          onAmbito: (c) {
            if (c != consolidado) onAmbito(c);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (estilista != null || servicio != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (estilista != null)
                  _ChipDeFiltro(
                    texto: 'Solo ${estilista!.nombre}',
                    onQuitar: onQuitarEstilista,
                  ),
                if (servicio != null)
                  _ChipDeFiltro(
                    texto: 'Solo ${servicio!.nombre}',
                    onQuitar: onQuitarServicio,
                  ),
                Text(
                  'Todo el tablero está filtrado. Toca ✕ para quitarlo.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        if (sinNada)
          const _SinCitasTodavia()
        else ...[
          _Historia(resumen: r, periodo: periodo, estilista: estilista?.nombre, servicio: servicio?.nombre),
          const SizedBox(height: AppSpacing.lg),
          _Hoy(
            hoy: d.hoy,
            fecha: d.hoyEnLaSede,
            invitaciones: invitaciones,
            onVerLista: onIrAAgenda,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Indicadores(datos: d),
          const SizedBox(height: AppSpacing.lg),
          _Rejilla(
            pares: [
              (_Cuando(resumen: r), _AQueHora(datos: d)),
              (
                _QuePiden(datos: d, elegido: servicio?.id, filtroEstilista: estilista?.nombre, onTocar: onTocarServicio),
                _QuienAtiende(datos: d, elegida: estilista?.id, filtroServicio: servicio?.nombre, onTocar: onTocarEstilista),
              ),
              (
                _PorDondeLlegan(datos: d),
                _Vuelven(
                  datos: d,
                  invitaciones: invitaciones,
                  filtrado: estilista != null || servicio != null,
                  onIrAClientes: onIrAClientes,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _QueSePerdio(datos: d),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas
// ---------------------------------------------------------------------------

class _ChipDeFiltro extends StatelessWidget {
  const _ChipDeFiltro({required this.texto, required this.onQuitar});

  final String texto;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(texto, style: TextStyle(color: AppColors.textOnBrand, fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.brand,
      deleteIconColor: AppColors.textOnBrand,
      onDeleted: onQuitar,
      onPressed: onQuitar,
      deleteButtonTooltipMessage: 'Quitar el filtro',
    );
  }
}

/// Dos tarjetas por fila en pantalla ancha; una debajo de otra en el celular.
class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.pares});

  final List<(Widget, Widget)> pares;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth >= 860;
        return Column(
          children: [
            for (final (a, b) in pares)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                // Sin IntrinsicHeight a propósito: el gráfico de barras usa
                // LayoutBuilder, que no sabe medir su alto intrínseco.
                child: ancho
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: a),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: b),
                        ],
                      )
                    : Column(
                        children: [a, const SizedBox(height: AppSpacing.lg), b],
                      ),
              ),
          ],
        );
      },
    );
  }
}

/// Una tarjeta con su pregunta, su respuesta en palabras, el gráfico y de
/// dónde sale el número.
class _Pregunta extends StatelessWidget {
  const _Pregunta({
    required this.pregunta,
    this.aclaracion,
    this.respuesta,
    required this.hijos,
    this.deDondeSale,
  });

  final String pregunta;
  final String? aclaracion;
  final Widget? respuesta;
  final List<Widget> hijos;
  final String? deDondeSale;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(pregunta, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (aclaracion != null)
                Text(aclaracion!, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
          if (respuesta != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: respuesta!),
          ],
          const SizedBox(height: AppSpacing.md),
          ...hijos,
          if (deDondeSale != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            Text(deDondeSale!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Un texto con trozos resaltados en negrita y en el color del tema.
Widget _respuesta(List<TrozoDeHistoria> trozos, {Color? resalte, Color? normal}) {
  return Text.rich(
    TextSpan(
      children: [
        for (final t in trozos)
          TextSpan(
            text: t.texto,
            style: TextStyle(
              fontWeight: t.resaltado ? FontWeight.w800 : FontWeight.w400,
              color: t.resaltado ? (resalte ?? AppColors.brandDark) : normal,
            ),
          ),
      ],
    ),
  );
}

List<TrozoDeHistoria> _trozos(List<Object> partes) => [
  for (final p in partes)
    p is _R ? (texto: p.texto, resaltado: true) : (texto: p.toString(), resaltado: false),
];

/// Un trozo resaltado dentro de `_trozos`.
class _R {
  const _R(this.texto);
  final String texto;
}

class _Variacion extends StatelessWidget {
  const _Variacion({
    required this.actual,
    required this.anterior,
    this.puntos = false,
    this.subirEsMalo = false,
  });

  final num actual;
  final num anterior;

  /// Para porcentajes: la diferencia en puntos, no en por ciento.
  final bool puntos;

  /// Para lo perdido: que suba es mala noticia.
  final bool subirEsMalo;

  @override
  Widget build(BuildContext context) {
    final int? v = puntos
        ? (actual - anterior).round()
        : variacion(actual, anterior);
    if (v == null || (puntos && anterior == 0 && actual == 0)) {
      return _pildora('sin comparación', AppColors.textSecondary, AppColors.surfaceAlt);
    }
    final bueno = subirEsMalo ? v < 0 : v > 0;
    final color = v == 0 ? AppColors.textSecondary : (bueno ? AppColors.success : AppColors.danger);
    final fondo = v == 0 ? AppColors.surfaceAlt : (bueno ? AppColors.successTint : AppColors.dangerTint);
    final flecha = v > 0 ? '▲' : v < 0 ? '▼' : '=';
    return _pildora('$flecha ${v.abs()}${puntos ? ' pts' : ' %'}', color, fondo);
  }

  Widget _pildora(String texto, Color color, Color fondo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
    child: Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
  );
}

class _SinCitasTodavia extends StatelessWidget {
  const _SinCitasTodavia();

  @override
  Widget build(BuildContext context) {
    return const InfoPanel(
      icon: Icons.insights_outlined,
      title: 'Todavía no hay citas que contar',
      description:
          'Cuando cierres tus primeras citas en la Agenda, aquí verás la '
          'historia de tu negocio: cuántas atendiste, qué te piden, quién '
          'atiende más y cuándo vienen. Prueba también con otro periodo.',
    );
  }
}

// ---------------------------------------------------------------------------
// La historia
// ---------------------------------------------------------------------------

class _Historia extends StatelessWidget {
  const _Historia({
    required this.resumen,
    required this.periodo,
    this.estilista,
    this.servicio,
  });

  final ResumenDeAtenciones resumen;
  final PeriodoDashboard periodo;
  final String? estilista;
  final String? servicio;

  @override
  Widget build(BuildContext context) {
    final d = resumen.datos;
    final nombre = periodo.etiqueta.toLowerCase();
    final trozos = historiaDelPeriodo(
      d,
      periodo: nombre,
      desde: resumen.rango.desde,
      hasta: resumen.rango.hasta,
      estilista: estilista,
      servicio: servicio,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.brandDeep,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LA HISTORIA DE ${nombre.toUpperCase()}',
            style: TextStyle(
              color: AppColors.brandTint,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            titularDelPeriodo(d.actual),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 15, height: 1.6),
            child: _respuesta(trozos, resalte: AppColors.brandTint, normal: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoy
// ---------------------------------------------------------------------------

class _Hoy extends StatelessWidget {
  const _Hoy({
    required this.hoy,
    required this.fecha,
    required this.invitaciones,
    this.onVerLista,
  });

  final HoyDeAtenciones hoy;
  final DateTime fecha;
  final Future<List<InvitacionAVolver>>? invitaciones;
  final VoidCallback? onVerLista;

  @override
  Widget build(BuildContext context) {
    const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    Widget dato(int n, String texto) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.brandTintSoft,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(texto, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

    return _Pregunta(
      pregunta: 'Hoy, ${diasDeLaSemana[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1]}',
      aclaracion: 'no cambia con el periodo',
      hijos: [
        LayoutBuilder(
          builder: (context, c) {
            final datos = [
              dato(hoy.citas, 'Citas de hoy'),
              dato(hoy.cerradas, 'Cerradas'),
              dato(hoy.enProceso, 'En proceso'),
              dato(hoy.porAtender, 'Por atender'),
            ];
            if (c.maxWidth < 420) {
              return Column(
                children: [
                  Row(children: [datos[0], const SizedBox(width: 8), datos[1]]),
                  const SizedBox(height: 8),
                  Row(children: [datos[2], const SizedBox(width: 8), datos[3]]),
                ],
              );
            }
            return Row(
              children: [
                for (var k = 0; k < datos.length; k++) ...[
                  if (k > 0) const SizedBox(width: 8),
                  datos[k],
                ],
              ],
            );
          },
        ),
        if (invitaciones != null)
          FutureBuilder<List<InvitacionAVolver>>(
            future: invitaciones,
            builder: (context, s) {
              final n = clientasDe((s.data ?? const <InvitacionAVolver>[]).where((f) => f.tocaHoy)).length;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Para invitar hoy: $n ${n == 1 ? 'clienta' : 'clientas'}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Ya les toca volver según el tiempo de su servicio.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (onVerLista != null)
                        FilledButton(onPressed: onVerLista, child: const Text('Ver lista')),
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

// ---------------------------------------------------------------------------
// ¿Cómo me fue?
// ---------------------------------------------------------------------------

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.datos});

  final DashboardDeAtenciones datos;

  @override
  Widget build(BuildContext context) {
    final a = datos.actual, b = datos.anterior;
    final tarjetas = <Widget>[
      _Indicador(
        titulo: 'Citas atendidas',
        valor: miles(a.atendidas),
        variacion: _Variacion(actual: a.atendidas, anterior: b.atendidas),
        tendencia: datos.serie.map((p) => p.atendidas).toList(),
      ),
      _Indicador(
        titulo: 'Clientas atendidas',
        valor: miles(a.clientas),
        variacion: _Variacion(actual: a.clientas, anterior: b.clientas),
      ),
      _Indicador(
        titulo: 'Clientas nuevas',
        valor: miles(a.nuevas),
        variacion: _Variacion(actual: a.nuevas, anterior: b.nuevas),
      ),
      _Indicador(
        titulo: 'Asistencia',
        valor: a.asistencia == null ? '—' : '${a.asistencia} %',
        variacion: (a.asistencia == null || b.asistencia == null)
            ? const _Variacion(actual: 0, anterior: 0)
            : _Variacion(actual: a.asistencia!, anterior: b.asistencia!, puntos: true),
      ),
      _Indicador(
        titulo: 'Horas de trabajo',
        valor: miles(a.horas),
        variacion: _Variacion(actual: a.minutos, anterior: b.minutos),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Cómo me fue?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(
          'contra el periodo anterior',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, c) {
            final columnas = c.maxWidth >= 860 ? 5 : (c.maxWidth >= 520 ? 3 : 2);
            final ancho = (c.maxWidth - (columnas - 1) * 10) / columnas;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
            );
          },
        ),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.titulo,
    required this.valor,
    required this.variacion,
    this.tendencia,
  });

  final String titulo;
  final String valor;
  final Widget variacion;
  final List<num>? tendencia;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 4),
          variacion,
          if (tendencia != null) ...[
            const SizedBox(height: 6),
            LineaDeTendencia(valores: tendencia!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ¿Cuándo vienen? y ¿A qué hora?
// ---------------------------------------------------------------------------

class _Cuando extends StatelessWidget {
  const _Cuando({required this.resumen});

  final ResumenDeAtenciones resumen;

  @override
  Widget build(BuildContext context) {
    final d = resumen.datos;
    final promedios = d.promedioPorDiaDeLaSemana(resumen.rango.desde, resumen.rango.hasta);
    final orden = promedios.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    final hay = orden.isNotEmpty && orden.first.value > 0 && orden.length > 1;
    final unidad = d.granularidad == 'day'
        ? 'por día'
        : d.granularidad == 'week'
        ? 'por semana'
        : 'por mes';

    return _Pregunta(
      pregunta: '¿Cuándo vienen?',
      aclaracion: 'citas atendidas $unidad',
      respuesta: hay
          ? _respuesta(_trozos([
              'El ',
              _R(diasDeLaSemana[orden.first.key - 1]),
              ' es tu día más fuerte (unas ${orden.first.value.round()} citas); el ',
              _R(diasDeLaSemana[orden.last.key - 1]),
              ', el más flojo.',
            ]))
          : null,
      hijos: [
        BarrasConComparacion(
          actual: d.serie,
          anterior: d.serieAnterior,
          granularidad: d.granularidad,
          hoy: d.hoyEnLaSede,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 16,
          children: [
            _Leyenda(color: AppColors.brand, texto: 'Este periodo'),
            _Leyenda(color: AppColors.textMuted, texto: 'El anterior', punteada: true),
            if (d.granularidad == 'day') _Leyenda(color: AppColors.brandDark, texto: 'Sábados'),
          ],
        ),
      ],
      deDondeSale:
          'Cuenta las citas cerradas: en tu negocio, cerrada quiere decir atendida, no pagada.',
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto, this.punteada = false});

  final Color color;
  final String texto;
  final bool punteada;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: punteada ? 16 : 12,
          height: punteada ? 2 : 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(punteada ? 0 : 3),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _AQueHora extends StatelessWidget {
  const _AQueHora({required this.datos});

  final DashboardDeAtenciones datos;

  @override
  Widget build(BuildContext context) {
    final pico = datos.horaPico;
    return _Pregunta(
      pregunta: '¿A qué hora?',
      aclaracion: 'día de la semana × hora',
      respuesta: pico == null
          ? null
          : _respuesta(_trozos([
              'La hora pico es el ',
              _R('${diasDeLaSemana[pico.diaSemana - 1]} de ${horaHablada(pico.hora)} a ${horaHablada(pico.hora + 1)}'),
              '. Ahí conviene tener a todo el equipo.',
            ])),
      hijos: [MapaDeCalor(celdas: datos.calor)],
      deDondeSale:
          'Más claro, menos citas; más color, más citas. Toca un cuadro para ver el número.',
    );
  }
}

// ---------------------------------------------------------------------------
// ¿Qué piden? y ¿Quién atiende?
// ---------------------------------------------------------------------------

class _QuePiden extends StatelessWidget {
  const _QuePiden({
    required this.datos,
    required this.elegido,
    required this.filtroEstilista,
    required this.onTocar,
  });

  final DashboardDeAtenciones datos;
  final String? elegido;
  final String? filtroEstilista;
  final ValueChanged<ServicioAtendido> onTocar;

  @override
  Widget build(BuildContext context) {
    final lista = datos.servicios;
    final total = lista.fold<int>(0, (t, s) => t + s.atenciones);
    final maximo = lista.isEmpty ? 1 : lista.first.atenciones;
    final masHoras = lista.isEmpty
        ? null
        : (List.of(lista)..sort((a, b) => b.minutos.compareTo(a.minutos))).first;
    final categorias = <String, int>{};
    for (final s in lista) {
      final c = s.categoria?.trim();
      if (c != null && c.isNotEmpty) categorias[c] = (categorias[c] ?? 0) + s.atenciones;
    }
    final catTop = categorias.entries.isEmpty
        ? null
        : (categorias.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    return _Pregunta(
      pregunta: '¿Qué piden?',
      aclaracion: 'atenciones por servicio${filtroEstilista == null ? '' : ' · $filtroEstilista'}',
      respuesta: lista.isEmpty
          ? const Text('Sin atenciones en este periodo.')
          : _respuesta(_trozos([
              _R(lista.first.nombre),
              ' es lo más pedido (${porcentaje(lista.first.atenciones, total)} %).',
              if (catTop != null) ...[' Por categoría manda ', _R(catTop.key), '.'],
              if (masHoras != null) ...[
                ' Lo que más horas ocupa es ',
                _R(masHoras.nombre),
                ' (${miles(masHoras.minutos / 60)} h).',
              ],
            ])),
      hijos: [
        for (final s in lista)
          RenglonDeRanking(
            titulo: s.nombre,
            detalle: [if (s.categoria != null && s.categoria!.trim().isNotEmpty) s.categoria!, '${s.duracion} min'].join(' · '),
            valor: miles(s.atenciones),
            extra: '${porcentaje(s.atenciones, total)} %',
            fraccion: s.atenciones / maximo,
            seleccionado: elegido == s.id,
            atenuado: elegido != null && elegido != s.id,
            onTap: () => onTocar(s),
          ),
      ],
      deDondeSale:
          'Toca un servicio para ver todo el tablero solo con él. Cuenta cada servicio de las citas cerradas, sin precios.',
    );
  }
}

class _QuienAtiende extends StatelessWidget {
  const _QuienAtiende({
    required this.datos,
    required this.elegida,
    required this.filtroServicio,
    required this.onTocar,
  });

  final DashboardDeAtenciones datos;
  final String? elegida;
  final String? filtroServicio;
  final ValueChanged<EstilistaAtendiendo> onTocar;

  @override
  Widget build(BuildContext context) {
    final lista = datos.equipo;
    final maximo = lista.isEmpty ? 1 : lista.first.citas;
    final masNuevas = lista.length < 2
        ? null
        : (List.of(lista)..sort((a, b) => porcentaje(b.nuevas, b.citas).compareTo(porcentaje(a.nuevas, a.citas)))).first;

    return _Pregunta(
      pregunta: '¿Quién atiende?',
      aclaracion: 'citas por estilista${filtroServicio == null ? '' : ' · $filtroServicio'}',
      respuesta: lista.isEmpty
          ? const Text('Nadie atendió en este periodo.')
          : _respuesta(_trozos([
              _R(lista.first.nombre),
              ' lleva más citas (${miles(lista.first.citas)}).',
              if (masNuevas != null && masNuevas.nuevas > 0) ...[
                ' ',
                _R(masNuevas.nombre),
                ' es quien más recibe clientas nuevas (${porcentaje(masNuevas.nuevas, masNuevas.citas)} % de las suyas).',
              ],
            ])),
      hijos: [
        for (final e in lista)
          RenglonDeRanking(
            inicial: e.nombre.trim().isEmpty ? '?' : e.nombre.trim()[0].toUpperCase(),
            titulo: e.nombre,
            valor: miles(e.citas),
            fraccion: e.citas / maximo,
            seleccionado: elegida == e.id,
            atenuado: elegida != null && elegida != e.id,
            onTap: () => onTocar(e),
            datos: [
              '${miles(e.minutos / 60)} h de trabajo',
              '${porcentaje(e.nuevas, e.citas)} % nuevas',
              '${porcentaje(e.enLinea, e.citas)} % en línea',
              if (e.calificacion != null)
                '★ ${e.calificacion!.toStringAsFixed(1).replaceAll('.', ',')} (${e.resenas})',
            ].join('  ·  '),
          ),
      ],
      deDondeSale:
          'Toca una persona para ver el tablero solo con sus citas. Las estrellas salen de las reseñas de sus citas del periodo.',
    );
  }
}

// ---------------------------------------------------------------------------
// ¿Por dónde llegan? y ¿Vuelven?
// ---------------------------------------------------------------------------

class _PorDondeLlegan extends StatelessWidget {
  const _PorDondeLlegan({required this.datos});

  final DashboardDeAtenciones datos;

  @override
  Widget build(BuildContext context) {
    final a = datos.actual, b = datos.anterior;
    Widget dato(String t, String v, {Color? marca, Widget? extra}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (marca != null) ...[
            Container(width: 10, height: 10, decoration: BoxDecoration(color: marca, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(t, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (extra != null) ...[const SizedBox(width: 6), extra],
        ],
      ),
    );

    return _Pregunta(
      pregunta: '¿Por dónde llegan?',
      aclaracion: 'en línea contra el salón',
      hijos: [
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DonaEnLinea(enLinea: a.enLinea, total: a.atendidas),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                children: [
                  dato('Por tu enlace', miles(a.enLinea), marca: AppColors.brand),
                  dato('En el salón o por teléfono', miles(a.atendidas - a.enLinea), marca: AppColors.brandDeep),
                  dato(
                    'Antes',
                    '${porcentaje(b.enLinea, b.atendidas)} %',
                    extra: _Variacion(
                      actual: porcentaje(a.enLinea, a.atendidas),
                      anterior: porcentaje(b.enLinea, b.atendidas),
                      puntos: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      deDondeSale:
          '"En línea" son las citas que nacieron en tu página. Cada vez que compartes tu enlace, este número sube.',
    );
  }
}

class _Vuelven extends StatelessWidget {
  const _Vuelven({
    required this.datos,
    required this.invitaciones,
    required this.filtrado,
    this.onIrAClientes,
  });

  final DashboardDeAtenciones datos;
  final Future<List<InvitacionAVolver>>? invitaciones;
  final bool filtrado;
  final VoidCallback? onIrAClientes;

  @override
  Widget build(BuildContext context) {
    final a = datos.actual;
    final enviadas = datos.invitacionesEnviadas;
    final agendaron = datos.invitacionesAgendaron;

    Widget paso(String texto, String valor, double fraccion, Color color, {Color? letra}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
              Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: fraccion.clamp(0.04, 1).toDouble(),
            child: Container(height: 22, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7))),
          ),
        ],
      ),
    );

    return _Pregunta(
      pregunta: '¿Vuelven?',
      aclaracion: 'clientas por semana',
      respuesta: a.clientas == 0
          ? null
          : _respuesta(_trozos([
              'De ${miles(a.clientas)} clientas atendidas, ',
              _R('${porcentaje(a.vuelven, a.clientas)} %'),
              ' ya habían venido antes.',
              if (!filtrado && enviadas > 0) ...[
                ' De ${miles(enviadas)} invitadas a volver, ',
                _R(miles(agendaron)),
                ' agendaron otra vez (${porcentaje(agendaron, enviadas)} %).',
              ],
            ])),
      hijos: [
        SemanasApiladas(semanas: datos.semanas),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 16,
          children: [
            _Leyenda(color: AppColors.brand, texto: 'Volvieron'),
            _Leyenda(color: AppColors.brandDeep, texto: 'Nuevas'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<InvitacionAVolver>>(
          future: invitaciones,
          builder: (context, s) {
            final filas = s.data ?? const <InvitacionAVolver>[];
            final noVolvieron = clientasDe(filas.where((f) => f.invitadaSinVolver)).length;
            final maximo = [enviadas, agendaron, noVolvieron].fold<int>(1, (m, v) => v > m ? v : m);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                paso('Invitadas en el periodo', miles(enviadas), enviadas / maximo, AppColors.brand.withValues(alpha: 0.55)),
                paso('Agendaron después de la invitación', '${miles(agendaron)} · ${porcentaje(agendaron, enviadas)} %', agendaron / maximo, AppColors.brand),
                if (invitaciones != null)
                  paso('Invitadas que no han vuelto (hoy)', miles(noVolvieron), noVolvieron / maximo, AppColors.brandTint),
                if (onIrAClientes != null && noVolvieron > 0)
                  TextButton(onPressed: onIrAClientes, child: const Text('Verlas en Clientes')),
              ],
            );
          },
        ),
        if (filtrado)
          Text(
            'Las invitaciones no se filtran por estilista ni por servicio: se invita a la clienta.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
      ],
      deDondeSale:
          '"Nueva" es la clienta cuya primera cita atendida cae en esa semana. Las invitaciones salen de Invitar a volver.',
    );
  }
}

// ---------------------------------------------------------------------------
// ¿Qué se perdió?
// ---------------------------------------------------------------------------

class _QueSePerdio extends StatelessWidget {
  const _QueSePerdio({required this.datos});

  final DashboardDeAtenciones datos;

  @override
  Widget build(BuildContext context) {
    final a = datos.actual, b = datos.anterior;
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final tasa = porcentaje(a.perdidas, a.decididas);
    final tasaAntes = porcentaje(b.perdidas, b.decididas);
    final diaTop = datos.perdidasPorDia.entries.isEmpty
        ? null
        : (datos.perdidasPorDia.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).first.key;

    Widget caja(int n, String texto, Color color, Widget variacion) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.brandTintSoft, borderRadius: BorderRadius.circular(AppRadius.control)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(miles(n), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            Text(texto, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            variacion,
          ],
        ),
      ),
    );

    return _Pregunta(
      pregunta: '¿Qué se perdió?',
      aclaracion: 'canceladas y las que no llegaron',
      respuesta: a.perdidas == 0
          ? const Text('No se perdió ninguna cita en este periodo.')
          : _respuesta(_trozos([
              'Se perdieron ',
              _R('$tasa de cada 100 citas'),
              b.decididas == 0
                  ? '. '
                  : tasa < tasaAntes
                  ? ' (antes $tasaAntes: mejoró). '
                  : tasa > tasaAntes
                  ? ' (antes $tasaAntes: empeoró). '
                  : ' (igual que antes). ',
              if (diaTop != null) ...['El día con más pérdidas es el ', _R(diasDeLaSemana[diaTop - 1]), ', y '],
              '${porcentaje(datos.perdidasEnLinea, a.perdidas)} % de las perdidas había llegado en línea.',
            ])),
      hijos: [
        Row(
          children: [
            caja(a.canceladas, 'Canceladas', AppColors.danger, _Variacion(actual: a.canceladas, anterior: b.canceladas, subirEsMalo: true)),
            const SizedBox(width: 10),
            caja(a.noLlegaron, 'No llegaron', AppColors.warning, _Variacion(actual: a.noLlegaron, anterior: b.noLlegaron, subirEsMalo: true)),
          ],
        ),
        if (datos.motivos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Los últimos motivos, como se escribieron', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          for (final m in datos.motivos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: m.cancelada ? AppColors.dangerTint : AppColors.warningTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      m.cancelada ? 'Cancelada' : 'No llegó',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: m.cancelada ? AppColors.danger : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: m.motivo,
                        children: [
                          TextSpan(
                            text: '  ·  ${diasDeLaSemana[m.dia.weekday - 1]} ${m.dia.day} ${meses[m.dia.month - 1]}'
                                '${m.servicios == null ? '' : ', ${m.servicios}'}'
                                '${m.estilistas == null ? '' : ' con ${m.estilistas}'}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
      deDondeSale:
          'Los motivos se escriben a mano al cancelar o marcar "No asistió", así que se muestran tal cual. Aquí, que una flecha suba es mala noticia.',
    );
  }
}
