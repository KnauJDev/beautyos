import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_stylist_work_photo.dart';

class MyStylistWorkPhotosService {
  const MyStylistWorkPhotosService();

  Future<List<MyStylistWorkPhoto>> getMyStylistWorkPhotos() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_stylist_work_photos',
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => MyStylistWorkPhoto.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
