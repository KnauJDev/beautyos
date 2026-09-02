/// Qué lleva hecho un salón nuevo de los cuatro "Primeros pasos"
/// (paso 8.8, D-186).
///
/// Los cuatro llevan al mismo sitio: que el salón **pueda cobrar una cita**.
/// Sin catálogo no se agenda, sin equipo tampoco, sin horario no hay huecos que
/// ofrecer, y la primera cita es el bucle cerrado.
class OnboardingProgress {
  const OnboardingProgress({
    required this.tieneServicios,
    required this.tieneEquipo,
    required this.tieneHorario,
    required this.tienePrimeraCita,
    required this.pasosCompletos,
    required this.pasosTotales,
    required this.descartado,
  });

  /// Cuando no se pudo consultar. **No se muestra la lista**: ante la duda, no
  /// molestar a un salón que probablemente ya está trabajando.
  const OnboardingProgress.desconocido()
    : tieneServicios = true,
      tieneEquipo = true,
      tieneHorario = true,
      tienePrimeraCita = true,
      pasosCompletos = 4,
      pasosTotales = 4,
      descartado = true;

  final bool tieneServicios;
  final bool tieneEquipo;
  final bool tieneHorario;
  final bool tienePrimeraCita;
  final int pasosCompletos;
  final int pasosTotales;

  /// El negocio pulsó "ya lo tengo listo". Va por negocio, no por persona: si
  /// el dueño la cierra, el administrador tampoco la vuelve a ver.
  final bool descartado;

  factory OnboardingProgress.fromMap(Map<String, dynamic> map) {
    final servicios = map['tiene_servicios'] == true;
    final equipo = map['tiene_equipo'] == true;
    final horario = map['tiene_horario'] == true;
    final cita = map['tiene_primera_cita'] == true;

    final completos = map['pasos_completos'];

    return OnboardingProgress(
      tieneServicios: servicios,
      tieneEquipo: equipo,
      tieneHorario: horario,
      tienePrimeraCita: cita,
      pasosCompletos: completos is int
          ? completos
          : int.tryParse(completos?.toString() ?? '') ??
                // Si el conteo no llegara, se recalcula aquí en vez de mostrar
                // "0 de 4" con los pasos marcados.
                [servicios, equipo, horario, cita].where((x) => x).length,
      pasosTotales: map['pasos_totales'] is int
          ? map['pasos_totales'] as int
          : 4,
      descartado: map['descartado'] == true,
    );
  }

  bool get todoListo => pasosCompletos >= pasosTotales;

  /// Si hay algo que enseñarle al salón. Una vez descartada no vuelve, y
  /// terminada tampoco: la lista tiene un final, no es un adorno permanente.
  bool get debeMostrarse => !descartado && !todoListo;
}
