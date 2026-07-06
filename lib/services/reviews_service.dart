import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_summary.dart';

class ReviewsService {
  const ReviewsService();

  Future<List<ReviewSummary>> getReviewsSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_reviews_summary',
    );

    return response
        .map<ReviewSummary>(
          (item) => ReviewSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
