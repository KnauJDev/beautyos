import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/publication_studio_data.dart';
import '../models/work_photo_summary.dart';
import 'sesion_supabase.dart';
import 'storage_cleanup.dart';
import 'work_photo_storage.dart';

class WorkPhotosService {
  const WorkPhotosService({required this.branchId});

  final String branchId;

  static const _almacen = WorkPhotoStorage();

  Future<List<WorkPhotoSummary>> getWorkPhotosSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_work_photos_summary_v2',
      params: {'p_branch_id': branchId},
    );

    final fotos = response
        .map<WorkPhotoSummary>(
          (item) =>
              WorkPhotoSummary.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    // Las que aun no se publican no tienen direccion permanente: se les pide
    // una temporal para poder verlas dentro de la app y decidir.
    return _almacen.conDireccionesVisibles(fotos);
  }

  Future<String> createWorkPhoto({
    required String ticketId,
    required String storagePath,
    required String photoType,
    String? caption,
    String? stylistId,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'create_work_photo',
      params: {
        'p_branch_id': branchId,
        'p_ticket_id': ticketId,
        'p_storage_path': storagePath,
        'p_photo_type': photoType,
        'p_caption': caption,
        'p_stylist_id': stylistId,
        // Sin `p_client_consent` desde D-288 (AQ): el permiso lo da ella.
      },
    );

    return response as String;
  }

  Future<void> setCustomerVisibility({
    required String photoId,
    required bool visible,
  }) async {
    await Supabase.instance.client.rpc(
      'set_work_photo_customer_visibility',
      params: {
        'p_branch_id': branchId,
        'p_photo_id': photoId,
        'p_visible': visible,
      },
    );
  }

  /// Borra una foto: **el archivo de verdad**, y la fila queda marcada como
  /// eliminada (H-09).
  ///
  /// **No se puede deshacer.** El respaldo del proyecto guarda la lista de
  /// archivos, no los archivos: una imagen borrada no esta en ningun
  /// respaldo. Quien llame a esto debe haber pedido confirmacion antes.
  ///
  /// **Primero el archivo, despues la base.** Si se hiciera al reves y el
  /// borrado del archivo fallara, la foto figuraria como eliminada mientras
  /// sigue publicada en internet. Asi, un fallo a medias deja como mucho una
  /// fila apuntando a algo que ya no existe -- feo, no grave.
  Future<void> deleteWorkPhoto({
    required String photoId,
    required String bucket,
    required String storagePath,
  }) async {
    await const StorageCleanup().borrarPorRuta(
      bucket: bucket,
      ruta: storagePath,
    );

    await Supabase.instance.client.rpc(
      'delete_work_photo',
      params: {'p_branch_id': branchId, 'p_photo_id': photoId},
    );
  }

  /// Publica o retira una foto del portafolio (H-09).
  ///
  /// **El orden de los dos pasos no es intercambiable.** Mover el archivo y
  /// anotarlo en la base son operaciones distintas y una puede fallar; la
  /// regla es que **cualquier fallo a medias deje la foto oculta, nunca
  /// publicada**:
  ///
  /// - **Publicar:** primero la base, despues mover. Si el movimiento falla,
  ///   la foto no aparece en el portafolio. Molesto, no grave.
  /// - **Retirar:** primero mover, despues la base. Si la base falla, el
  ///   archivo ya salio de internet.
  ///
  /// Al reves, un fallo dejaria el archivo publico con la base diciendo que
  /// no lo esta. Eso si seria una fuga, y en fotos de clientas reales no es
  /// un detalle tecnico.
  ///
  /// **Quién mueve el archivo (D-285, hallazgo BX):** la Edge Function
  /// `move-work-photo`, no la app. Mover exige un permiso de Storage que nadie
  /// tiene, y por eso desde el 09-ago ninguna foto llegó nunca al almacén
  /// público. El orden de arriba no cambia.
  Future<void> setPortfolioApproval({
    required String photoId,
    required bool approved,
    required String storagePath,
  }) async {
    if (approved) {
      await Supabase.instance.client.rpc(
        'set_work_photo_portfolio_approval',
        params: {
          'p_branch_id': branchId,
          'p_photo_id': photoId,
          'p_approved': true,
          'p_public_url': _almacen.urlPublica(storagePath),
        },
      );

      try {
        await _moverEnServidor(photoId, 'publico');
      } catch (_) {
        // D-284 (hallazgo BW): si el archivo no se pudo mover, la base NO
        // puede quedarse diciendo "publicada" -- así nació el cuadro roto
        // del portafolio el 27-sep. Se deshace la anotación y se avisa del
        // fallo original. El archivo no se movió: sigue privado, que es lo
        // que la base vuelve a decir.
        await Supabase.instance.client.rpc(
          'set_work_photo_portfolio_approval',
          params: {
            'p_branch_id': branchId,
            'p_photo_id': photoId,
            'p_approved': false,
            'p_public_url': null,
          },
        );
        rethrow;
      }
      return;
    }

    await _moverEnServidor(photoId, 'privado');

    await Supabase.instance.client.rpc(
      'set_work_photo_portfolio_approval',
      params: {
        'p_branch_id': branchId,
        'p_photo_id': photoId,
        'p_approved': false,
        'p_public_url': null,
      },
    );
  }

  /// Mueve el archivo de la foto al almacén `publico` o `privado` por la Edge
  /// Function `move-work-photo` (D-285). Ella pregunta a la base, con la
  /// sesión de quien llama, si puede; a público solo si ya está aprobada y
  /// con consentimiento.
  Future<void> _moverEnServidor(String photoId, String destino) async {
    await Supabase.instance.client.functions.invoke(
      'move-work-photo',
      headers: await cabecerasParaEdgeFunction(),
      body: {'branchId': branchId, 'photoId': photoId, 'destino': destino},
    );
  }

  /// Datos para el Estudio de publicación (paso 6.2, D-169). El servidor
  /// rechaza una foto que no esté aprobada para portafolio o sin
  /// consentimiento de la clienta -- mismo candado que D-167.
  Future<PublicationStudioData> getPublicationStudioData(String photoId) async {
    final response = await Supabase.instance.client
        .rpc(
          'get_publication_studio_data',
          params: {'p_branch_id': branchId, 'p_photo_id': photoId},
        )
        .single();

    return PublicationStudioData.fromMap(Map<String, dynamic>.from(response));
  }
}
