import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_tenant_detail.dart';

class PlatformTenantDetailService {
  const PlatformTenantDetailService();

  Future<List<PlatformClientSummary>> getClients(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_clients',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (row) => PlatformClientSummary.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<PlatformTicketSummary>> getTickets(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_tickets',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (row) => PlatformTicketSummary.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<PlatformBranchFinancialSummary>> getFinancialSummary(
    String tenantId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_financial_summary',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (row) => PlatformBranchFinancialSummary.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<PlatformTeamMember>> getTeam(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_team',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (row) =>
              PlatformTeamMember.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<PlatformReviewSummary>> getReviews(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_reviews',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (row) => PlatformReviewSummary.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<PlatformWorkPhotoSummary>> getWorkPhotos(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_work_photos',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (row) => PlatformWorkPhotoSummary.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
