import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pending_invitation.dart';
import '../models/team_invitation.dart';

class TeamInvitationsService {
  const TeamInvitationsService();

  Future<void> createInvitation({
    required String branchId,
    required String email,
    required String role,
    String? stylistId,
  }) async {
    await Supabase.instance.client.rpc(
      'create_team_invitation',
      params: {
        'p_branch_id': branchId,
        'p_email': email,
        'p_role': role,
        'p_stylist_id': stylistId,
      },
    );
  }

  Future<List<TeamInvitation>> listInvitations(String branchId) async {
    final response = await Supabase.instance.client.rpc(
      'list_team_invitations',
      params: {'p_branch_id': branchId},
    );

    return (response as List)
        .map(
          (item) =>
              TeamInvitation.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> cancelInvitation(String invitationId) async {
    await Supabase.instance.client.rpc(
      'cancel_team_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }

  Future<PendingInvitation?> getMyPendingInvitation() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_pending_invitation',
    );

    final rows = response as List;
    if (rows.isEmpty) {
      return null;
    }

    return PendingInvitation.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<void> acceptInvitation(String fullName) async {
    await Supabase.instance.client.rpc(
      'accept_team_invitation',
      params: {'p_full_name': fullName},
    );
  }
}
