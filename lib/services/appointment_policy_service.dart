import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_policy.dart';

class AppointmentPolicyService {
  const AppointmentPolicyService({required this.branchId});

  final String branchId;

  Future<AppointmentPolicy> getAppointmentPolicy() async {
    final response = await Supabase.instance.client
        .rpc('get_appointment_policy_v2', params: {'p_branch_id': branchId})
        .single();

    return AppointmentPolicy.fromMap(Map<String, dynamic>.from(response));
  }
}
