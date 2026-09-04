import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/beauty_service.dart';
import '../models/service_management_item.dart';
import 'monitoreo_service.dart';

class ServicesService {
  const ServicesService();

  Future<List<BeautyService>> getActiveVisibleServices() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client
            .from('services')
            .select('id, name, category, duration_minutes, price')
            .eq('active', true)
            .eq('visible_to_customer', true)
            .order('name');

        return response
            .map<BeautyService>((item) => BeautyService.fromMap(item))
            .toList();
      },
      motivo: 'Fallo al consultar services activos',
    );
  }

  Future<List<ServiceManagementItem>> getServicesForManagement(
    String branchId,
  ) async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client.rpc(
          'get_services_for_management',
          params: {'p_branch_id': branchId},
        );

        return (response as List)
            .map(
              (item) => ServiceManagementItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      },
      motivo: 'Fallo al consultar get_services_for_management()',
    );
  }

  Future<void> createService({
    required String branchId,
    required String name,
    required String category,
    required int durationMinutes,
    required num price,
    bool visibleToCustomer = true,
  }) async {
    await Supabase.instance.client.rpc(
      'create_service',
      params: {
        'p_branch_id': branchId,
        'p_name': name,
        'p_category': category,
        'p_duration_minutes': durationMinutes,
        'p_price': price,
        'p_visible_to_customer': visibleToCustomer,
      },
    );
  }

  Future<void> updateService({
    required String branchId,
    required String serviceId,
    required String name,
    required String category,
    required int durationMinutes,
    required num price,
    bool visibleToCustomer = true,
  }) async {
    await Supabase.instance.client.rpc(
      'update_service',
      params: {
        'p_branch_id': branchId,
        'p_service_id': serviceId,
        'p_name': name,
        'p_category': category,
        'p_duration_minutes': durationMinutes,
        'p_price': price,
        'p_visible_to_customer': visibleToCustomer,
      },
    );
  }

  Future<void> setServiceActive({
    required String branchId,
    required String serviceId,
    required bool active,
  }) async {
    await Supabase.instance.client.rpc(
      'set_service_active',
      params: {
        'p_branch_id': branchId,
        'p_service_id': serviceId,
        'p_active': active,
      },
    );
  }
}
