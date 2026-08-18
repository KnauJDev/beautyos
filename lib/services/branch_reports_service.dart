import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_report_v3.dart';

class BranchReportsService {
  const BranchReportsService({required this.branchId});

  final String branchId;

  Future<BranchReportV3> getBranchReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startFormatted = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endFormatted = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final response = await Supabase.instance.client.rpc(
      'get_branch_reports_v3',
      params: {
        'p_branch_id': branchId,
        'p_start_date': startFormatted,
        'p_end_date': endFormatted,
      },
    );

    if (response is List && response.isNotEmpty) {
      return BranchReportV3.fromMap(Map<String, dynamic>.from(response.first as Map));
    }

    if (response is Map) {
      return BranchReportV3.fromMap(Map<String, dynamic>.from(response));
    }

    throw Exception('No se pudieron obtener los datos del reporte para la sede.');
  }
}
