import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_movement_summary.dart';

class InventoryMovementsService {
  const InventoryMovementsService({required this.branchId});

  final String branchId;

  Future<List<InventoryMovementSummary>> getInventoryMovementsSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_inventory_movements_summary_v2',
      params: {'p_branch_id': branchId},
    );

    return response
        .map<InventoryMovementSummary>(
          (item) => InventoryMovementSummary.fromMap(item),
        )
        .toList();
  }

  Future<void> createStockConsumption({
    required String productId,
    required num quantity,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'create_stock_consumption',
      params: {
        'p_branch_id': branchId,
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_notes': notes,
      },
    );
  }
}
