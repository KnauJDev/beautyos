import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sales_report_summary.dart';

class SalesReportService {
  const SalesReportService({required this.branchId});

  final String? branchId;

  Future<List<SalesReportSummary>> getSalesReportSummary() async {
    final response = await Supabase.instance.client.rpc(
      branchId == null
          ? 'get_sales_report_summary'
          : 'get_sales_report_summary_v2',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return response
        .map<SalesReportSummary>(
          (item) => SalesReportSummary.fromMap(item),
        )
        .toList();
  }
}
