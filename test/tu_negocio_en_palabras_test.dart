import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/dashboard_hoy.dart';
import 'package:salonymas/models/dashboard_overview.dart';
import 'package:salonymas/models/periodo_dashboard.dart';
import 'package:salonymas/widgets/tu_negocio_en_palabras_card.dart';

DashboardHoy _hoy({
  int citas = 0,
  int atendidas = 0,
  int pendientes = 0,
  int sinConfirmar = 0,
  double porCobrarMonto = 0,
  int porCobrarTickets = 0,
  int clientesEnRiesgo = 0,
}) {
  return DashboardHoy(
    hoy: DateTime(2026, 8, 30),
    citas: citas,
    atendidas: atendidas,
    pendientes: pendientes,
    sinConfirmar: sinConfirmar,
    porCobrarMonto: porCobrarMonto,
    porCobrarTickets: porCobrarTickets,
    clientesEnRiesgo: clientesEnRiesgo,
  );
}

DashboardOverview _overview({
  required double ventas,
  required double ventasAnterior,
  DateTime? primeraActividad,
}) {
  return DashboardOverview(
    ventas: ventas,
    citas: 10,
    clientesAtendidos: 8,
    ticketsCobrados: 10,
    minutosVendidos: 600,
    ventasAnterior: ventasAnterior,
    citasAnterior: 9,
    clientesAtendidosAnterior: 7,
    ticketsCobradosAnterior: 9,
    minutosVendidosAnterior: 540,
    hoyEnLaSede: DateTime(2026, 8, 30),
    sedesIncluidas: 1,
    primeraActividad: primeraActividad,
  );
}

// Bien dentro de la historia del negocio, para que la comparación cuente
// como "disponible" en vez de "historia insuficiente".
final _rangoAnteriorDisponible = RangoFechas(
  DateTime(2026, 7, 1),
  DateTime(2026, 7, 31),
);
final _primeraActividadTemprana = DateTime(2026, 1, 1);

void main() {
  group('NarrativaNegocioBuilder.saludo (D-168)', () {
    test('límites exactos de cada franja horaria', () {
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 4, 59)),
        '🌙 Buenas noches',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 5, 0)),
        '🌅 Buenos días',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 11, 59)),
        '🌅 Buenos días',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 12, 0)),
        '☀️ Buenas tardes',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 18, 29)),
        '☀️ Buenas tardes',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 18, 30)),
        '🌙 Buenas noches',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 23, 59)),
        '🌙 Buenas noches',
      );
      expect(
        NarrativaNegocioBuilder.saludo(DateTime(2026, 8, 30, 0, 0)),
        '🌙 Buenas noches',
      );
    });
  });

  group('Generación matutina con citas y alertas (D-168)', () {
    test('saluda de mañana, cuenta el ritmo de citas y avisa por confirmar', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 5, atendidas: 2, sinConfirmar: 2),
        nombre: 'Yelimar Rodríguez',
        ahora: DateTime(2026, 8, 30, 8, 0),
      );

      expect(narrativa.saludo, '🌅 Buenos días, Yelimar');
      expect(narrativa.mensaje, contains('5 citas'));
      expect(narrativa.mensaje, contains('atendiste 2'));
      expect(narrativa.mensaje, contains('2 citas sin confirmar'));
      expect(narrativa.mensaje, contains('WhatsApp'));
    });

    test('cuando ya atendió todas las citas del día lo dice sin repetir el número', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 3, atendidas: 3),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 15, 0),
      );

      expect(narrativa.mensaje, contains('las atendiste todas'));
    });

    test('singular: 1 cita, sin plural de sobra', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, sinConfirmar: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 9, 0),
      );

      expect(narrativa.mensaje, contains('1 cita programada'));
      expect(narrativa.mensaje, contains('1 cita sin confirmar'));
      expect(narrativa.mensaje, isNot(contains('1 citas')));
    });

    test('de noche cambia a tiempo pasado ("tuviste", "atendiste")', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 4, atendidas: 4),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 20, 0),
      );

      expect(narrativa.saludo, startsWith('🌙 Buenas noches'));
      expect(narrativa.mensaje, contains('Hoy tuviste'));
    });
  });

  group('Alerta de dinero por cobrar (D-168)', () {
    test('formatea el monto en pesos colombianos correctamente', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 2, atendidas: 2, porCobrarMonto: 150000, porCobrarTickets: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, contains(r'$150.000'));
      expect(narrativa.mensaje, contains('1 ticket'));
      expect(narrativa.mensaje, isNot(contains('1 tickets')));
    });

    test('monto grande con separadores de miles y plural de tickets', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(porCobrarMonto: 2480000, porCobrarTickets: 3),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, contains(r'$2.480.000'));
      expect(narrativa.mensaje, contains('3 tickets'));
    });

    test('sin nada por cobrar, no aparece ninguna frase de caja', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, isNot(contains('pendientes por cobrar')));
    });
  });

  group('Alerta de clientes en riesgo (D-168)', () {
    test('plural con varias clientas en riesgo', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(clientesEnRiesgo: 3),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, contains('3 clientas'));
      expect(narrativa.mensaje, contains('reactivarlas'));
    });

    test('singular con una sola clienta en riesgo', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(clientesEnRiesgo: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, contains('1 clienta que solía venir'));
      expect(narrativa.mensaje, contains('reactivarla'));
    });

    test('sin clientes en riesgo, no aparece la frase de reactivación', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, isNot(contains('reactivar')));
    });
  });

  group('Día cero / sin citas hoy (D-168)', () {
    test('mensaje positivo de preparación, sin mencionar un ritmo que no existe', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 9, 0),
      );

      expect(narrativa.mensaje, contains('no tienes citas agendadas'));
      expect(narrativa.mensaje, contains('catálogo'));
      expect(narrativa.mensaje, isNot(contains('atendiste')));
    });

    test('sin citas hoy pero con dinero pendiente, la alerta de caja igual aparece', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(porCobrarMonto: 90000, porCobrarTickets: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 9, 0),
      );

      expect(narrativa.mensaje, contains('no tienes citas agendadas'));
      expect(narrativa.mensaje, contains(r'$90.000'));
    });

    test('variante de noche para el día sin citas', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 21, 0),
      );

      expect(narrativa.mensaje, contains('Hoy no tuviste citas agendadas'));
    });
  });

  group('Tendencia del período (D-168)', () {
    test('ventas arriba comparadas con el período anterior', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        overview: _overview(
          ventas: 1150000,
          ventasAnterior: 1000000,
          primeraActividad: _primeraActividadTemprana,
        ),
        rangoAnterior: _rangoAnteriorDisponible,
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, contains('15 % arriba'));
    });

    test('ventas abajo comparadas con el período anterior', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        overview: _overview(
          ventas: 850000,
          ventasAnterior: 1000000,
          primeraActividad: _primeraActividadTemprana,
        ),
        rangoAnterior: _rangoAnteriorDisponible,
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, contains('15 % abajo'));
    });

    test('un movimiento menor al 1 % no se menciona: no es noticia', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        overview: _overview(
          ventas: 1002000,
          ventasAnterior: 1000000,
          primeraActividad: _primeraActividadTemprana,
        ),
        rangoAnterior: _rangoAnteriorDisponible,
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, isNot(contains('período anterior')));
    });

    test('sin historia suficiente, la tendencia no se menciona', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        overview: _overview(ventas: 1150000, ventasAnterior: 1000000),
        rangoAnterior: _rangoAnteriorDisponible,
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, isNot(contains('período anterior')));
    });

    test('sin overview ni rango anterior, la tendencia simplemente se omite', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(citas: 1, atendidas: 1),
        nombre: 'Carlos',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.mensaje, isNot(contains('período anterior')));
    });
  });

  group('Nombre del saludo (D-168)', () {
    test('usa solo el primer nombre aunque llegue el nombre completo', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(),
        nombre: 'Yelimar Andrea Rodríguez Pérez',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.saludo, '🌅 Buenos días, Yelimar');
    });

    test('un nombre vacío no rompe el saludo', () {
      final narrativa = NarrativaNegocioBuilder.generar(
        hoy: _hoy(),
        nombre: '',
        ahora: DateTime(2026, 8, 30, 10, 0),
      );

      expect(narrativa.saludo, '🌅 Buenos días, por aquí');
    });
  });
}
