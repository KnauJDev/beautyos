import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_policy.dart';
import 'monitoreo_service.dart';

class AppointmentPolicyService {
  const AppointmentPolicyService({required this.branchId});

  final String branchId;

  Future<AppointmentPolicy> getAppointmentPolicy() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client
            .rpc('get_appointment_policy_v2', params: {'p_branch_id': branchId})
            .single();

        return AppointmentPolicy.fromMap(Map<String, dynamic>.from(response));
      },
      motivo: 'Fallo al consultar get_appointment_policy_v2()',
    );
  }

  Future<void> updateAppointmentPolicy({
    required bool requiresDeposit,
    required num depositPercentage,
    required int cancellationHours,
    required int rescheduleHours,
    required bool manualConfirmationRequired,
    required bool customerRescheduleAllowed,
  }) async {
    await Supabase.instance.client.rpc(
      'update_appointment_policy',
      params: {
        'p_branch_id': branchId,
        'p_requires_deposit': requiresDeposit,
        'p_deposit_percentage': depositPercentage,
        'p_cancellation_hours': cancellationHours,
        'p_reschedule_hours': rescheduleHours,
        'p_manual_confirmation_required': manualConfirmationRequired,
        'p_customer_reschedule_allowed': customerRescheduleAllowed,
      },
    );
  }
}
