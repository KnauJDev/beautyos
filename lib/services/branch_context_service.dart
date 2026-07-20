import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_context.dart';
import '../models/my_profile.dart';

class BranchContextService {
  const BranchContextService();

  Future<List<BranchContext>> getAccessibleBranches({
    required MyProfile profile,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_my_branch_context_v2',
      );
      final rows = response as List<dynamic>;

      return rows
          .map(
            (row) => BranchContext.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (!_isMissingV2Function(error)) {
        rethrow;
      }

      return [
        BranchContext.legacy(
          tenantId: profile.tenantId,
          tenantName: profile.tenantName ?? 'Negocio BeautyOS',
          role: profile.role,
        ),
      ];
    }
  }

  bool _isMissingV2Function(PostgrestException error) {
    return error.code == 'PGRST202' ||
        error.message.contains('get_my_branch_context_v2');
  }
}
