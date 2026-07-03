import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_policy.dart';

class AppointmentPolicyService {
  const AppointmentPolicyService();

  Future<AppointmentPolicy> getAppointmentPolicy() async {
    final response = await Supabase.instance.client
        .rpc('get_appointment_policy')
        .single();

    return AppointmentPolicy.fromMap(
      Map<String, dynamic>.from(response),
    );
  }
}
