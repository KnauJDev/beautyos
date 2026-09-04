import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_management_item.dart';
import 'monitoreo_service.dart';

class ExpensesService {
  const ExpensesService({required this.branchId});

  final String branchId;

  Future<List<ExpenseManagementItem>> getExpensesForManagement() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client.rpc(
          'get_expenses_for_management',
          params: {'p_branch_id': branchId},
        );

        return (response as List)
            .map(
              (item) => ExpenseManagementItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      },
      motivo: 'Fallo al consultar get_expenses_for_management()',
    );
  }

  Future<void> createExpense({
    required String category,
    required String description,
    required num amount,
    required DateTime expenseDate,
    required String paymentMethod,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'create_expense',
      params: {
        'p_branch_id': branchId,
        'p_category': category,
        'p_description': description,
        'p_amount': amount,
        'p_expense_date': _formatDate(expenseDate),
        'p_payment_method': paymentMethod,
        'p_notes': notes,
      },
    );
  }

  Future<void> updateExpense({
    required String expenseId,
    required String category,
    required String description,
    required num amount,
    required DateTime expenseDate,
    required String paymentMethod,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'update_expense',
      params: {
        'p_branch_id': branchId,
        'p_expense_id': expenseId,
        'p_category': category,
        'p_description': description,
        'p_amount': amount,
        'p_expense_date': _formatDate(expenseDate),
        'p_payment_method': paymentMethod,
        'p_notes': notes,
      },
    );
  }

  Future<void> setExpenseActive({
    required String expenseId,
    required bool active,
  }) async {
    await Supabase.instance.client.rpc(
      'set_expense_active',
      params: {
        'p_branch_id': branchId,
        'p_expense_id': expenseId,
        'p_active': active,
      },
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
