import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_context.dart';

class BranchContextService {
  const BranchContextService();

  Future<List<BranchContext>> getAccessibleBranches() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_branch_context_v2',
    );
    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => BranchContext.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }
}
