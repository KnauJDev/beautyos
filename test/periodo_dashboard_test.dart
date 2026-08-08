import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/periodo_dashboard.dart';

/// Pruebas del motor de comparación del Dashboard (2.5a, D-110).
///
/// Aquí es donde viven los errores que nadie ve: un rango mal calculado no
/// rompe la pantalla, solo enseña un porcentaje equivocado, y el propietario
/// toma decisiones con él. Por eso el motor se construyó como lógica pura,
/// sin base de datos y sin reloj: para poder fijarle el día y comprobarlo.
///
/// El 8 de agosto de 2026 es un **sábado**. Se usa como "hoy" en casi todo.
void main() {
  final hoy = DateTime(2026, 8, 8);

  group('rangos de calendario — "cómo voy este mes"', () {
    test('hoy es un solo día', () {
      final r = PeriodoDashboard.hoy.rango(hoy);
      expect(r.desde, DateTime(2026, 8, 8));
      expect(r.hasta, DateTime(2026, 8, 8));
      expect(r.dias, 1, reason: 'Un solo día mide 1, no 0.');
    });

    test('la semana arranca el lunes', () {
      final r = PeriodoDashboard.estaSemana.rango(hoy);
      expect(r.desde, DateTime(2026, 8, 3));
      expect(r.desde.weekday, DateTime.monday);
      expect(r.hasta, DateTime(2026, 8, 8));
    });

    test('el mes va del día 1 a hoy, no al final del mes', () {
      final r = PeriodoDashboard.esteMes.rango(hoy);
      expect(r.desde, DateTime(2026, 8, 1));
      expect(r.hasta, DateTime(2026, 8, 8));
    });

    test('el año va del 1 de enero a hoy', () {
      final r = PeriodoDashboard.esteAno.rango(hoy);
      expect(r.desde, DateTime(2026, 1, 1));
      expect(r.hasta, DateTime(2026, 8, 8));
    });
  });

  group('comparación de calendario — el mismo tramo, nunca el mes entero', () {
    test('este mes se compara del 1 al 8 de julio', () {
      final r = PeriodoDashboard.esteMes.rangoAnterior(hoy);

      expect(
        r,
        RangoFechas(DateTime(2026, 7, 1), DateTime(2026, 7, 8)),
        reason:
            'Comparar el 1-8 de agosto contra julio ENTERO haría que todo '
            'negocio pareciera hundirse los primeros veinte días de cada mes.',
      );
      expect(r.hasta, isNot(DateTime(2026, 7, 31)));
    });

    test('hoy se compara con ayer', () {
      final r = PeriodoDashboard.hoy.rangoAnterior(hoy);
      expect(r.desde, DateTime(2026, 8, 7));
      expect(r.hasta, DateTime(2026, 8, 7));
    });

    test('esta semana se compara con el mismo tramo de la semana pasada', () {
      final r = PeriodoDashboard.estaSemana.rangoAnterior(hoy);
      expect(r.desde, DateTime(2026, 7, 27), reason: 'lunes anterior');
      expect(r.hasta, DateTime(2026, 8, 1), reason: 'sábado anterior');
      expect(r.dias, PeriodoDashboard.estaSemana.rango(hoy).dias);
    });

    test('este año se compara con el mismo tramo del año pasado', () {
      final r = PeriodoDashboard.esteAno.rangoAnterior(hoy);
      expect(r.desde, DateTime(2025, 1, 1));
      expect(r.hasta, DateTime(2025, 8, 8));
    });

    test('el 31 de marzo se compara contra el 28 de febrero, no desborda', () {
      // Sin recortar el día, DateTime(2026, 2, 31) se desbordaría al 3 de
      // marzo y la comparación saldría de un mes equivocado.
      final r = PeriodoDashboard.esteMes.rangoAnterior(DateTime(2026, 3, 31));
      expect(r.desde, DateTime(2026, 2, 1));
      expect(r.hasta, DateTime(2026, 2, 28));
    });

    test('en año bisiesto el recorte llega al 29', () {
      final r = PeriodoDashboard.esteMes.rangoAnterior(DateTime(2028, 3, 31));
      expect(r.hasta, DateTime(2028, 2, 29));
    });

    test('el 29 de febrero se compara contra el 28 del año anterior', () {
      final r = PeriodoDashboard.esteAno.rangoAnterior(DateTime(2028, 2, 29));
      expect(r.hasta, DateTime(2027, 2, 28));
    });

    test('en enero, este mes se compara con diciembre del año pasado', () {
      final r = PeriodoDashboard.esteMes.rangoAnterior(DateTime(2026, 1, 15));
      expect(r.desde, DateTime(2025, 12, 1));
      expect(r.hasta, DateTime(2025, 12, 15));
    });
  });

  group('rangos rodantes — "cómo vengo últimamente"', () {
    test('últimos 30 días incluye hoy y mide exactamente 30', () {
      final r = PeriodoDashboard.ultimos30Dias.rango(hoy);
      expect(r.hasta, DateTime(2026, 8, 8));
      expect(r.desde, DateTime(2026, 7, 10));
      expect(r.dias, 30);
    });

    test('la ventana anterior queda pegada y mide lo mismo', () {
      final actual = PeriodoDashboard.ultimos30Dias.rango(hoy);
      final anterior = PeriodoDashboard.ultimos30Dias.rangoAnterior(hoy);

      expect(anterior.dias, actual.dias);
      expect(
        anterior.hasta.add(const Duration(days: 1)),
        actual.desde,
        reason: 'No puede quedar ni un día de hueco ni uno solapado.',
      );
    });

    test('los atajos de 2 a 12 meses salen todos de la misma regla', () {
      for (var m = 2; m <= 12; m++) {
        final periodo = PeriodoDashboard.ultimosMeses(m);
        final actual = periodo.rango(hoy);
        final anterior = periodo.rangoAnterior(hoy);

        expect(actual.hasta, hoy);
        expect(anterior.dias, actual.dias, reason: '$m meses');
        expect(anterior.hasta.add(const Duration(days: 1)), actual.desde);
      }
    });

    test('el trimestre arranca tres meses atrás', () {
      final r = PeriodoDashboard.ultimosMeses(3).rango(hoy);
      expect(r.desde, DateTime(2026, 5, 8));
      expect(r.hasta, DateTime(2026, 8, 8));
    });

    test('doce meses se llama "Último año"', () {
      expect(PeriodoDashboard.ultimosMeses(12).etiqueta, 'Último año');
      expect(PeriodoDashboard.ultimosMeses(3).etiqueta, 'Últimos 3 meses');
    });

    test('un rango libre se compara con los mismos días justo antes', () {
      final elegido = RangoFechas(DateTime(2026, 6, 10), DateTime(2026, 6, 20));
      final periodo = PeriodoDashboard.personalizado(elegido);

      expect(periodo.rango(hoy), elegido);

      final anterior = periodo.rangoAnterior(hoy);
      expect(anterior.dias, 11);
      expect(anterior.hasta, DateTime(2026, 6, 9));
      expect(anterior.desde, DateTime(2026, 5, 30));
    });

    test('el filtro ofrece los atajos sin repetir claves', () {
      final claves = PeriodoDashboard.atajos.map((p) => p.clave).toList();
      expect(claves.toSet().length, claves.length);
      expect(claves, contains('ultimos_2_meses'));
      expect(claves, contains('ultimos_12_meses'));
    });
  });

  group('la regla de oro: sin historia no hay porcentaje', () {
    final rangoAnterior = RangoFechas(
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 8),
    );

    test('con historia y movimiento, calcula la variación', () {
      final c = Comparacion.calcular(
        actual: 1280000,
        anterior: 1081000,
        rangoAnterior: rangoAnterior,
        primeraActividad: DateTime(2026, 1, 15),
      );

      expect(c.estado, EstadoComparacion.disponible);
      expect(c.variacion! * 100, closeTo(18.4, 0.1));
      expect(c.subio, isTrue);
    });

    test('detecta la caída', () {
      final c = Comparacion.calcular(
        actual: 80,
        anterior: 100,
        rangoAnterior: rangoAnterior,
        primeraActividad: DateTime(2026, 1, 15),
      );

      expect(c.variacion, closeTo(-0.2, 0.0001));
      expect(c.bajo, isTrue);
      expect(c.subio, isFalse);
    });

    test('si el negocio no existía, dice "espera" y no un porcentaje', () {
      final c = Comparacion.calcular(
        actual: 500000,
        anterior: 0,
        rangoAnterior: rangoAnterior,
        primeraActividad: DateTime(2026, 7, 10),
      );

      expect(c.estado, EstadoComparacion.historiaInsuficiente);
      expect(
        c.variacion,
        isNull,
        reason: 'Nunca un porcentaje inventado sobre historia que no existe.',
      );
    });

    test('sin ninguna actividad todavía, tampoco compara', () {
      final c = Comparacion.calcular(
        actual: 0,
        anterior: 0,
        rangoAnterior: rangoAnterior,
        primeraActividad: null,
      );

      expect(c.estado, EstadoComparacion.historiaInsuficiente);
      expect(c.variacion, isNull);
    });

    test('existía pero sin movimiento: no es infinito, es otra historia', () {
      final c = Comparacion.calcular(
        actual: 500000,
        anterior: 0,
        rangoAnterior: rangoAnterior,
        primeraActividad: DateTime(2026, 1, 1),
      );

      expect(c.estado, EstadoComparacion.sinMovimientoAnterior);
      expect(
        c.variacion,
        isNull,
        reason: 'Pasar de 0 a algo no se puede expresar como porcentaje.',
      );
    });

    test('dice cuántos meses de historia faltan, redondeando hacia arriba', () {
      // Un trimestre pedido con la historia real del negocio: los datos
      // arrancan el 10 de julio de 2026.
      final periodo = PeriodoDashboard.ultimosMeses(3);
      final c = Comparacion.calcular(
        actual: 1000,
        anterior: 0,
        rangoAnterior: periodo.rangoAnterior(hoy),
        primeraActividad: DateTime(2026, 7, 10),
      );

      expect(c.estado, EstadoComparacion.historiaInsuficiente);
      expect(
        c.mesesDeHistoriaQueFaltan,
        greaterThanOrEqualTo(4),
        reason:
            'Comparar un trimestre pide seis meses de historia y el negocio '
            'lleva uno.',
      );
    });

    test('el borde exacto sí compara: la historia empieza justo ese día', () {
      final c = Comparacion.calcular(
        actual: 10,
        anterior: 5,
        rangoAnterior: rangoAnterior,
        primeraActividad: DateTime(2026, 7, 1),
      );

      expect(c.estado, EstadoComparacion.disponible);
    });

    test('la hora de la primera actividad no adelanta ni atrasa el borde', () {
      // Si la primera venta fue a las 11 de la noche del 1 de julio, el día 1
      // sigue estando cubierto: se compara por fecha, no por instante.
      final c = Comparacion.calcular(
        actual: 10,
        anterior: 5,
        rangoAnterior: rangoAnterior,
        primeraActividad: DateTime(2026, 7, 1, 23, 30),
      );

      expect(c.estado, EstadoComparacion.disponible);
    });
  });

  group('el caso real del negocio hoy', () {
    // Los datos arrancan alrededor del 10 de julio de 2026: poco más de un mes.
    final primeraActividad = DateTime(2026, 7, 10);

    test('los rangos cortos sí se pueden comparar', () {
      for (final periodo in [
        PeriodoDashboard.hoy,
        PeriodoDashboard.estaSemana,
        PeriodoDashboard.ultimos7Dias,
      ]) {
        final c = Comparacion.calcular(
          actual: 100,
          anterior: 90,
          rangoAnterior: periodo.rangoAnterior(hoy),
          primeraActividad: primeraActividad,
        );

        expect(
          c.estado,
          EstadoComparacion.disponible,
          reason: '${periodo.etiqueta} debería poder compararse ya.',
        );
      }
    });

    test('los rangos largos avisan en vez de inventar', () {
      for (var m = 2; m <= 12; m++) {
        final periodo = PeriodoDashboard.ultimosMeses(m);
        final c = Comparacion.calcular(
          actual: 100,
          anterior: 90,
          rangoAnterior: periodo.rangoAnterior(hoy),
          primeraActividad: primeraActividad,
        );

        expect(
          c.estado,
          EstadoComparacion.historiaInsuficiente,
          reason:
              '${periodo.etiqueta} no tiene historia suficiente y no puede '
              'mostrar un porcentaje.',
        );
        expect(c.mesesDeHistoriaQueFaltan, greaterThan(0));
      }
    });
  });
}
