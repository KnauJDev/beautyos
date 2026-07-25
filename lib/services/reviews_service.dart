import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_summary.dart';

class ReviewsService {
  const ReviewsService({required this.branchId});

  final String branchId;

  Future<List<ReviewSummary>> getReviewsSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_reviews_summary_v2',
      params: {'p_branch_id': branchId},
    );

    return response
        .map<ReviewSummary>(
          (item) =>
              ReviewSummary.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> moderateReview({
    required String reviewId,
    required bool approve,
  }) async {
    await Supabase.instance.client.rpc(
      'moderate_review',
      params: {
        'p_branch_id': branchId,
        'p_review_id': reviewId,
        'p_approve': approve,
      },
    );
  }

  Future<void> setReviewVisibility({
    required String reviewId,
    required bool visible,
  }) async {
    await Supabase.instance.client.rpc(
      'set_review_visibility',
      params: {
        'p_branch_id': branchId,
        'p_review_id': reviewId,
        'p_visible': visible,
      },
    );
  }
}
