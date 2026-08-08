import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/dashboard_overview.dart';
import 'package:salonymas/models/periodo_dashboard.dart';

/// Pruebas del resumen de la Vista 1 (2.5a, D-110).
///
/// Lo que se vigila aqui no es la aritmetica sino **que la pantalla nunca
/// reciba un numero que no pueda defender**: un ticket promedio infinito, una
/// fecha corrida un dia, o un porcentaje sobre historia que no existe.
void main() {
  Map<String, dynamic> respuesta({
    Object? sales = 1280000,
    Object? prevSales = 1081000,
    Object? paidTickets = 22,
    Object? prevPaidTickets = 20,
    Object? firstActivity = '2026-01-15',
  }) {
    return <String, dynamic>{
      'sales': sales,
      'appointments': 30,
      'clients_served': 25,
      'paid_tickets': paidTickets,
      'prev_sales': prevSales,
      'prev_appointments': 28,
      'prev_clients_served': 24,
      'prev_paid_tickets': prevPaidTickets,
      'first_activity_on': firstActivity,
      'today_on': '2026-08-08',
      'branches_included': 2,
    };
  }

  group('lectura de la respuesta de Supabase', () {
    test('lee los cuatro indicadores y su periodo anterior', () {
      final o = DashboardOverview.fromMap(respuesta());

      expect(o.ventas, 1280000);
      expect(o.citas, 30);
      expect(o.clientesAtendidos, 25);
      expect(o.ticketsCobrados, 22);
      expect(o.ventasAnterior, 1081000);
      expect(o.sedesIncluidas, 2);
    });

    test('la fecha no se corre un dia al leerse', () {
      // Postgres manda `date` como texto. Convertirlo a instante local es
      // justo lo que desplaza el dia segun la zona del navegador.
      final o = DashboardOverview.fromMap(respuesta());

      expect(o.hoyEnLaSede, DateTime(2026, 8, 8));
      expect(o.primeraActividad, DateTime(2026, 1, 15));
    });

    test('acepta numeros que lleguen como texto', () {
      // `numeric` de Postgres puede llegar como String por el cliente REST.
      final o = DashboardOverview.fromMap(
        respuesta(sales: '1280000.50', paidTickets: '22'),
      );

      expect(o.ventas, closeTo(1280000.50, 0.001));
      expect(o.ticketsCobrados, 22);
    });

    test('un negocio sin un solo dato se reconoce como tal', () {
      final o = DashboardOverview.fromMap(respuesta(firstActivity: null));

      expect(o.primeraActividad, isNull);
      expect(o.sinHistoria, isTrue);
    });
  });

  group('ticket promedio', () {
    test('divide ventas entre tickets cobrados', () {
      final o = DashboardOverview.fromMap(respuesta());
      expect(o.ticketPromedio, closeTo(1280000 / 22, 0.001));
    });

    test('sin tickets cobrados no hay promedio, y no es cero ni infinito', () {
      final o = DashboardOverview.fromMap(
        respuesta(sales: 0, paidTickets: 0, prevPaidTickets: 0),
      );

      expect(
        o.ticketPromedio,
        isNull,
        reason:
            'Dividir entre cero daria infinito, que es exactamente la '
            'precision que los datos no soportan.',
      );
      expect(o.ticketPromedioAnterior, isNull);
    });
  });

  group('las comparaciones respetan la regla de oro', () {
    final anterior = RangoFechas(DateTime(2026, 7, 1), DateTime(2026, 7, 8));

    test('con historia suficiente, calcula el porcentaje', () {
      final o = DashboardOverview.fromMap(respuesta());
      final c = o.compararVentas(anterior);

      expect(c.estado, EstadoComparacion.disponible);
      expect(c.variacion! * 100, closeTo(18.4, 0.1));
    });

    test('si el negocio nacio despues, avisa en vez de inventar', () {
      final o = DashboardOverview.fromMap(
        respuesta(firstActivity: '2026-07-10'),
      );

      for (final c in [
        o.compararVentas(anterior),
        o.compararCitas(anterior),
        o.compararClientes(anterior),
        o.compararTicketPromedio(anterior),
      ]) {
        expect(c.estado, EstadoComparacion.historiaInsuficiente);
        expect(c.variacion, isNull);
      }
    });

    test('existia pero sin movimiento: no es infinito', () {
      final o = DashboardOverview.fromMap(
        respuesta(prevSales: 0, prevPaidTickets: 0),
      );
      final c = o.compararVentas(anterior);

      expect(c.estado, EstadoComparacion.sinMovimientoAnterior);
      expect(c.variacion, isNull);
    });

    test('las cuatro comparaciones salen del mismo origen de historia', () {
      final o = DashboardOverview.fromMap(respuesta());

      expect(o.compararCitas(anterior).estado, EstadoComparacion.disponible);
      expect(o.compararClientes(anterior).estado, EstadoComparacion.disponible);
      expect(
        o.compararTicketPromedio(anterior).estado,
        EstadoComparacion.disponible,
      );
    });
  });
}
