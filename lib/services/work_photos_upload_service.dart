import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'work_photo_storage.dart';

/// Sube una foto de trabajo al almacen **privado** `work-photos-private`
/// (sub-bloque 2 de "Resenas y fotos de trabajo", D-058/D-059).
///
/// **Cambio del 09-ago (H-09):** antes subia al almacen publico, asi que la
/// foto quedaba alcanzable desde internet en el mismo instante en que se
/// subia, antes de que nadie la revisara. Ahora nace privada y solo se
/// publica al aprobarla -- ver `WorkPhotoStorage`.
///
/// Requiere sesion de `tenant_owner`/`admin`/`stylist` con acceso a la sede:
/// la politica `work_photos_private_insert_staff` sobre `storage.objects` la
/// valida en el servidor contra `tenant_memberships`/`branch_memberships`,
/// igual criterio que `beautyos_resolve_branch_access`.
class WorkPhotosUploadService {
  const WorkPhotosUploadService();

  static const _uuid = Uuid();

  Future<XFile?> pickImage() {
    return ImagePicker().pickImage(source: ImageSource.gallery);
  }

  /// Devuelve la **ruta** del archivo, no una direccion.
  ///
  /// Antes devolvia la direccion publica completa y el servidor la guardaba
  /// tal cual; o sea, el cliente escribia lo que la base creia. Ahora viaja
  /// solo la ruta y `create_work_photo` comprueba que este dentro de la
  /// carpeta de esa sede.
  Future<String> uploadWorkPhoto({
    required String branchId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final path = '$branchId/${_uuid.v4()}.$extension';

    await Supabase.instance.client.storage
        .from(WorkPhotoStorage.bucketPrivado)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(extension)),
        );

    return path;
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
