import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'storage_cleanup.dart';

/// Sube la portada del negocio al bucket publico `tenant-covers` (punto 6
/// del benchmarking). Mismo patron que `TenantLogoUploadService`: la portada
/// es del tenant completo, ruta `{tenant_id}/archivo.ext`. La politica
/// `tenant_covers_insert_owner` sobre `storage.objects` exige que quien sube
/// sea `tenant_owner` de ese tenant exacto.
class TenantCoverUploadService {
  const TenantCoverUploadService();

  static const _uuid = Uuid();

  Future<XFile?> pickImage() {
    return ImagePicker().pickImage(source: ImageSource.gallery);
  }

  Future<String> uploadTenantCoverPhoto({
    required String tenantId,
    required XFile image,
    String? previousUrl,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final path = '$tenantId/${_uuid.v4()}.$extension';

    await Supabase.instance.client.storage
        .from('tenant-covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );

    // El archivo anterior se borra DESPUES de que el nuevo esta arriba
    // (H-09). Al reves, un fallo al subir dejaria al negocio sin imagen
    // ninguna.
    await const StorageCleanup().borrarPorUrlPublica(
      bucket: 'tenant-covers',
      urlPublica: previousUrl,
    );

    return Supabase.instance.client.storage
        .from('tenant-covers')
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
