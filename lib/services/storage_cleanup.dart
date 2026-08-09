import 'package:supabase_flutter/supabase_flutter.dart';

/// Borra archivos de los almacenes (H-09).
///
/// **Por que existe.** Hasta el 09-ago los cuatro almacenes tenian **solo
/// politica de insercion**: no habia forma de borrar nada desde la
/// aplicacion. Cada vez que alguien reemplazaba un logo, una portada o la
/// foto de un profesional, el archivo anterior quedaba guardado para siempre,
/// ocupando espacio sin techo y sin que nadie pudiera limpiarlo.
///
/// **Lo que se borra aqui es irrecuperable.** El respaldo del proyecto
/// (`scripts/respaldo_supabase.ps1`) guarda la **lista** de archivos, no los
/// archivos: una imagen borrada no esta en ningun respaldo. Quien llame a
/// esto para algo que decide una persona debe pedir confirmacion antes.
class StorageCleanup {
  const StorageCleanup();

  SupabaseClient get _cliente => Supabase.instance.client;

  /// Borra el archivo al que apunta una direccion publica.
  ///
  /// Se usa al **reemplazar** logo, portada o foto del profesional, y ahi no
  /// se pregunta nada: la persona acaba de sustituir la imagen, la anterior
  /// ya no la quiere.
  ///
  /// **Es de mejor esfuerzo a proposito.** Si el borrado del archivo viejo
  /// falla, no se deshace la subida del nuevo ni se le muestra un error a
  /// quien acaba de cambiar su logo: lo que pidio -- tener el logo nuevo --
  /// ya ocurrio. Lo unico que queda es un archivo de mas, que era justo la
  /// situacion normal antes de este cambio.
  Future<void> borrarPorUrlPublica({
    required String bucket,
    required String? urlPublica,
  }) async {
    final ruta = rutaDesdeUrlPublica(bucket: bucket, urlPublica: urlPublica);

    if (ruta == null) {
      return;
    }

    try {
      await _cliente.storage.from(bucket).remove([ruta]);
    } catch (_) {
      // Silencio deliberado: ver el comentario de arriba.
    }
  }

  /// Borra un archivo por su ruta. Aqui **si** se propaga el fallo: lo usa el
  /// borrado que pide una persona expresamente, y decirle "listo" cuando el
  /// archivo sigue publicado seria mentirle.
  Future<void> borrarPorRuta({
    required String bucket,
    required String ruta,
  }) async {
    await _cliente.storage.from(bucket).remove([ruta]);
  }

  /// Saca la ruta interna de una direccion publica de Supabase, que siempre
  /// tiene la forma `.../object/public/<bucket>/<ruta>`.
  ///
  /// Devuelve nulo si la direccion no corresponde a ese almacen, para no
  /// borrar por error algo que no era.
  String? rutaDesdeUrlPublica({
    required String bucket,
    required String? urlPublica,
  }) {
    if (urlPublica == null || urlPublica.isEmpty) {
      return null;
    }

    final marca = '/object/public/$bucket/';
    final corte = urlPublica.indexOf(marca);

    if (corte == -1) {
      return null;
    }

    final ruta = urlPublica.substring(corte + marca.length);

    // Se limpia lo que Supabase pueda anadir al final de la direccion.
    final sinConsulta = ruta.split('?').first;

    return sinConsulta.isEmpty ? null : sinConsulta;
  }
}
