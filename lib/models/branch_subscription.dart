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
    this.currentPeriodEnd,
    this.activatedAt,
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
  final DateTime? currentPeriodEnd;
  final DateTime? activatedAt;

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
      currentPeriodEnd: DateTime.tryParse(
        map['current_period_end']?.toString() ?? '',
      ),
      activatedAt: DateTime.tryParse(map['activated_at']?.toString() ?? ''),
    );
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
