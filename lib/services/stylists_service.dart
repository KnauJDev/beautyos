import 'package:supabase_flutter/supabase_flutter.dart';

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
}
