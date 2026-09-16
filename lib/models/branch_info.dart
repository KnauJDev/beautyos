/// Los datos propios de una sede, vistos desde su propio salón (D-242).
///
/// POR QUÉ ES UN MODELO APARTE DE [BranchSubscription]
///
/// Aquel responde *"¿cuánto paga esta sede y hasta cuándo?"* y lo mira el
/// dueño de plataforma. Este responde *"¿quién la lleva y dónde está?"* y lo
/// mira el salón. Comparten columnas en la base pero no pregunta ni permiso:
/// `get_branch_info` está protegida **por sede**, así que un admin de la sede
/// A no puede leer la B.
///
/// Juntarlos obligaría a que la pantalla de Configuración de cada salón
/// arrastrara campos de dinero que no le corresponde ver.
class BranchInfo {
  const BranchInfo({
    required this.branchId,
    required this.branchName,
    required this.isPrimary,
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

  /// Quien lleva ESTA sede. Puede no ser el dueño del negocio (D-239).
  final String? managerName;
  final String? contactEmail;
  final String? contactPhone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? department;

  factory BranchInfo.fromMap(Map<String, dynamic> map) {
    String? texto(Object? valor) {
      final s = valor?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return BranchInfo(
      branchId: map['branch_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      isPrimary: map['is_primary'] == true,
      managerName: texto(map['manager_name']),
      contactEmail: texto(map['contact_email']),
      contactPhone: texto(map['contact_phone']),
      whatsapp: texto(map['whatsapp']),
      address: texto(map['address']),
      city: texto(map['city']),
      department: texto(map['department']),
    );
  }

  /// Si esta sede tiene algún dato propio escrito.
  ///
  /// Sirve para que la pantalla invite a rellenarlos en vez de enseñar siete
  /// casillas vacías sin explicar para qué son.
  bool get tieneDatos =>
      (managerName ?? '').isNotEmpty ||
      (contactEmail ?? '').isNotEmpty ||
      (contactPhone ?? '').isNotEmpty ||
      (whatsapp ?? '').isNotEmpty ||
      (address ?? '').isNotEmpty ||
      (city ?? '').isNotEmpty ||
      (department ?? '').isNotEmpty;
}
