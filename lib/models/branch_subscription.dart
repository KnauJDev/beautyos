/// El estado de pago de una sede (D-190, D-193).
///
/// Viene de `get_branch_subscriptions()`, que ya existía desde la Etapa 2 y
/// hasta ahora no la llamaba nadie: se construyó antes que la pantalla a
/// propósito, porque enseñar "esta sede está pendiente" sin un botón para
/// pagarla es frustración, no información.
class BranchSubscription {
  const BranchSubscription({
    required this.branchId,
    required this.branchName,
    required this.isPrimary,
    required this.branchActive,
    required this.status,
    required this.alDia,
    required this.precioCop,
    required this.motivoPrecio,
    this.tienePrecioPactado = false,
    this.currentPeriodEnd,
    this.activatedAt,
    this.managerName,
    this.contactEmail,
    this.contactPhone,
    this.whatsapp,
    this.address,
    this.city,
    this.department,
  });

  final String branchId;
  final String branchName;
  final bool isPrimary;

  /// Si la sede está activa **operativamente**. No es lo mismo que estar al
  /// día: una sede puede estar abierta y en mora.
  final bool branchActive;

  final String status;

  /// Lo que la pantalla necesita saber de verdad. Lo calcula el servidor para
  /// que "al día" signifique lo mismo aquí y allá.
  final bool alDia;

  final int precioCop;
  final String motivoPrecio;

  /// Si el precio de arriba es un **acuerdo** o simplemente el de lista.
  ///
  /// `precioCop` es el precio EFECTIVO: cuando no hay nada pactado, el
  /// servidor devuelve el de lista. Sin esta bandera, la pantalla no podia
  /// distinguir "pactado 150.000" de "sin pactar, lista 150.000", y la unica
  /// pista era comparar el texto del motivo -- una cadena pensada para leerse,
  /// decidiendo sobre dinero (D-237).
  final bool tienePrecioPactado;
  final DateTime? currentPeriodEnd;
  final DateTime? activatedAt;

  // --------------------------------------------------------------------------
  // Los datos propios de la sede (D-241).
  //
  // Opcionales porque este mismo modelo lo llena tambien
  // `get_branch_subscriptions()`, que es la que ve el SALON y no devuelve
  // estos campos: al salon no le hace falta que se los cuenten, son suyos.
  // Solo `platform_get_tenant_branches` los trae.
  //
  // Las columnas existen en `branches` desde el 20-jul y estuvieron dos meses
  // sin que nadie las escribiera. El dato no faltaba: faltaba la puerta.
  // --------------------------------------------------------------------------

  /// Quien lleva ESTA sede. El dueno del negocio puede no ser el encargado de
  /// ninguna (D-239), por eso es dato de la sede.
  final String? managerName;
  final String? contactEmail;
  final String? contactPhone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? department;

  /// Si esta sede tiene algun dato propio escrito.
  ///
  /// Sirve para que la pantalla diga "sin datos propios todavia" en vez de
  /// ensenar siete guiones, que parece un error de carga.
  bool get tieneDatosPropios =>
      (managerName ?? '').isNotEmpty ||
      (contactEmail ?? '').isNotEmpty ||
      (contactPhone ?? '').isNotEmpty ||
      (whatsapp ?? '').isNotEmpty ||
      (address ?? '').isNotEmpty ||
      (city ?? '').isNotEmpty ||
      (department ?? '').isNotEmpty;

  factory BranchSubscription.fromMap(Map<String, dynamic> map) {
    final precio = map['precio_cop'];

    return BranchSubscription(
      branchId: map['branch_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      isPrimary: map['is_primary'] == true,
      branchActive: map['branch_active'] == true,
      status: map['status']?.toString() ?? 'pending',
      alDia: map['al_dia'] == true,
      precioCop: precio is int
          ? precio
          : int.tryParse(precio?.toString() ?? '') ?? 0,
      motivoPrecio: map['motivo_precio']?.toString() ?? 'Precio de lista',
      tienePrecioPactado: map['tiene_precio_pactado'] == true,
      currentPeriodEnd: DateTime.tryParse(
        map['current_period_end']?.toString() ?? '',
      ),
      activatedAt: DateTime.tryParse(map['activated_at']?.toString() ?? ''),
      managerName: _texto(map['manager_name']),
      contactEmail: _texto(map['contact_email']),
      contactPhone: _texto(map['contact_phone']),
      whatsapp: _texto(map['whatsapp']),
      address: _texto(map['address']),
      city: _texto(map['city']),
      department: _texto(map['department']),
    );
  }

  /// Texto que puede no venir --el lector del salon no manda estos campos-- y
  /// que si viene vacio vale lo mismo que no venir.
  static String? _texto(Object? valor) {
    final s = valor?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  /// Nunca se ha pagado. Es distinto de "se cayó": una sede que se dio de alta
  /// y jamás se activó no ha tenido nunca un período.
  bool get nuncaActivada => activatedAt == null;

  /// Lo que se le dice al dueño, en su idioma y no en el de la base de datos.
  String get etiquetaEstado {
    if (alDia) return 'Al día';
    switch (status) {
      case 'pending':
        return nuncaActivada ? 'Pendiente de activar' : 'Pendiente de pago';
      case 'past_due':
        return 'Pago vencido';
      case 'grace':
        return 'En período de gracia';
      case 'suspended':
        return 'Suspendida';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }
}
