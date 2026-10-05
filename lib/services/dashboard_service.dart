import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_de_atenciones.dart';
import '../models/dashboard_hoy.dart';
import '../models/dashboard_metrics.dart';
import '../models/dashboard_overview.dart';
import '../models/dashboard_serie.dart';
import '../models/periodo_dashboard.dart';
import 'monitoreo_service.dart';

/// Resultado de pedir el resumen: los numeros y **los rangos con los que se
/// calcularon**.
///
/// Los rangos vuelven con los datos porque la pantalla los necesita para dos
/// cosas: escribir "1 al 8 de agosto contra 1 al 8 de julio" debajo del
/// indicador, y decidir si la comparacion se puede mostrar.
class ResumenDashboard {
  const ResumenDashboard({
    required this.datos,
    required this.rango,
    required this.rangoAnterior,
  });

  final DashboardOverview datos;
  final RangoFechas rango;
  final RangoFechas rangoAnterior;
}

/// Lo mismo que [ResumenDashboard], para el Dashboard de atenciones (D-317).
class ResumenDeAtenciones {
  const ResumenDeAtenciones({
    required this.datos,
    required this.rango,
    required this.rangoAnterior,
  });

  final DashboardDeAtenciones datos;
  final RangoFechas rango;
  final RangoFechas rangoAnterior;
}

class DashboardService {
  const DashboardService({required this.branchId});

  final String branchId;

  Future<DashboardMetrics> getMetrics() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client
            .rpc('get_dashboard_metrics_v2', params: {'p_branch_id': branchId})
            .single();

        return DashboardMetrics.fromMap(Map<String, dynamic>.from(response));
      },
      motivo: 'Fallo al consultar get_dashboard_metrics_v2()',
    );
  }

  /// Trae la Vista 1 para [periodo].
  ///
  /// **El problema del huevo y la gallina, y como se resuelve.** Para saber que
  /// rango pedir hay que saber que dia es *en la sede*, y eso solo lo sabe el
  /// servidor: el navegador de un mostrador puede tener la hora corrida, y a
  /// partir de las 7 de la noche una zona equivocada cambia el dia entero.
  ///
  /// Asi que se pide con la fecha del dispositivo como conjetura, y la
  /// respuesta trae el dia real de la sede. Si no coinciden -- raro, pero es
  /// justo el caso en el que un cierre de caja no cuadraria -- se recalcula y
  /// se pide **una sola vez mas**. Nunca mas de dos viajes.
  ///
  /// [branchIds] vacio significa "todas las sedes que pueda ver". El servidor
  /// interseca esa lista con las sedes de las que el usuario es miembro de
  /// verdad, asi que pedir una sede ajena devuelve error, no datos.
  Future<ResumenDashboard> getOverview({
    required PeriodoDashboard periodo,
    List<String> branchIds = const <String>[],
  }) async {
    return MonitoreoService.capturar(
      () async {
        final conjetura = DateTime.now();
        var resultado = await _pedirOverview(periodo, branchIds, conjetura);

        final hoyReal = resultado.datos.hoyEnLaSede;
        final desalineado =
            hoyReal.year != conjetura.year ||
            hoyReal.month != conjetura.month ||
            hoyReal.day != conjetura.day;

        if (desalineado) {
          resultado = await _pedirOverview(periodo, branchIds, hoyReal);
        }

        return resultado;
      },
      motivo: 'Fallo al consultar get_dashboard_overview()',
    );
  }

  /// El Dashboard de atenciones de los negocios sin caja (D-317): el mismo
  /// periodo y la misma comparación que [getOverview], contados en citas,
  /// clientas, servicios y equipo, sin un peso.
  ///
  /// Mismo truco del día de la sede que [getOverview]: se pide con la fecha
  /// del dispositivo y, si la sede dice otra, se pide una vez más.
  ///
  /// [estilistaId] y [servicioId] son los filtros que se ponen al tocar una
  /// estilista o un servicio en el tablero.
  Future<ResumenDeAtenciones> getAtenciones({
    required PeriodoDashboard periodo,
    List<String> branchIds = const <String>[],
    String? estilistaId,
    String? servicioId,
  }) async {
    return MonitoreoService.capturar(
      () async {
        final conjetura = DateTime.now();
        var resultado = await _pedirAtenciones(
          periodo, branchIds, conjetura, estilistaId, servicioId,
        );

        final hoyReal = resultado.datos.hoyEnLaSede;
        if (hoyReal.year != conjetura.year ||
            hoyReal.month != conjetura.month ||
            hoyReal.day != conjetura.day) {
          resultado = await _pedirAtenciones(
            periodo, branchIds, hoyReal, estilistaId, servicioId,
          );
        }

        return resultado;
      },
      motivo: 'Fallo al consultar get_dashboard_atenciones()',
    );
  }

  Future<ResumenDeAtenciones> _pedirAtenciones(
    PeriodoDashboard periodo,
    List<String> branchIds,
    DateTime hoy,
    String? estilistaId,
    String? servicioId,
  ) async {
    final rango = periodo.rango(hoy);
    final anterior = periodo.rangoAnterior(hoy);

    final response = await Supabase.instance.client.rpc(
      'get_dashboard_atenciones',
      params: {
        'p_branch_ids': branchIds.isEmpty ? null : branchIds,
        'p_from': _fecha(rango.desde),
        'p_to': _fecha(rango.hasta),
        'p_prev_from': _fecha(anterior.desde),
        'p_prev_to': _fecha(anterior.hasta),
        'p_stylist_id': estilistaId,
        'p_service_id': servicioId,
      },
    );

    return ResumenDeAtenciones(
      datos: DashboardDeAtenciones.fromMap(
        Map<String, dynamic>.from(response as Map),
      ),
      rango: rango,
      rangoAnterior: anterior,
    );
  }

  /// El bloque de hoy y los avisos.
  ///
  /// No recibe rango a propósito: **hoy es hoy**, mire el propietario el mes o
  /// el año. Por eso tampoco se recarga al cambiar el filtro de fechas.
  Future<DashboardHoy> getHoy({
    List<String> branchIds = const <String>[],
  }) async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client
            .rpc(
              'get_dashboard_today',
              params: {'p_branch_ids': branchIds.isEmpty ? null : branchIds},
            )
            .single();

        return DashboardHoy.fromMap(Map<String, dynamic>.from(response));
      },
      motivo: 'Fallo al consultar get_dashboard_today()',
    );
  }

  /// La serie del gráfico para el mismo rango que se está mirando.
  ///
  /// Va en su propia consulta y no dentro de [getOverview] a propósito: los
  /// cuatro indicadores de arriba son cuatro números y llegan en un parpadeo,
  /// mientras que la serie puede traer cientos de filas. Juntarlas haría
  /// esperar a los números por el gráfico.
  Future<SerieDashboard> getSerie({
    required RangoFechas rango,
    List<String> branchIds = const <String>[],
  }) async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client.rpc(
          'get_dashboard_series',
          params: {
            'p_branch_ids': branchIds.isEmpty ? null : branchIds,
            'p_from': _fecha(rango.desde),
            'p_to': _fecha(rango.hasta),
          },
        );

        final filas = (response as List)
            .map((fila) => Map<String, dynamic>.from(fila as Map))
            .toList(growable: false);

        return SerieDashboard.fromRows(filas);
      },
      motivo: 'Fallo al consultar get_dashboard_series()',
    );
  }

  Future<ResumenDashboard> _pedirOverview(
    PeriodoDashboard periodo,
    List<String> branchIds,
    DateTime hoy,
  ) async {
    final rango = periodo.rango(hoy);
    final anterior = periodo.rangoAnterior(hoy);

    final response = await Supabase.instance.client
        .rpc(
          'get_dashboard_overview',
          params: {
            'p_branch_ids': branchIds.isEmpty ? null : branchIds,
            'p_from': _fecha(rango.desde),
            'p_to': _fecha(rango.hasta),
            'p_prev_from': _fecha(anterior.desde),
            'p_prev_to': _fecha(anterior.hasta),
          },
        )
        .single();

    return ResumenDashboard(
      datos: DashboardOverview.fromMap(Map<String, dynamic>.from(response)),
      rango: rango,
      rangoAnterior: anterior,
    );
  }

  /// `YYYY-MM-DD`, que es como Postgres espera un `date`. Se manda la fecha
  /// civil pelada, sin hora ni zona: la zona la aplica el servidor con la de
  /// cada sede.
  static String _fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
