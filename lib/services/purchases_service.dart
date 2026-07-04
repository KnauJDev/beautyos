import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase_summary.dart';

class PurchasesService {
  const PurchasesService();

  Future<List<PurchaseSummary>> getPurchasesSummary() async {
    final response = await Supabase.instance.client.rpc('get_purchases_summary');

    return response
        .map<PurchaseSummary>(
          (item) => PurchaseSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
