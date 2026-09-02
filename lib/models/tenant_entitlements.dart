/// Lo que el plan del negocio permite hacer, tal como lo resuelve el backend
/// (`get_my_entitlements()`, existente desde el 22-jul).
///
/// **Por qué existe esto (TL-19, D-184).** El backend hacía cumplir los planes
/// desde el principio (D-069, D-124, D-136) pero la interfaz **nunca preguntaba
/// nada**: `BeautyModule` solo filtraba por rol. Un salón en plan Básico veía
/// Inventario en su menú, entraba, pulsaba "Guardar" y recibía en pantalla
/// `PostgrestException: beautyos_require_entitlement: Plan no autorizado`.
///
/// El dueño no concluye "debo mejorar mi plan": concluye que el software está
/// roto. Y de paso se pierde la venta, porque toda la escalera de precios de
/// D-124 era invisible dentro del producto.
class TenantEntitlements {
  const TenantEntitlements({
    required this.porClave,
    required this.limitesPorClave,
    required this.consultado,
  });

  /// Sin datos todavía, o no aplica (un cliente final, o el dueño de la
  /// plataforma, que no tienen membresía de negocio).
  ///
  /// **Deja pasar todo a propósito.** Ver `permite()`.
  const TenantEntitlements.desconocido()
    : porClave = const {},
      limitesPorClave = const {},
      consultado = false;

  final Map<String, bool> porClave;
  final Map<String, int?> limitesPorClave;

  /// `true` solo si la consulta se hizo y respondió. Si es `false`, no se sabe
  /// nada y no se bloquea nada.
  final bool consultado;

  factory TenantEntitlements.fromList(List<dynamic> filas) {
    final porClave = <String, bool>{};
    final limites = <String, int?>{};

    for (final fila in filas) {
      if (fila is! Map) continue;
      final mapa = Map<String, dynamic>.from(fila);
      final clave = mapa['feature_key']?.toString();
      if (clave == null || clave.isEmpty) continue;

      porClave[clave] = mapa['entitled'] == true;

      final limite = mapa['limit_value'];
      limites[clave] = limite is int
          ? limite
          : int.tryParse(limite?.toString() ?? '');
    }

    return TenantEntitlements(
      porClave: porClave,
      limitesPorClave: limites,
      consultado: true,
    );
  }

  /// ¿El plan del negocio incluye esta capacidad?
  ///
  /// **Falla ABIERTO a propósito, y conviene entender por qué.** Si la consulta
  /// no se pudo hacer (`consultado == false`) o la clave no vino en la
  /// respuesta, esto devuelve `true` y la interfaz no bloquea nada.
  ///
  /// Es lo contrario de lo que se hizo en el perímetro de pagos (D-181, D-182),
  /// donde todo falla cerrado — y es deliberado: **aquí la interfaz no es la
  /// frontera de seguridad.** Quien impide de verdad la operación es el backend,
  /// con `beautyos_require_entitlement` dentro de las RPC. Este candado es de
  /// cortesía: sirve para explicar en vez de reventar.
  ///
  /// Si fallara cerrado, un fallo de red dejaría a un salón que SÍ paga sin
  /// acceso a sus propios módulos. Ese daño es real e inmediato; el de fallar
  /// abierto es que alguien vea una pantalla que su plan no cubre y reciba el
  /// error del backend, que es exactamente lo que pasaba antes de este cambio.
  bool permite(String? clave) {
    if (clave == null || clave.isEmpty) return true;
    if (!consultado) return true;
    return porClave[clave] ?? true;
  }

  int? limiteDe(String clave) => limitesPorClave[clave];

  /// Las capacidades que el plan actual NO cubre, para poder decir en la
  /// pantalla de mejora qué se gana al subir.
  List<String> get bloqueadas => porClave.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toList(growable: false);
}

/// Las claves que usa `public.features`, para no escribirlas sueltas por ahí.
///
/// Deben coincidir con las sembradas en `20260722184914` y con las que exige
/// `beautyos_require_entitlement` en las RPC. Si alguna vez se añade una
/// capacidad nueva en SQL, esta lista es donde se refleja.
abstract final class ClaveDeCapacidad {
  static const inventario = 'inventory';
  static const reportesFinancieros = 'financial_reports';
  static const portafolio = 'portfolio';
  static const resenas = 'reviews';
  static const publicacionRedes = 'social_publishing';

  /// Límites numéricos, no módulos: se leen con `limiteDe`, no con `permite`.
  static const sedes = 'branches';
  static const cuentasDeEquipo = 'team_members';
}
