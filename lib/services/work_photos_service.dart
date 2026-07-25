import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work_photo_summary.dart';

class WorkPhotosService {
  const WorkPhotosService({required this.branchId});

  final String branchId;

  Future<List<WorkPhotoSummary>> getWorkPhotosSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_work_photos_summary_v2',
      params: {'p_branch_id': branchId},
    );

    return response
        .map<WorkPhotoSummary>(
          (item) =>
              WorkPhotoSummary.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<String> createWorkPhoto({
    required String ticketId,
    required String photoUrl,
    required String photoType,
    String? caption,
    String? stylistId,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_work_photo',
      params: {
        'p_branch_id': branchId,
        'p_ticket_id': ticketId,
        'p_photo_url': photoUrl,
        'p_photo_type': photoType,
        'p_caption': caption,
        'p_stylist_id': stylistId,
      },
    );

    return response as String;
  }

  Future<void> setCustomerVisibility({
    required String photoId,
    required bool visible,
  }) async {
    await Supabase.instance.client.rpc(
      'set_work_photo_customer_visibility',
      params: {
        'p_branch_id': branchId,
        'p_photo_id': photoId,
        'p_visible': visible,
      },
    );
  }

  Future<void> setPortfolioApproval({
    required String photoId,
    required bool approved,
  }) async {
    await Supabase.instance.client.rpc(
      'set_work_photo_portfolio_approval',
      params: {
        'p_branch_id': branchId,
        'p_photo_id': photoId,
        'p_approved': approved,
      },
    );
  }
}
