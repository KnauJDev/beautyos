import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work_photo_summary.dart';

class WorkPhotosService {
  const WorkPhotosService();

  Future<List<WorkPhotoSummary>> getWorkPhotosSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_work_photos_summary',
    );

    return response
        .map<WorkPhotoSummary>(
          (item) => WorkPhotoSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
