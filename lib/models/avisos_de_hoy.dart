/// La campana de avisos de los cinco lugares (D-318; reactivada por D-304).
///
/// **Lo básico**, decidido por el propietario el 07-oct: las citas de hoy sin
/// confirmar, los clientes para invitar a volver, el inventario bajo y las
/// sedes por vencer. Cada aviso lleva al módulo donde se resuelve.
///
/// Aquí solo vive lo que se puede probar sin servidor: los números y las
/// frases. Quien los carga es `AvisosService`.
library;

class SedePorVencer {
  const SedePorVencer({
    required this.nombre,
    required this.dias,
    required this.vencida,
  });

  final String nombre;

  /// Días que le quedan. `null` si no se sabe.
  final int? dias;
  final bool vencida;
}

/// Un aviso de la campana: qué dice y adónde lleva (el título del módulo,
/// el mismo de `_irAModulo`).
class AvisoDeLaCampana {
  const AvisoDeLaCampana({
    required this.texto,
    required this.destino,
    this.filtroDeClientes,
    this.urgente = false,
  });

  final String texto;
  final String destino;

  /// Para abrir Clientes ya filtrado (`para_invitar`).
  final String? filtroDeClientes;

  /// Rojo y no ámbar: una sede vencida deja de recibir citas.
  final bool urgente;
}

class AvisosDeHoy {
  const AvisosDeHoy({
    this.sinConfirmar = 0,
    this.paraInvitar = 0,
    this.inventarioBajo = 0,
    this.sedes = const <SedePorVencer>[],
  });

  static const vacio = AvisosDeHoy();

  /// Citas de hoy que siguen sin confirmar. Sin caja no hay: nacen
  /// confirmadas (D-312).
  final int sinConfirmar;

  /// Clientes a los que ya les toca volver (D-314).
  final int paraInvitar;

  /// Productos activos en su mínimo o por debajo.
  final int inventarioBajo;

  /// Sedes vencidas o a 5 días o menos de vencer (solo las ve la dueña).
  final List<SedePorVencer> sedes;

  List<AvisoDeLaCampana> get lista => [
    if (sinConfirmar > 0)
      AvisoDeLaCampana(
        texto: sinConfirmar == 1
            ? '1 cita de hoy sin confirmar'
            : '$sinConfirmar citas de hoy sin confirmar',
        destino: 'Agenda',
      ),
    if (paraInvitar > 0)
      AvisoDeLaCampana(
        texto: paraInvitar == 1
            ? '1 cliente para invitar hoy: ya le toca volver'
            : '$paraInvitar clientes para invitar hoy: ya les toca volver',
        destino: 'Clientes',
        filtroDeClientes: 'para_invitar',
      ),
    if (inventarioBajo > 0)
      AvisoDeLaCampana(
        texto: inventarioBajo == 1
            ? '1 producto por debajo del mínimo'
            : '$inventarioBajo productos por debajo del mínimo',
        destino: 'Inventario',
      ),
    for (final s in sedes)
      AvisoDeLaCampana(
        texto: s.vencida
            ? 'La sede ${s.nombre} está vencida: no recibe citas nuevas'
            : s.dias == null
            ? 'La sede ${s.nombre} vence pronto'
            : s.dias! <= 1
            ? 'La sede ${s.nombre} vence mañana'
            : 'La sede ${s.nombre} vence en ${s.dias} días',
        destino: 'Configuración',
        urgente: s.vencida,
      ),
  ];

  int get cuantos => lista.length;
}
