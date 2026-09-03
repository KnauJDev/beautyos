import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'image_compression.dart';
import 'storage_cleanup.dart';

/// Sube la portada de un artículo de blog al bucket público `blog-covers`
/// (paso 6.6, D-171). Mismo patrón que `TenantCoverUploadService`: ruta
/// `{tenant_id}/archivo.ext`, autorizada por `tenant_owner`/`admin` de ese
/// tenant exacto.
class BlogCoverUploadService {
  const BlogCoverUploadService();

  static const _uuid = Uuid();

  /// Comprime antes de subir (TL-20, D-199): ver `image_compression.dart`.
  Future<XFile?> pickImage() {
    return elegirImagenComprimida();
  }

  Future<String> uploadCoverPhoto({
    required String tenantId,
    required XFile image,
    String? previousUrl,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final path = '$tenantId/${_uuid.v4()}.$extension';

    await Supabase.instance.client.storage
        .from('blog-covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );

    // La portada anterior se borra DESPUES de que la nueva ya esta arriba
    // (H-09) -- si el borrado del archivo viejo falla, el artículo se queda
    // con la portada nueva de todas formas.
    await const StorageCleanup().borrarPorUrlPublica(
      bucket: 'blog-covers',
      urlPublica: previousUrl,
    );

    return Supabase.instance.client.storage
        .from('blog-covers')
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
