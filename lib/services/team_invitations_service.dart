import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pending_invitation.dart';
import '../models/team_invitation.dart';

class TeamInvitationsService {
  const TeamInvitationsService();

  /// Crea la invitación y trata de enviar el correo automático (D-062).
  /// Devuelve `true` si el correo se envió; `false` si la invitación quedó
  /// creada pero el correo falló (el propietario debe avisar por su cuenta).
  Future<bool> createInvitation({
    required String branchId,
    required String email,
    required String role,
    String? stylistId,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_team_invitation',
      params: {
        'p_branch_id': branchId,
        'p_email': email,
        'p_role': role,
        'p_stylist_id': stylistId,
      },
    );

    final invitationId = (response as Map)['id'] as String;

    try {
      await Supabase.instance.client.functions.invoke(
        'send-invitation-email',
        body: {'invitation_id': invitationId, 'app_url': Uri.base.origin},
      );
      return true;
    } catch (_) {
      return false;
    }
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
