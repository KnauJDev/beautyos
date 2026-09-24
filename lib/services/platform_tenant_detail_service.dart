import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_tenant_detail.dart';
import 'work_photo_storage.dart';

class PlatformTenantDetailService {
  const PlatformTenantDetailService();

  final _storage = const WorkPhotoStorage();

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

  /// D-076 (restaurado el 24-sep, hallazgo BC, D-274): el acceso de soporte
  /// vuelve a alcanzar también las fotos que el negocio aún no ha aprobado.
  /// La RPC ahora trae `storage_bucket`/`storage_path` de cada una, y aquí se
  /// piden sus direcciones temporales con el mismo helper que ya usa el
  /// propio negocio (`WorkPhotoStorage.firmar`): la política del almacén
  /// privado le da permiso a quien tiene rol de plataforma, igual que a
  /// quien pertenece al negocio.
  Future<List<PlatformWorkPhotoSummary>> getWorkPhotos(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_work_photos',
      params: {'p_tenant_id': tenantId},
    );
    final fotos = (response as List)
        .map(
          (row) => PlatformWorkPhotoSummary.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();

    final rutasPendientes = fotos
        .where((f) => f.displayUrl == null && f.storagePath != null)
        .map((f) => f.storagePath!)
        .toList();
    if (rutasPendientes.isEmpty) {
      return fotos;
    }

    final firmadas = await _storage.firmar(rutasPendientes);
    return fotos
        .map(
          (f) => f.displayUrl == null && f.storagePath != null
              ? f.conDisplayUrl(firmadas[f.storagePath])
              : f,
        )
        .toList();
  }
}
