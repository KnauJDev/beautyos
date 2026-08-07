import 'dart:convert';

import 'package:http/http.dart' as http;

/// Version con la que se compilo esta copia de la aplicacion.
///
/// El archivo `build-info.json` lo escribe Cloudflare al compilar, con el
/// identificador del commit. En desarrollo no existe, y eso no es un error:
/// simplemente no hay nada contra que comparar.
class AppVersion {
  const AppVersion({required this.commit, required this.builtAt});

  final String commit;
  final String? builtAt;

  /// Los 7 primeros caracteres, que es como se nombra un commit en Git y lo
  /// que se le muestra al propietario en Configuracion.
  String get shortCommit =>
      commit.length > 7 ? commit.substring(0, 7) : commit;

  bool get isDevelopment => commit == 'local' || commit.isEmpty;

  static AppVersion? fromJson(Map<String, dynamic> map) {
    final commit = map['commit']?.toString().trim();
    if (commit == null || commit.isEmpty) return null;
    return AppVersion(commit: commit, builtAt: map['builtAt']?.toString());
  }
}

/// Averigua que version esta publicada en el servidor.
///
/// Existe porque los archivos de Flutter Web no llevan huella en el nombre
/// (D-096): una pestana abierta durante dias sigue ejecutando el codigo del
/// primer dia sin manera de enterarse. Esto le da esa manera.
class AppVersionService {
  const AppVersionService();

  static const _rutaLocal = 'build-info.json';

  /// Lee la version publicada ahora mismo.
  ///
  /// Siempre con un parametro distinto en la direccion para saltarse cualquier
  /// cache intermedia: preguntar por la version y que te respondan la version
  /// vieja no tendria ningun sentido.
  ///
  /// Devuelve `null` ante cualquier problema -- sin conexion, servidor caido,
  /// archivo ausente en desarrollo. Comprobar si hay actualizaciones es una
  /// comodidad, nunca un motivo para estorbarle el trabajo a nadie.
  Future<AppVersion?> fetchPublishedVersion() async {
    try {
      final url = Uri.base.resolve(
        '$_rutaLocal?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http
          .get(url, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      return AppVersion.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
