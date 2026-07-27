import 'package:supabase_flutter/supabase_flutter.dart';

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
}
