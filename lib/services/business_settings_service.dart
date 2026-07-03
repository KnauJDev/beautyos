import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_settings.dart';

class BusinessSettingsService {
  const BusinessSettingsService();

  Future<BusinessSettings> getBusinessSettings() async {
    final response = await Supabase.instance.client
        .rpc('get_business_settings')
        .single();

    return BusinessSettings.fromMap(
      Map<String, dynamic>.from(response),
    );
  }
}
