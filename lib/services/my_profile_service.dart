import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_profile.dart';

class MyProfileService {
  const MyProfileService();

  Future<MyProfile?> getMyProfile() async {
    final response = await Supabase.instance.client
        .rpc('get_my_profile')
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return MyProfile.fromMap(Map<String, dynamic>.from(response));
  }
}
