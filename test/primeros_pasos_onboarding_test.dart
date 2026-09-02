import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/onboarding_progress.dart';

void main() {
  group('Paso 8.8 — Primeros pasos: lo que llega de la base', () {
    test('fromMap lee los cuatro pasos y el conteo', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': true,
        'tiene_horario': false,
        'tiene_primera_cita': false,
        'pasos_completos': 2,
        'pasos_totales': 4,
        'descartado': false,
      });

      expect(p.tieneServicios, true);
      expect(p.tieneEquipo, true);
      expect(p.tieneHorario, false);
      expect(p.tienePrimeraCita, false);
      expect(p.pasosCompletos, 2);
      expect(p.pasosTotales, 4);
      expect(p.todoListo, false);
      expect(p.debeMostrarse, true);
    });

    test('si el conteo no llega, se recalcula con los pasos', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': false,
        'tiene_horario': true,
        'tiene_primera_cita': false,
        'descartado': false,
      });

      // Sin esto se veria "0 de 4" con dos pasos ya tachados, que es peor que
      // no mostrar nada.
      expect(p.pasosCompletos, 2);
      expect(p.pasosTotales, 4);
    });

    test('un salón que no ha hecho nada muestra la lista entera', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': false,
        'tiene_equipo': false,
        'tiene_horario': false,
        'tiene_primera_cita': false,
        'pasos_completos': 0,
        'pasos_totales': 4,
        'descartado': false,
      });

      expect(p.pasosCompletos, 0);
      expect(p.debeMostrarse, true);
    });
  });

  group('Paso 8.8 — La lista tiene un final', () {
    test('con los cuatro pasos hechos deja de mostrarse sola', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': true,
        'tiene_horario': true,
        'tiene_primera_cita': true,
        'pasos_completos': 4,
        'pasos_totales': 4,
        'descartado': false,
      });

      expect(p.todoListo, true);
      // Nadie tiene que cerrarla: una lista de tareas terminada que sigue
      // ocupando el tablero deja de ser ayuda y pasa a ser ruido.
      expect(p.debeMostrarse, false);
    });

    test('descartada no se muestra aunque falten pasos', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': false,
        'tiene_horario': false,
        'tiene_primera_cita': false,
        'pasos_completos': 1,
        'pasos_totales': 4,
        'descartado': true,
      });

      expect(p.todoListo, false);
      expect(p.debeMostrarse, false);
    });

    // Mismo criterio que los candados de plan (D-184): ante la duda, no
    // molestar a un salón que probablemente ya está trabajando.
    test('si no se pudo consultar, no se muestra nada', () {
      const p = OnboardingProgress.desconocido();

      expect(p.debeMostrarse, false);
      expect(p.todoListo, true);
    });

    test('una respuesta vacía o rara no enseña una lista falsa', () {
      final p = OnboardingProgress.fromMap(<String, dynamic>{});

      // Todo en false y conteo 0: la lista se mostraría entera. Es lo correcto
      // para un salón recién creado, que es justo el caso en el que la base
      // devuelve todos los campos en false.
      expect(p.pasosCompletos, 0);
      expect(p.tieneServicios, false);
      expect(p.descartado, false);
    });
  });
}
