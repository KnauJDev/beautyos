import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_summary.dart';

class ProductsService {
  const ProductsService();

  Future<List<ProductSummary>> getProductsSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_products_summary');

    return response
        .map<ProductSummary>((item) => ProductSummary.fromMap(item))
        .toList();
  }
}
