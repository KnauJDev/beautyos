import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_management_item.dart';
import 'monitoreo_service.dart';

class ProductsService {
  const ProductsService({required this.branchId});

  final String branchId;

  Future<List<ProductManagementItem>> getProductsForManagement() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client.rpc(
          'get_products_for_management',
          params: {'p_branch_id': branchId},
        );

        return (response as List)
            .map(
              (item) => ProductManagementItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      },
      motivo: 'Fallo al consultar get_products_for_management()',
    );
  }

  Future<void> createProduct({
    required String name,
    required String category,
    String? brand,
    required String productType,
    required String unit,
    String? sku,
    required num minimumStock,
    required num purchasePrice,
    required num salePrice,
    bool visibleForSale = false,
  }) async {
    await Supabase.instance.client.rpc(
      'create_product',
      params: {
        'p_branch_id': branchId,
        'p_name': name,
        'p_category': category,
        'p_product_type': productType,
        'p_unit': unit,
        'p_sku': sku,
        'p_minimum_stock': minimumStock,
        'p_purchase_price': purchasePrice,
        'p_sale_price': salePrice,
        'p_visible_for_sale': visibleForSale,
        'p_brand': brand,
      },
    );
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String category,
    String? brand,
    required String productType,
    required String unit,
    String? sku,
    required num minimumStock,
    required num purchasePrice,
    required num salePrice,
    bool visibleForSale = false,
  }) async {
    await Supabase.instance.client.rpc(
      'update_product',
      params: {
        'p_branch_id': branchId,
        'p_product_id': productId,
        'p_name': name,
        'p_category': category,
        'p_product_type': productType,
        'p_unit': unit,
        'p_sku': sku,
        'p_minimum_stock': minimumStock,
        'p_purchase_price': purchasePrice,
        'p_sale_price': salePrice,
        'p_visible_for_sale': visibleForSale,
        'p_brand': brand,
      },
    );
  }

  Future<void> setProductActive({
    required String productId,
    required bool active,
  }) async {
    await Supabase.instance.client.rpc(
      'set_product_active',
      params: {
        'p_branch_id': branchId,
        'p_product_id': productId,
        'p_active': active,
      },
    );
  }
}
