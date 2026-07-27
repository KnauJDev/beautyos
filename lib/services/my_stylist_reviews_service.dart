import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_stylist_review.dart';

class MyStylistReviewsService {
  const MyStylistReviewsService({required this.branchId});

  final String branchId;

  Future<List<MyStylistReview>> getMyReviews() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_stylist_reviews',
      params: {'p_branch_id': branchId},
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) =>
              MyStylistReview.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }
}
