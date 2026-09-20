import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_commission_summary_item.dart';

class MyCommissionSummaryService {
  const MyCommissionSummaryService({required this.branchId});

  final String branchId;

  Future<List<MyCommissionSummaryItem>> getMySummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'get_my_commission_summary',
      params: {
        'p_branch_id': branchId,
        'p_start_date': _formatDate(startDate),
        'p_end_date': _formatDate(endDate),
      },
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => MyCommissionSummaryItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  /// Si la comisión del salón la aprobó alguien, o sigue siendo la que vino
  /// de fábrica (hallazgo **AJ**).
  ///
  /// **Nunca lanza, y ante la duda dice que sí.** Mismo criterio que
  /// `OnboardingService.getProgress` y que los candados de plan (D-184): si
  /// no se pudo preguntar, no se acusa al salón de nada. Un aviso falso sobre
  /// el sueldo de alguien hace más daño que su ausencia.
  Future<bool> policyIsConfirmed() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'my_commission_policy_is_confirmed',
      );

      return response is bool ? response : true;
    } catch (_) {
      return true;
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
