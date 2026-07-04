import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase_item_summary.dart';

class PurchaseItemsService {
  const PurchaseItemsService();

  Future<List<PurchaseItemSummary>> getPurchaseItemsSummary() async {
    final response =
        await Supabase.instance.client.rpc('get_purchase_items_summary');

    return response
        .map<PurchaseItemSummary>(
          (item) => PurchaseItemSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
