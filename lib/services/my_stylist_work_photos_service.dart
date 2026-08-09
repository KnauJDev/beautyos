import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_stylist_work_photo.dart';
import 'work_photo_storage.dart';

class MyStylistWorkPhotosService {
  const MyStylistWorkPhotosService({required this.branchId});

  final String branchId;

  Future<List<MyStylistWorkPhoto>> getMyStylistWorkPhotos() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_stylist_work_photos_v2',
      params: {'p_branch_id': branchId},
    );

    final rows = response as List<dynamic>;

    final fotos = rows
        .map(
          (row) =>
              MyStylistWorkPhoto.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();

    // Las fotos que aun no se publican no tienen direccion permanente: se les
    // pide una temporal para que el estilista pueda ver su propio trabajo
    // mientras espera la aprobacion (H-09).
    const almacen = WorkPhotoStorage();

    final pendientes = fotos
        .where((f) => f.displayUrl == null && f.storagePath != null)
        .map((f) => f.storagePath!)
        .toList();

    if (pendientes.isEmpty) {
      return fotos;
    }

    final firmadas = await almacen.firmar(pendientes);

    return fotos
        .map(
          (foto) => foto.displayUrl != null || foto.storagePath == null
              ? foto
              : foto.conDisplayUrl(firmadas[foto.storagePath!]),
        )
        .toList();
  }
}
