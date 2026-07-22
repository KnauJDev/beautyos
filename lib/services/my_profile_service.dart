import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_profile.dart';

class MyProfileService {
  const MyProfileService();

  Future<MyProfile?> getMyProfile() async {
    // get_my_profile() es "returns table" (un conjunto), no un escalar.
    // .maybeSingle() le pide a PostgREST coaccionar el arreglo a un solo
    // objeto y, con 0 filas (usuario recien registrado, todavia sin
    // tenant), eso produce un error HTTP 406 en vez de un cuerpo vacio. Se
    // evita ese error tratando la respuesta como lista desde el principio.
    final response = await Supabase.instance.client.rpc('get_my_profile');
    final rows = response as List;

    if (rows.isEmpty) {
      return null;
    }

    return MyProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }
}
