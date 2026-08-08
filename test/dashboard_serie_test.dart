import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/dashboard_serie.dart';

/// Pruebas de la serie del gráfico (2.5a, D-110).
///
/// Lo que se vigila: que el gráfico **no cuente una historia distinta a la de
/// los números de arriba**, y que no destaque un "mejor día" que no existe.
void main() {
  Map<String, dynamic> fila(
    String fecha, {
    num sales = 0,
    int appointments = 0,
    int clients = 0,
    int paid = 0,
    String grano = 'day',
  }) {
    return <String, dynamic>{
      'bucket_on': fecha,
      'granularity': grano,
      'sales': sales,
      'appointments': appointments,
      'clients_served': clients,
      'paid_tickets': paid,
    };
  }

  group('lectura de la serie', () {
    test('lee los puntos y conserva el orden', () {
      final s = SerieDashboard.fromRows([
        fila('2026-08-06', sales: 100000, paid: 2),
        fila('2026-08-07', sales: 250000, paid: 5),
        fila('2026-08-08', sales: 180000, paid: 3),
      ]);

      expect(s.puntos.length, 3);
      expect(s.puntos.first.fecha, DateTime(2026, 8, 6));
      expect(s.puntos.last.ventas, 180000);
      expect(s.grano, GranoSerie.dia);
    });

    test('reconoce el agrupamiento que decidió el servidor', () {
      expect(
        SerieDashboard.fromRows([fila('2026-01-05', grano: 'week')]).grano,
        GranoSerie.semana,
      );
      expect(
        SerieDashboard.fromRows([fila('2026-01-01', grano: 'month')]).grano,
        GranoSerie.mes,
      );
    });

    test('una serie sin filas se reconoce como vacía', () {
      expect(SerieDashboard.fromRows(const []).vacia, isTrue);
    });
  });

  group('los días sin movimiento valen cero, no desaparecen', () {
    test('un cero en medio se conserva como punto', () {
      // Si el servidor no rellenara los huecos, el grafico uniria el lunes con
      // el miercoles en linea recta y escondería que el martes no se vendio.
      final s = SerieDashboard.fromRows([
        fila('2026-08-03', sales: 100000, paid: 2),
        fila('2026-08-04', sales: 0),
        fila('2026-08-05', sales: 90000, paid: 1),
      ]);

      expect(s.puntos.length, 3);
      expect(s.puntos[1].ventas, 0);
    });
  });

  group('ticket promedio dentro del gráfico', () {
    test('divide ventas entre tickets cobrados', () {
      final p = PuntoSerie.fromMap(fila('2026-08-08', sales: 300000, paid: 4));
      expect(p.ticketPromedio, 75000);
    });

    test('sin cobros no hay promedio: null, no infinito', () {
      final p = PuntoSerie.fromMap(fila('2026-08-08', sales: 0, paid: 0));
      expect(p.ticketPromedio, isNull);
      // Al dibujar cae a cero, que es lo unico que una escala admite.
      expect(IndicadorGrafico.ticketPromedio.valorDe(p), 0);
    });
  });

  group('el mejor período', () {
    test('encuentra el pico del indicador elegido', () {
      final s = SerieDashboard.fromRows([
        fila('2026-08-06', sales: 100000, appointments: 9),
        fila('2026-08-07', sales: 250000, appointments: 3),
        fila('2026-08-08', sales: 180000, appointments: 12),
      ]);

      expect(s.mejor(IndicadorGrafico.ventas)!.fecha, DateTime(2026, 8, 7));
      // El mejor dia de ventas no tiene por que ser el de mas citas: por eso
      // el pico se calcula por indicador y no una sola vez.
      expect(s.mejor(IndicadorGrafico.citas)!.fecha, DateTime(2026, 8, 8));
    });

    test('sin movimiento no hay mejor día, y eso es correcto', () {
      final s = SerieDashboard.fromRows([
        fila('2026-08-07'),
        fila('2026-08-08'),
      ]);

      expect(
        s.mejor(IndicadorGrafico.ventas),
        isNull,
        reason:
            'Destacar "tu mejor día" cuando no se vendió nada sería una burla.',
      );
    });
  });

  group('los cuatro indicadores salen de la misma serie', () {
    test('cambiar de indicador no necesita otra consulta', () {
      final p = PuntoSerie.fromMap(
        fila('2026-08-08', sales: 300000, appointments: 12, clients: 8, paid: 4),
      );

      expect(IndicadorGrafico.ventas.valorDe(p), 300000);
      expect(IndicadorGrafico.citas.valorDe(p), 12);
      expect(IndicadorGrafico.clientes.valorDe(p), 8);
      expect(IndicadorGrafico.ticketPromedio.valorDe(p), 75000);
    });

    test('solo ventas y ticket promedio se pintan como dinero', () {
      expect(IndicadorGrafico.ventas.esDinero, isTrue);
      expect(IndicadorGrafico.ticketPromedio.esDinero, isTrue);
      expect(IndicadorGrafico.citas.esDinero, isFalse);
      expect(IndicadorGrafico.clientes.esDinero, isFalse);
    });
  });
}
