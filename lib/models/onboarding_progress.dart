/// Qué lleva hecho un salón nuevo de los cinco "Primeros pasos"
/// (paso 8.8, D-186; el quinto desde el hallazgo **AJ**).
///
/// Los cuatro primeros llevan al mismo sitio: que el salón **pueda cobrar una
/// cita**. Sin catálogo no se agenda, sin equipo tampoco, sin horario no hay
/// huecos que ofrecer, y la primera cita es el bucle cerrado.
///
/// **El quinto llegó porque cobrar no es lo último que pasa: después hay que
/// pagarle a alguien.** El salón nacía con una comisión del 40% que nadie le
/// pedía confirmar, heredada de un default de tabla, y esa cifra decide lo que
/// gana una persona. Se comprobó con dinero real el 18-sep: \$7.200 sobre un
/// servicio de \$18.000, generados sin que nadie los aprobara nunca.
class OnboardingProgress {
  const OnboardingProgress({
    required this.tieneServicios,
    required this.tieneEquipo,
    required this.tieneHorario,
    required this.tienePrimeraCita,
    required this.tieneComision,
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
      tieneComision = true,
      pasosCompletos = 5,
      pasosTotales = 5,
      descartado = true;

  final bool tieneServicios;
  final bool tieneEquipo;
  final bool tieneHorario;
  final bool tienePrimeraCita;

  /// Alguien guardó la comisión a propósito. **Falso no significa que no haya
  /// comisión**: significa que la que hay es la que vino de fábrica (AJ).
  final bool tieneComision;

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
    final comision = map['tiene_comision'] == true;

    final completos = map['pasos_completos'];

    return OnboardingProgress(
      tieneServicios: servicios,
      tieneEquipo: equipo,
      tieneHorario: horario,
      tienePrimeraCita: cita,
      tieneComision: comision,
      pasosCompletos: completos is int
          ? completos
          : int.tryParse(completos?.toString() ?? '') ??
                // Si el conteo no llegara, se recalcula aquí en vez de mostrar
                // "0 de 5" con los pasos marcados.
                [
                  servicios,
                  equipo,
                  horario,
                  cita,
                  comision,
                ].where((x) => x).length,
      pasosTotales: map['pasos_totales'] is int
          ? map['pasos_totales'] as int
          : 5,
      descartado: map['descartado'] == true,
    );
  }

  bool get todoListo => pasosCompletos >= pasosTotales;

  /// Si hay algo que enseñarle al salón. Una vez descartada no vuelve, y
  /// terminada tampoco: la lista tiene un final, no es un adorno permanente.
  bool get debeMostrarse => !descartado && !todoListo;
}
