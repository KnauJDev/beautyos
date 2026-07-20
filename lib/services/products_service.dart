import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_summary.dart';

class ProductsService {
  const ProductsService({required this.branchId});

  final String? branchId;

  Future<List<ProductSummary>> getProductsSummary() async {
    final response = await Supabase.instance.client.rpc(
      branchId == null ? 'get_products_summary' : 'get_products_summary_v2',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return response
        .map<ProductSummary>((item) => ProductSummary.fromMap(item))
        .toList();
  }
}
