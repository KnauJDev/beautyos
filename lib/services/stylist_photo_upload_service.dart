import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'image_compression.dart';
import 'storage_cleanup.dart';

/// Sube la foto de un profesional al bucket publico `stylist-photos` (punto
/// 6 del benchmarking). Ruta `{tenant_id}/{stylist_id}/archivo.ext`. La
/// politica `stylist_photos_insert_owner_admin` sobre `storage.objects`
/// exige que quien sube sea `tenant_owner` o `admin` de ese tenant exacto,
/// y que el estilista pertenezca a el.
class StylistPhotoUploadService {
  const StylistPhotoUploadService();

  static const _uuid = Uuid();

  /// Comprime antes de subir (TL-20, D-199): ver `image_compression.dart`.
  Future<XFile?> pickImage() {
    return elegirImagenComprimida();
  }

  Future<String> uploadStylistPhoto({
    required String tenantId,
    required String stylistId,
    required XFile image,
    String? previousUrl,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final path = '$tenantId/$stylistId/${_uuid.v4()}.$extension';

    await Supabase.instance.client.storage
        .from('stylist-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );

    // El archivo anterior se borra DESPUES de que el nuevo esta arriba
    // (H-09). Al reves, un fallo al subir dejaria al negocio sin imagen
    // ninguna.
    await const StorageCleanup().borrarPorUrlPublica(
      bucket: 'stylist-photos',
      urlPublica: previousUrl,
    );

    return Supabase.instance.client.storage
        .from('stylist-photos')
        .getPublicUrl(path);
  }

  String _extensionFor(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
