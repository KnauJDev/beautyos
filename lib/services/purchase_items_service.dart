import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase_item_summary.dart';

class PurchaseItemsService {
  const PurchaseItemsService({required this.branchId});

  final String? branchId;

  Future<List<PurchaseItemSummary>> getPurchaseItemsSummary() async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_purchase_items_summary'
          : 'get_purchase_items_summary_v2',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return response
        .map<PurchaseItemSummary>(
          (item) => PurchaseItemSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
