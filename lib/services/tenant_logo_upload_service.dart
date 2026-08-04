import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Sube el logo del negocio al bucket publico `tenant-logos` (punto 4.4 de
/// la ruta general, marca blanca). A diferencia de `WorkPhotosUploadService`
/// (por sede), el logo es del tenant completo: la ruta es
/// `{tenant_id}/archivo.ext`. La politica `tenant_logos_insert_owner` sobre
/// `storage.objects` exige que quien sube sea `tenant_owner` de ese tenant
/// exacto.
class TenantLogoUploadService {
  const TenantLogoUploadService();

  static const _uuid = Uuid();

  Future<XFile?> pickImage() {
    return ImagePicker().pickImage(source: ImageSource.gallery);
  }

  Future<String> uploadTenantLogo({
    required String tenantId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final path = '$tenantId/${_uuid.v4()}.$extension';

    await Supabase.instance.client.storage
        .from('tenant-logos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );

    return Supabase.instance.client.storage
        .from('tenant-logos')
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
