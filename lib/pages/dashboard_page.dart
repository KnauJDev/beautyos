import 'package:flutter/material.dart';

import '../models/branch_context.dart';
import '../models/dashboard_serie.dart';
import '../models/periodo_dashboard.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grafico_protagonista.dart';
import '../widgets/indicador_comparado.dart';

/// Vista 1 del Dashboard: el resumen (tarea 2.5a, D-110).
///
/// Responde en cinco segundos "¿cómo está mi negocio?" y en treinta "¿por qué?".
/// Cuatro indicadores protagonistas y nada más: el resto de las cifras existen,
/// pero viven detrás, en las vistas de Negocio, Clientes y Equipo.
///
/// **Se diseñó primero el día cero.** Todos los negocios que se registren
/// empiezan sin un solo dato, y el Dashboard es la primera pantalla que ven: un
/// tablero de indicadores en cero no se ve elegante, se ve roto.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.branchId,
    this.branches = const <BranchContext>[],
  });

  final String branchId;

  /// Las sedes que este usuario puede consultar. Vacío significa que solo hay
  /// una y no se dibuja el selector.
  final List<BranchContext> branches;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardService dashboardService;

  PeriodoDashboard _periodo = PeriodoDashboard.esteMes;

  /// `null` = todas las sedes que el usuario alcanza, que es el valor por
  /// defecto: "¿cómo va mi negocio?" para quien tiene dos locales son los dos.
  String? _sedeElegida;

  late Future<ResumenDashboard> _resumen;
  late Future<SerieDashboard> _serie;

  @override
  void initState() {
    super.initState();
    dashboardService = DashboardService(branchId: widget.branchId);
    _cargarTodo();
  }

  List<String> get _sedes =>
      _sedeElegida == null ? const <String>[] : <String>[_sedeElegida!];

  void _cargarTodo() {
    _resumen = dashboardService.getOverview(
      periodo: _periodo,
      branchIds: _sedes,
    );

    // La serie espera al resumen solo para una cosa: saber que dia es en la
    // sede. El rango se calcula con esa fecha, no con la del navegador, o el
    // grafico dibujaria un dia corrido respecto a los numeros de arriba.
    _serie = _resumen.then(
      (r) => dashboardService.getSerie(rango: r.rango, branchIds: _sedes),
    );
  }

  void _recargar() {
    setState(_cargarTodo);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Dashboard',
      subtitle: '¿Cómo está tu negocio?',
      children: [
        FutureBuilder<ResumenDashboard>(
          future: _resumen,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingCard(mensaje: 'Consultando tu negocio...');
            }

            if (snapshot.hasError) {
              return ErrorState(
                titulo: 'No se pudo cargar el resumen',
                detalle: '${snapshot.error}',
                onReintentar: _recargar,
              );
            }

            final resumen = snapshot.data!;
            final datos = resumen.datos;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Controles(
                  periodo: _periodo,
                  hoy: datos.hoyEnLaSede,
                  branches: widget.branches,
                  sedeElegida: _sedeElegida,
                  onPeriodo: (p) {
                    setState(() {
                      _periodo = p;
                      _cargarTodo();
                    });
                  },
                  onSede: (id) {
                    setState(() {
                      _sedeElegida = id;
                      _cargarTodo();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                if (datos.sinHistoria)
                  const _DiaCero()
                else ...[
                  _Indicadores(resumen: resumen, periodo: _periodo),
                  const SizedBox(height: AppSpacing.lg),
                  // El grafico va en su propio FutureBuilder: son cientos de
                  // filas contra los cuatro numeros de arriba, y esos no tienen
                  // por que esperarlo.
                  FutureBuilder<SerieDashboard>(
                    future: _serie,
                    builder: (context, s) {
                      if (s.connectionState == ConnectionState.waiting) {
                        return const LoadingCard(
                          mensaje: 'Dibujando tu tendencia...',
                        );
                      }
                      if (s.hasError || !s.hasData) {
                        return ErrorState(
                          titulo: 'No se pudo dibujar el gráfico',
                          detalle: '${s.error ?? ''}',
                          onReintentar: _recargar,
                        );
                      }
                      return GraficoProtagonista(serie: s.data!);
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.periodo,
    required this.hoy,
    required this.branches,
    required this.sedeElegida,
    required this.onPeriodo,
    required this.onSede,
  });

  final PeriodoDashboard periodo;
  final DateTime hoy;
  final List<BranchContext> branches;
  final String? sedeElegida;
  final ValueChanged<PeriodoDashboard> onPeriodo;
  final ValueChanged<String?> onSede;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        FiltroPeriodo(periodo: periodo, onCambio: onPeriodo, hoy: hoy),

        // Con una sola sede el selector no aporta nada y estorba, igual que el
        // icono de la casita en la barra de celular (D-106).
        if (branches.length > 1)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.control),
              color: AppColors.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: sedeElegida,
                borderRadius: BorderRadius.circular(AppRadius.control),
                onChanged: onSede,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las sedes'),
                  ),
                  for (final sede in branches)
                    DropdownMenuItem<String?>(
                      value: sede.branchId,
                      child: Text(sede.branchName),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.resumen, required this.periodo});

  final ResumenDashboard resumen;
  final PeriodoDashboard periodo;

  @override
  Widget build(BuildContext context) {
    final datos = resumen.datos;
    final anterior = resumen.rangoAnterior;
    final etiqueta = etiquetaComparacion(periodo, datos.hoyEnLaSede);

    final tarjetas = <Widget>[
      IndicadorComparado(
        titulo: 'Ventas',
        valor: _dinero(datos.ventas),
        comparacion: datos.compararVentas(anterior),
        etiquetaPeriodoAnterior: etiqueta,
        origenDelDato:
            'Suma de los cobros registrados en el período. Un servicio '
            'terminado y sin cobrar no cuenta aquí: está en "por cobrar".',
      ),
      IndicadorComparado(
        titulo: 'Citas',
        valor: '${datos.citas}',
        comparacion: datos.compararCitas(anterior),
        etiquetaPeriodoAnterior: etiqueta,
        origenDelDato:
            'Citas con fecha dentro del período. Las canceladas no se '
            'cuentan.',
      ),
      IndicadorComparado(
        titulo: 'Clientes atendidos',
        valor: '${datos.clientesAtendidos}',
        comparacion: datos.compararClientes(anterior),
        etiquetaPeriodoAnterior: etiqueta,
        origenDelDato:
            'Personas distintas con al menos un cobro en el período. No son '
            'los clientes registrados.',
      ),
      IndicadorComparado(
        titulo: 'Ticket promedio',
        valor: datos.ticketPromedio == null
            ? 'Sin cobros'
            : _dinero(datos.ticketPromedio!),
        comparacion: datos.compararTicketPromedio(anterior),
        etiquetaPeriodoAnterior: etiqueta,
        origenDelDato:
            'Ventas divididas entre los tickets cobrados en el período.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cuatro en fila en pantalla ancha, dos por fila en celular. Nunca uno
        // solo: el valor de estos números está en verlos juntos.
        final columnas = constraints.maxWidth >= 900 ? 4 : 2;
        final ancho =
            (constraints.maxWidth - (columnas - 1) * AppSpacing.md) / columnas;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final tarjeta in tarjetas)
              SizedBox(width: ancho, child: tarjeta),
          ],
        );
      },
    );
  }

  /// Formato colombiano: `$24.800.000`, sin decimales.
  ///
  /// Los centavos no existen en la práctica de un salón y ocupan un espacio que
  /// en celular hace falta.
  static String _dinero(double valor) {
    final entero = valor.round().abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(entero[i]);
    }

    return '${valor < 0 ? '-' : ''}\$${buffer.toString()}';
  }
}

/// Lo que ve un negocio que todavía no tiene ni un dato.
///
/// No dice "no hay datos" ni muestra cuatro ceros: **invita a empezar**. Es la
/// primera pantalla de cada negocio que se registre, y absorbe la tarea 4.4 de
/// onboarding, pospuesta desde D-085.
class _DiaCero extends StatelessWidget {
  const _DiaCero();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu negocio está listo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Aquí verás cómo crece. En cuanto cobres tu primer ticket, esta '
            'pantalla empieza a contarte la historia de tu negocio.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Paso(
            icono: Icons.content_cut_outlined,
            texto: 'Crea tus servicios y sus precios',
          ),
          const _Paso(
            icono: Icons.badge_outlined,
            texto: 'Suma a tu equipo',
          ),
          const _Paso(
            icono: Icons.calendar_month_outlined,
            texto: 'Agenda tu primera cita',
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icono, size: 19, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
