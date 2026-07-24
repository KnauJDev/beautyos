import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase_management_item.dart';

class PurchasesService {
  const PurchasesService({required this.branchId});

  final String branchId;

  Future<List<PurchaseManagementItem>> getPurchasesForManagement() async {
    final response = await Supabase.instance.client.rpc(
      'get_purchases_for_management',
      params: {'p_branch_id': branchId},
    );

    return (response as List)
        .map(
          (item) => PurchaseManagementItem.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> createPurchase({
    required String supplierName,
    required List<Map<String, dynamic>> items,
    required DateTime purchaseDate,
    String? invoiceNumber,
    required String paymentMethod,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'create_purchase',
      params: {
        'p_branch_id': branchId,
        'p_supplier_name': supplierName,
        'p_items': items,
        'p_purchase_date': _formatDate(purchaseDate),
        'p_invoice_number': invoiceNumber,
        'p_payment_method': paymentMethod,
        'p_notes': notes,
      },
    );
  }

  Future<void> updatePurchaseHeader({
    required String purchaseId,
    required String supplierName,
    required DateTime purchaseDate,
    String? invoiceNumber,
    required String paymentMethod,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'update_purchase_header',
      params: {
        'p_branch_id': branchId,
        'p_purchase_id': purchaseId,
        'p_supplier_name': supplierName,
        'p_purchase_date': _formatDate(purchaseDate),
        'p_invoice_number': invoiceNumber,
        'p_payment_method': paymentMethod,
        'p_notes': notes,
      },
    );
  }

  Future<void> voidPurchase({required String purchaseId}) async {
    await Supabase.instance.client.rpc(
      'void_purchase',
      params: {'p_branch_id': branchId, 'p_purchase_id': purchaseId},
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
