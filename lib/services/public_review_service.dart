import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_review_ticket.dart';

class PublicReviewService {
  const PublicReviewService();

  Future<PublicReviewTicket> getTicketForReview(String ticketId) async {
    final response = await Supabase.instance.client.rpc(
      'public_get_ticket_for_review',
      params: {'p_ticket_id': ticketId},
    );

    final rows = response as List<dynamic>;

    if (rows.isEmpty) {
      throw Exception('Este enlace de reseña no es válido.');
    }

    return PublicReviewTicket.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<String> createReview({
    required String ticketId,
    required int rating,
    String? comment,
    String? stylistId,
    String? serviceId,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'public_create_review',
      params: {
        'p_ticket_id': ticketId,
        'p_rating': rating,
        'p_comment': comment,
        'p_stylist_id': stylistId,
        'p_service_id': serviceId,
      },
    );

    return response as String;
  }
}
