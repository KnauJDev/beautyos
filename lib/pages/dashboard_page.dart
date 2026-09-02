import 'package:flutter/material.dart';

import '../models/branch_context.dart';
import '../models/dashboard_hoy.dart';
import '../models/dashboard_serie.dart';
import '../models/onboarding_progress.dart';
import '../models/periodo_dashboard.dart';
import '../services/dashboard_service.dart';
import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import '../widgets/agenda_de_hoy.dart';
import '../widgets/app_widgets.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/grafico_protagonista.dart';
import '../widgets/indicador_comparado.dart';
import '../widgets/primeros_pasos_card.dart';
import '../widgets/tiempo_vendido.dart';
import '../widgets/tu_negocio_en_palabras_card.dart';

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
    required this.nombreParaSaludo,
    this.onIrAAgenda,
    this.onIrATickets,
    this.onIrAClientes,
    this.onIrAServicios,
    this.onIrAEstilistas,
    this.onIrAConfiguracion,
  });

  final String branchId;

  /// Las sedes que este usuario puede consultar. Vacío significa que solo hay
  /// una y no se dibuja el selector.
  final List<BranchContext> branches;

  /// El titular o, si no tiene perfil con nombre, el nombre del negocio.
  /// "Tu negocio en palabras" (D-168) solo usa el primer nombre.
  final String nombreParaSaludo;

  /// Cambian de pestaña dentro del shell (D-168, mismo criterio de D-163:
  /// Agenda, Tickets y Clientes son módulos hermanos en el mismo
  /// `IndexedStack`, no rutas empujables).
  final VoidCallback? onIrAAgenda;
  final VoidCallback? onIrATickets;
  final VoidCallback? onIrAClientes;

  /// Los tres destinos de la lista de Primeros pasos (paso 8.8, D-186). Mismo
  /// criterio que los de arriba: son modulos hermanos del mismo `IndexedStack`.
  final VoidCallback? onIrAServicios;
  final VoidCallback? onIrAEstilistas;
  final VoidCallback? onIrAConfiguracion;

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
  late Future<DashboardHoy> _hoy;

  /// Primeros pasos (paso 8.8, D-186). Se carga aparte del resto: si fallara,
  /// el Dashboard tiene que seguir funcionando igual.
  final OnboardingService _onboardingService = const OnboardingService();
  late Future<OnboardingProgress> _primerosPasos;

  @override
  void initState() {
    super.initState();
    dashboardService = DashboardService(branchId: widget.branchId);
    _cargarTodo();
    _cargarHoy();
    _cargarPrimerosPasos();
  }

  void _cargarPrimerosPasos() {
    _primerosPasos = _onboardingService.getProgress(widget.branchId);
  }

  Future<void> _descartarPrimerosPasos() async {
    try {
      await _onboardingService.dismiss();
      if (!mounted) return;
      setState(_cargarPrimerosPasos);
    } catch (_) {
      if (!mounted) return;
      // Si no se pudo guardar, hay que decirlo: si no, la lista reaparece al
      // recargar y parece que el boton no hace nada.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo ocultar la lista. Intentalo de nuevo.'),
        ),
      );
    }
  }

  List<String> get _sedes =>
      _sedeElegida == null ? const <String>[] : <String>[_sedeElegida!];

  /// Se recarga al cambiar de sede, pero **no al cambiar el rango de fechas**:
  /// hoy es hoy, mire el propietario el mes o el ano.
  void _cargarHoy() {
    _hoy = dashboardService.getHoy(branchIds: _sedes);
  }

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
    setState(() {
      _cargarTodo();
      _cargarHoy();
      _cargarPrimerosPasos();
    });
  }

  /// Convierte los números en frases. Es donde el tablero deja de ser
  /// estadística y empieza a hablar.
  ///
  /// Como mucho **tres**, y en este orden: primero lo que se puede resolver hoy
  /// —el dinero en la calle—, después lo que se está perdiendo despacio, y solo
  /// al final la felicitación. Un tablero que abre con elogios y esconde el
  /// problema al fondo no sirve para dirigir un negocio.
  List<Aviso> _avisos(DashboardHoy hoy, ResumenDashboard resumen) {
    final lista = <Aviso>[];

    if (hoy.porCobrarTickets > 0) {
      lista.add(
        Aviso(
          texto:
              'Tienes ${_Indicadores._dinero(hoy.porCobrarMonto)} por cobrar '
              'en ${hoy.porCobrarTickets} '
              '${hoy.porCobrarTickets == 1 ? "ticket finalizado" : "tickets finalizados"}.',
          tono: TonoAviso.atencion,
        ),
      );
    }

    if (hoy.clientesEnRiesgo > 0) {
      lista.add(
        Aviso(
          texto:
              '${hoy.clientesEnRiesgo} '
              '${hoy.clientesEnRiesgo == 1 ? "cliente que venía seguido no vuelve" : "clientes que venían seguido no vuelven"} '
              'hace más de 45 días.',
          tono: TonoAviso.atencion,
        ),
      );
    }

    // El indicador que más se movió. Sale gratis: ya está calculado arriba.
    final movimientos = <String, Comparacion>{
      'Las ventas': resumen.datos.compararVentas(resumen.rangoAnterior),
      'Las citas': resumen.datos.compararCitas(resumen.rangoAnterior),
      'El ticket promedio': resumen.datos.compararTicketPromedio(
        resumen.rangoAnterior,
      ),
    };

    MapEntry<String, Comparacion>? mayor;
    for (final entrada in movimientos.entries) {
      if (entrada.value.estado != EstadoComparacion.disponible) continue;
      final v = entrada.value.variacion!.abs();
      if (v < 0.05) continue; // menos de un 5 % es ruido, no noticia
      if (mayor == null || v > mayor.value.variacion!.abs()) {
        mayor = entrada;
      }
    }

    if (mayor != null && lista.length < 3) {
      final pct = (mayor.value.variacion! * 100).abs().toStringAsFixed(1);
      lista.add(
        Aviso(
          texto: mayor.value.subio
              ? '${mayor.key} subieron ${pct.replaceAll('.', ',')}% frente al período anterior.'
              : '${mayor.key} bajaron ${pct.replaceAll('.', ',')}% frente al período anterior.',
          tono: mayor.value.subio ? TonoAviso.bueno : TonoAviso.atencion,
        ),
      );
    }

    return lista.take(3).toList(growable: false);
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
                // Primeros pasos (paso 8.8, D-186): va ARRIBA DEL TODO, antes
                // de los controles. Un salon que aun no puede cobrar no
                // necesita elegir un rango de fechas: necesita saber que le
                // falta. Cuando los cuatro pasos estan hechos desaparece sola.
                FutureBuilder<OnboardingProgress>(
                  future: _primerosPasos,
                  builder: (context, p) {
                    if (!p.hasData || !p.data!.debeMostrarse) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: PrimerosPasosCard(
                        progreso: p.data!,
                        onIrAServicios: widget.onIrAServicios ?? () {},
                        onIrAEstilistas: widget.onIrAEstilistas ?? () {},
                        onIrAConfiguracion: widget.onIrAConfiguracion ?? () {},
                        onIrAAgenda: widget.onIrAAgenda ?? () {},
                        onDescartar: _descartarPrimerosPasos,
                      ),
                    );
                  },
                ),
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
                      _cargarHoy();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                if (datos.sinHistoria)
                  // Si la lista de Primeros pasos esta arriba, esta tarjeta
                  // diria lo mismo con menos: se calla (paso 8.8, D-186).
                  FutureBuilder<OnboardingProgress>(
                    future: _primerosPasos,
                    builder: (context, p) =>
                        (p.hasData && p.data!.debeMostrarse)
                        ? const SizedBox.shrink()
                        : const _DiaCero(),
                  )
                else ...[
                  // Su propio FutureBuilder porque usa `_hoy`, que se carga
                  // aparte de `_resumen` (ver comentario de `_cargarHoy`).
                  // Comparte la misma Future que AgendaDeHoy/AvisosDelDia
                  // mas abajo -- no dispara una segunda consulta.
                  FutureBuilder<DashboardHoy>(
                    future: _hoy,
                    builder: (context, h) {
                      if (!h.hasData) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: TuNegocioEnPalabrasCard(
                          hoy: h.data!,
                          overview: datos,
                          rangoAnterior: resumen.rangoAnterior,
                          nombre: widget.nombreParaSaludo,
                          onIrAAgenda: widget.onIrAAgenda,
                          onIrATickets: widget.onIrATickets,
                          onIrAClientes: widget.onIrAClientes,
                        ),
                      );
                    },
                  ),
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

                  const SizedBox(height: AppSpacing.lg),
                  TiempoVendido(
                    datos: datos,
                    rangoAnterior: resumen.rangoAnterior,
                    etiquetaPeriodoAnterior: etiquetaComparacion(
                      _periodo,
                      datos.hoyEnLaSede,
                    ),
                  ),

                  // El bloque de hoy y los avisos van al final y en su propio
                  // FutureBuilder: responden a otra pregunta -- "que pasa
                  // ahora" en vez de "como me fue" -- y no se recargan cuando
                  // se mueve el filtro de fechas.
                  FutureBuilder<DashboardHoy>(
                    future: _hoy,
                    builder: (context, h) {
                      if (!h.hasData) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          AgendaDeHoy(hoy: h.data!),
                          const SizedBox(height: AppSpacing.lg),
                          AvisosDelDia(avisos: _avisos(h.data!, resumen)),
                        ],
                      );
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
            // Acotado igual que el filtro de fechas: el nombre de una sede
            // puede ser largo y en un telefono empujaria el control fuera de
            // la pantalla.
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.control),
              color: AppColors.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: sedeElegida,
                isExpanded: true,
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
                      child: Text(
                        sede.branchName,
                        overflow: TextOverflow.ellipsis,
                      ),
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
