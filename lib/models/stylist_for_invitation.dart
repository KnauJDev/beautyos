/// Un estilista del catálogo tal y como lo necesita el diálogo de invitar
/// (hallazgo R, D-132).
///
/// **Por qué es un modelo aparte de `StylistSummary`:** esta lista viene de
/// `get_stylists_for_invitation`, que responde por **una sede concreta** y dice
/// además si ese estilista **ya tiene una cuenta activa**. `StylistSummary`
/// responde por todo el negocio y no sabe nada de cuentas: son dos preguntas
/// distintas y mezclarlas obligaría a tocar una función cuyos permisos reales
/// no se pueden leer del respaldo.
class StylistForInvitation {
  final String id;
  final String name;

  /// `true` si ese estilista del catálogo ya tiene una cuenta activa en el
  /// negocio. Invitar a otra se rechaza en la base de datos.
  final bool hasActiveAccount;

  const StylistForInvitation({
    required this.id,
    required this.name,
    required this.hasActiveAccount,
  });

  factory StylistForInvitation.fromMap(Map<String, dynamic> map) {
    return StylistForInvitation(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      // Tolerante a propósito: si el servidor mandara vacío, se asume que NO
      // tiene cuenta y el candado de la base sigue protegiendo. Depender de
      // que el servidor nunca mande nulo es la suposición que causó D-123.
      hasActiveAccount: map['has_active_account'] == true,
    );
  }
}
