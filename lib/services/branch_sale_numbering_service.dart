import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sale_numbering.dart';

class BranchSaleNumberingService {
  final String branchId;

  const BranchSaleNumberingService({required this.branchId});

  /// Obtiene la configuración de numeración de ventas y DIAN para la sede
  Future<BranchSaleNumbering> getBranchSaleNumbering() async {
    final response = await Supabase.instance.client.rpc(
      'get_branch_sale_numbering',
      params: {'p_branch_id': branchId},
    );

    if (response is List && response.isNotEmpty) {
      return BranchSaleNumbering.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    } else if (response is Map) {
      return BranchSaleNumbering.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    throw StateError('No se encontró configuración de numeración para la sede.');
  }

  /// Guarda o actualiza la configuración de numeración y Resolución DIAN
  Future<void> updateBranchSaleNumbering({
    required String prefix,
    required int nextNumber,
    required int padding,
    String? resolutionNumber,
    DateTime? resolutionDate,
    int? rangeFrom,
    int? rangeTo,
    DateTime? validUntil,
  }) async {
    await Supabase.instance.client.rpc(
      'set_branch_sale_numbering',
      params: {
        'p_branch_id': branchId,
        'p_prefix': prefix.trim(),
        'p_next_number': nextNumber,
        'p_padding': padding,
        'p_resolution_number': resolutionNumber != null && resolutionNumber.trim().isNotEmpty
            ? resolutionNumber.trim()
            : null,
        'p_resolution_date': resolutionDate?.toIso8601String().split('T').first,
        'p_range_from': rangeFrom,
        'p_range_to': rangeTo,
        'p_valid_until': validUntil?.toIso8601String().split('T').first,
      },
    );
  }
}
