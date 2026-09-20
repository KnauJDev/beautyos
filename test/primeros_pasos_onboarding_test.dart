import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/onboarding_progress.dart';

/// **Actualizado el 20-sep por el hallazgo AJ:** los pasos pasaron de cuatro a
/// cinco. Las filas de abajo mandaban `pasos_totales: 4` a mano, así que
/// habrían seguido en verde describiendo una forma que el servidor ya no
/// manda — que es justo la clase de mentira silenciosa que este proyecto
/// persigue desde D-129.
void main() {
  group('Paso 8.8 — Primeros pasos: lo que llega de la base', () {
    test('fromMap lee los cinco pasos y el conteo', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': true,
        'tiene_horario': false,
        'tiene_primera_cita': false,
        'tiene_comision': false,
        'pasos_completos': 2,
        'pasos_totales': 5,
        'descartado': false,
      });

      expect(p.tieneServicios, true);
      expect(p.tieneEquipo, true);
      expect(p.tieneHorario, false);
      expect(p.tienePrimeraCita, false);
      expect(p.tieneComision, false);
      expect(p.pasosCompletos, 2);
      expect(p.pasosTotales, 5);
      expect(p.todoListo, false);
      expect(p.debeMostrarse, true);
    });

    test('si el conteo no llega, se recalcula con los pasos', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': false,
        'tiene_horario': true,
        'tiene_primera_cita': false,
        'tiene_comision': true,
      });

      // Sin esto se veria "0 de 5" con tres pasos ya tachados, que es peor que
      // no mostrar nada.
      expect(p.pasosCompletos, 3);
      expect(p.pasosTotales, 5);
    });

    test('un salón que no ha hecho nada muestra la lista entera', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': false,
        'tiene_equipo': false,
        'tiene_horario': false,
        'tiene_primera_cita': false,
        'tiene_comision': false,
        'pasos_completos': 0,
        'pasos_totales': 5,
        'descartado': false,
      });

      expect(p.pasosCompletos, 0);
      expect(p.debeMostrarse, true);
    });
  });

  group('Paso 8.8 — La lista tiene un final', () {
    test('con los cinco pasos hechos deja de mostrarse sola', () {
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': true,
        'tiene_horario': true,
        'tiene_primera_cita': true,
        'tiene_comision': true,
        'pasos_completos': 5,
        'pasos_totales': 5,
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
        'tiene_comision': false,
        'pasos_completos': 1,
        'pasos_totales': 5,
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
      expect(p.pasosTotales, 5);
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

  group('AJ — el quinto paso: confirmar cuánto gana el equipo', () {
    test('cuatro de cinco: la lista sigue viva solo por la comisión', () {
      // Es el caso de todos los salones de la base el 20-sep: montados,
      // cobrando, y con un 40% que nadie miró.
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': true,
        'tiene_horario': true,
        'tiene_primera_cita': true,
        'tiene_comision': false,
        'pasos_completos': 4,
        'pasos_totales': 5,
        'descartado': false,
      });

      expect(p.tieneComision, false);
      expect(p.todoListo, false);
      expect(
        p.debeMostrarse,
        true,
        reason: 'antes de AJ este salón daba la lista por terminada',
      );
    });

    test('un salón sin el campo no se da por confirmado', () {
      // Si la base fuera vieja y no mandara `tiene_comision`, la lectura debe
      // caer del lado de avisar. Dar por buena una cifra que decide un sueldo
      // porque falta un campo es exactamente el fallo que AJ describe.
      final p = OnboardingProgress.fromMap({
        'tiene_servicios': true,
        'tiene_equipo': true,
        'tiene_horario': true,
        'tiene_primera_cita': true,
        'pasos_completos': 4,
        'pasos_totales': 5,
        'descartado': false,
      });

      expect(p.tieneComision, false);
    });

    test('pero si no se pudo consultar nada, no se acusa a nadie', () {
      // La excepción a la regla de arriba, y es deliberada: `desconocido()`
      // significa que no hubo respuesta, no que la respuesta fuera "no".
      // Mismo criterio que D-184.
      const p = OnboardingProgress.desconocido();
      expect(p.tieneComision, true);
    });
  });
}
