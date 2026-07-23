import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    await Supabase.instance.client.rpc(
      'create_stylist',
      params: {
        'p_branch_id': branchId,
        'p_name': name,
        'p_phone': phone,
        'p_specialty': specialty,
      },
    );
  }

  Future<void> updateStylist({
    required String branchId,
    required String stylistId,
    required String name,
    String? phone,
    String? specialty,
  }) async {
    await Supabase.instance.client.rpc(
      'update_stylist',
      params: {
        'p_branch_id': branchId,
        'p_stylist_id': stylistId,
        'p_name': name,
        'p_phone': phone,
        'p_specialty': specialty,
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
