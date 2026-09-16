import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_info.dart';

class BranchesService {
  const BranchesService();

  Future<void> createBranch({
    required String name,
    String? address,
    String? city,
  }) async {
    await Supabase.instance.client.rpc(
      'create_branch',
      params: {'p_name': name, 'p_address': address, 'p_city': city},
    );
  }

  /// Los datos propios de UNA sede (D-242, paso 9.43).
  ///
  /// La RPC esta protegida **por sede** y no por negocio: un admin de la sede
  /// A no puede leer la B. Antes no hacia falta preguntarlo porque no habia
  /// nada que leer -- `get_business_settings` devolvia siempre la direccion de
  /// la sede principal, mirases la sede que mirases.
  Future<BranchInfo?> getBranchInfo(String branchId) async {
    final respuesta = await Supabase.instance.client.rpc(
      'get_branch_info',
      params: {'p_branch_id': branchId},
    );

    if (respuesta is List && respuesta.isNotEmpty) {
      return BranchInfo.fromMap(Map<String, dynamic>.from(respuesta.first));
    }
    return null;
  }

  /// Escribe los datos propios de UNA sede (D-242, paso 9.43).
  ///
  /// **Manda los siete campos siempre.** La RPC no conserva nada: vacio
  /// significa vacio, igual que su hermana del Panel (D-241) y al reves de lo
  /// que hacia la de precios antes de D-237, donde `null` conservaba y por eso
  /// se podia poner un precio pero nunca quitarlo.
  ///
  /// Quien la llame debe mandar el formulario entero.
  Future<void> updateBranchInfo({
    required String branchId,
    required String? managerName,
    required String? contactEmail,
    required String? contactPhone,
    required String? whatsapp,
    required String? address,
    required String? city,
    required String? department,
  }) async {
    await Supabase.instance.client.rpc(
      'update_branch_info',
      params: {
        'p_branch_id': branchId,
        'p_manager_name': managerName,
        'p_contact_email': contactEmail,
        'p_contact_phone': contactPhone,
        'p_whatsapp': whatsapp,
        'p_address': address,
        'p_city': city,
        'p_department': department,
      },
    );
  }
}
