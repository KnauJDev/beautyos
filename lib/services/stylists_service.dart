import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stylist_for_invitation.dart';
import '../models/stylist_management_item.dart';
import '../models/stylist_summary.dart';

class StylistsService {
  const StylistsService();

  Future<List<StylistSummary>> getStylistsSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_stylists_summary');

    return response
        .map<StylistSummary>((item) => StylistSummary.fromMap(item))
        .toList();
  }

  /// Los estilistas que se pueden invitar **en esta sede**, marcando cuáles ya
  /// tienen cuenta activa (hallazgo R, D-132).
  ///
  /// Es distinta de `getStylistsSummary`, que responde por todo el negocio: el
  /// diálogo de invitar mostraba estilistas de otras sedes y la invitación se
  /// rechazaba **después** de llenar el formulario.
  Future<List<StylistForInvitation>> getStylistsForInvitation(
    String branchId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'get_stylists_for_invitation',
      params: {'p_branch_id': branchId},
    );

    return (response as List)
        .map<StylistForInvitation>(
          (item) => StylistForInvitation.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<StylistManagementItem>> getStylistsForManagement(
    String branchId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'get_stylists_for_management',
      params: {'p_branch_id': branchId},
    );

    return (response as List)
        .map(
          (item) => StylistManagementItem.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> createStylist({
    required String branchId,
    required String name,
    String? phone,
    String? specialty,
    String? bio,
  }) async {
    await Supabase.instance.client.rpc(
      'create_stylist',
      params: {
        'p_branch_id': branchId,
        'p_name': name,
        'p_phone': phone,
        'p_specialty': specialty,
        'p_bio': bio,
      },
    );
  }

  Future<void> updateStylist({
    required String branchId,
    required String stylistId,
    required String name,
    String? phone,
    String? specialty,
    String? photoUrl,
    String? bio,
  }) async {
    await Supabase.instance.client.rpc(
      'update_stylist',
      params: {
        'p_branch_id': branchId,
        'p_stylist_id': stylistId,
        'p_name': name,
        'p_phone': phone,
        'p_specialty': specialty,
        'p_photo_url': photoUrl,
        'p_bio': bio,
      },
    );
  }

  Future<void> setStylistActive({
    required String branchId,
    required String stylistId,
    required bool active,
  }) async {
    await Supabase.instance.client.rpc(
      'set_stylist_active',
      params: {
        'p_branch_id': branchId,
        'p_stylist_id': stylistId,
        'p_active': active,
      },
    );
  }
}
