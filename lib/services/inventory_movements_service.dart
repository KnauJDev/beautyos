import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_movement_summary.dart';

class InventoryMovementsService {
  const InventoryMovementsService();

  Future<List<InventoryMovementSummary>> getInventoryMovementsSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_inventory_movements_summary');

    return response
        .map<InventoryMovementSummary>(
          (item) => InventoryMovementSummary.fromMap(item),
        )
        .toList();
  }
}
