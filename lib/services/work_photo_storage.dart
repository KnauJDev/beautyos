import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work_photo_summary.dart';

/// Los dos almacenes de fotos de trabajo y el movimiento entre ellos (H-09).
///
/// **Por que hay dos.** Hasta el 09-ago toda foto se subia a un almacen
/// publico y quedaba alcanzable desde ese instante, con los interruptores de
/// aprobacion todavia apagados: una foto de una clienta que nadie habia
/// revisado ya era publica, y ocultarla en la app no la quitaba de internet.
/// Ahora una foto **nace privada** y **aprobarla es lo que la publica**.
///
/// **Por que la publicada usa direccion permanente y no una que caduque.** El
/// portafolio existe para que alguien que no conoce el negocio vea el trabajo
/// y se decida, y mas adelante esa misma foto sale publicada con la resena en
/// redes sociales (tarea 4.3). Una red social necesita una direccion que no
/// caduque para ir a buscar la imagen. Las direcciones temporales quedan solo
/// para ver dentro de la app una foto que aun no se publica -- eso es para
/// una persona, no para el mundo.
class WorkPhotoStorage {
  const WorkPhotoStorage();

  static const bucketPublico = 'work-photos';
  static const bucketPrivado = 'work-photos-private';

  /// Cuanto vale una direccion temporal. Una hora alcanza de sobra para
  /// revisar y aprobar, y si la pestana queda abierta mas tiempo basta con
  /// actualizar la lista.
  static const _segundosFirma = 3600;

  SupabaseClient get _cliente => Supabase.instance.client;

  /// La direccion permanente que tendria este archivo una vez publicado.
  /// Es una concatenacion, no una llamada al servidor.
  String urlPublica(String storagePath) {
    return _cliente.storage.from(bucketPublico).getPublicUrl(storagePath);
  }

  /// Direcciones temporales para las fotos que aun no se publican.
  ///
  /// Se piden todas de una sola vez en lugar de una por foto: una galeria con
  /// treinta pendientes serian treinta viajes al servidor.
  ///
  /// Devuelve un mapa de ruta a direccion. Las que falten simplemente no
  /// estaran: la pantalla lo dice con palabras en vez de pintar un cuadro
  /// roto.
  Future<Map<String, String>> firmar(List<String> rutas) async {
    if (rutas.isEmpty) {
      return const {};
    }

    try {
      final respuesta = await _cliente.storage
          .from(bucketPrivado)
          .createSignedUrlsResult(rutas, _segundosFirma);

      // Se usa la variante que informa ruta por ruta: si una foto concreta no
      // se puede firmar -- por ejemplo porque el archivo se perdio -- las
      // demas se siguen viendo, en vez de caerse la galeria entera.
      return {
        for (final firma in respuesta)
          if (firma is SignedUrlSuccess) firma.path: firma.signedUrl,
      };
    } catch (_) {
      // Si las firmas fallan, las fotos publicadas se siguen viendo y las
      // pendientes avisan de que no se pueden mostrar. Se prefiere una
      // galeria a medias antes que una pantalla de error: no poder ver una
      // miniatura no es motivo para bloquear el modulo entero.
      return const {};
    }
  }

  /// Rellena `displayUrl` de las fotos que todavia no estan publicadas.
  Future<List<WorkPhotoSummary>> conDireccionesVisibles(
    List<WorkPhotoSummary> fotos,
  ) async {
    final pendientes = fotos
        .where((f) => f.displayUrl == null && f.storagePath != null)
        .map((f) => f.storagePath!)
        .toList();

    if (pendientes.isEmpty) {
      return fotos;
    }

    final firmadas = await firmar(pendientes);

    return fotos
        .map(
          (foto) => foto.displayUrl != null || foto.storagePath == null
              ? foto
              : foto.conDisplayUrl(firmadas[foto.storagePath!]),
        )
        .toList();
  }

  /// Mueve el archivo al almacen publico y devuelve su direccion permanente.
  Future<String> publicar(String storagePath) async {
    await _cliente.storage.from(bucketPrivado).move(
          storagePath,
          storagePath,
          destinationBucket: bucketPublico,
        );

    return urlPublica(storagePath);
  }

  /// Devuelve el archivo al almacen privado: deja de ser alcanzable.
  Future<void> despublicar(String storagePath) async {
    await _cliente.storage.from(bucketPublico).move(
          storagePath,
          storagePath,
          destinationBucket: bucketPrivado,
        );
  }
}
