import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Sube una foto de trabajo al bucket publico `work-photos`
/// (sub-bloque 2 de "Resenas y fotos de trabajo", D-058/D-059). Requiere
/// sesion de `tenant_owner`/`admin`/`stylist` con acceso a la sede: la
/// politica `work_photos_insert_staff` sobre `storage.objects` la valida
/// en el servidor contra `tenant_memberships`/`branch_memberships`, igual
/// criterio que `beautyos_resolve_branch_access`.
class WorkPhotosUploadService {
  const WorkPhotosUploadService();

  static const _uuid = Uuid();

  Future<XFile?> pickImage() {
    return ImagePicker().pickImage(source: ImageSource.gallery);
  }

  Future<String> uploadWorkPhoto({
    required String branchId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final path = '$branchId/${_uuid.v4()}.$extension';

    await Supabase.instance.client.storage
        .from('work-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );

    return Supabase.instance.client.storage
        .from('work-photos')
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
