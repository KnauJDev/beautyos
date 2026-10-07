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
    this.fuentesPorClave = const {},
  });

  /// Sin datos todavía, o no aplica (un cliente final, o el dueño de la
  /// plataforma, que no tienen membresía de negocio).
  ///
  /// **Deja pasar todo a propósito.** Ver `permite()`.
  const TenantEntitlements.desconocido()
    : porClave = const {},
      limitesPorClave = const {},
      consultado = false,
      fuentesPorClave = const {};

  final Map<String, bool> porClave;
  final Map<String, int?> limitesPorClave;

  /// De dónde sale cada decisión, tal como la devuelve el servidor: `plan`,
  /// `override` (una excepción puesta desde el Panel), `no_incluida_en_plan`…
  /// D-310: con esto se distingue lo que el plan no trae (candado, D-184) de lo
  /// que la plataforma le apagó a este negocio (se esconde).
  final Map<String, String> fuentesPorClave;

  /// `true` solo si la consulta se hizo y respondió. Si es `false`, no se sabe
  /// nada y no se bloquea nada.
  final bool consultado;

  factory TenantEntitlements.fromList(List<dynamic> filas) {
    final porClave = <String, bool>{};
    final limites = <String, int?>{};
    final fuentes = <String, String>{};

    for (final fila in filas) {
      if (fila is! Map) continue;
      final mapa = Map<String, dynamic>.from(fila);
      final clave = mapa['feature_key']?.toString();
      if (clave == null || clave.isEmpty) continue;

      porClave[clave] = mapa['entitled'] == true;
      final fuente = mapa['source']?.toString();
      if (fuente != null) fuentes[clave] = fuente;

      final limite = mapa['limit_value'];
      limites[clave] = limite is int
          ? limite
          : int.tryParse(limite?.toString() ?? '');
    }

    return TenantEntitlements(
      porClave: porClave,
      limitesPorClave: limites,
      consultado: true,
      fuentesPorClave: fuentes,
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

  /// ¿La plataforma le APAGÓ esta capacidad a este negocio desde el Panel?
  /// (D-310, paso 1 del plan del primer cliente real, D-308.)
  ///
  /// Es distinto de que el plan no la traiga. Lo que el plan no trae se sigue
  /// viendo con candado, para no matar la venta (D-184). Lo que el propietario
  /// apagó a propósito —a David, que solo quiere agenda— **desaparece**: un
  /// candado ahí sería un estorbo que nadie va a comprar.
  ///
  /// Falla en `false` (se ve) igual que [permite] falla en `true`: si la
  /// consulta no respondió, no se esconde nada.
  /// Encendida **de verdad**: se consultó y la respuesta fue sí (D-318).
  ///
  /// [permite] da `true` cuando no se pudo consultar o la clave no vino, para
  /// no bloquear a nadie por un fallo de red. Para una capacidad que nace
  /// apagada eso sería encenderla sin querer, así que se pregunta por aquí.
  bool encendido(String clave) => consultado && porClave[clave] == true;

  bool apagadoPorLaPlataforma(String? clave) {
    if (clave == null || clave.isEmpty || !consultado) return false;
    return porClave[clave] == false && fuentesPorClave[clave] == 'override';
  }

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

  /// D-310: nacen para poder apagárselas a un negocio desde el Panel. Entran
  /// encendidas en todos los planes (`20261002180000`).
  static const cajaYCobros = 'cash_register';
  static const comisiones = 'commissions';
  static const blog = 'blog';

  /// D-317: el Dashboard con su propio interruptor, separado de
  /// [reportesFinancieros], que se queda con Reportes. Encendida en todos los
  /// planes (`20261004100000`).
  static const dashboard = 'dashboard';

  /// D-318: la app en cinco lugares (Agenda, Clientes, Mi negocio, Mi vitrina,
  /// Ajustes). **Nace apagada** en todos los planes (`20261007100000`) y la
  /// plataforma la enciende salón por salón. Se pregunta con
  /// [TenantEntitlements.encendido], no con `permite`.
  static const cincoLugares = 'cinco_lugares';

  /// Límites numéricos, no módulos: se leen con `limiteDe`, no con `permite`.
  static const sedes = 'branches';
  static const cuentasDeEquipo = 'team_members';
}
