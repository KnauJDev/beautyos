import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/services/sesion_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// El token que viaja a una Edge Function tiene que estar vigente (D-207).
///
/// **El fallo que cierra.** Los tokens de Supabase caducan a la hora. Las
/// cuatro Edge Functions que exigen sesión validan el token y responden
/// **401** si venció. El síntoma que reportó el propietario fue el más
/// visible: *"Se requiere una sesión autenticada para generar la sesión de
/// pago"* al darle a renovar la suscripción. **No se podía cobrar.**
///
/// **Qué se prueba aquí y qué no.** `sesionFresca()` llama a Supabase para
/// refrescar, así que no se puede ejercitar en `flutter test` sin sesión real.
/// Lo que **sí** se prueba es la decisión de la que todo cuelga —*¿hay que
/// refrescar?*— con tokens fabricados que llevan la fecha de caducidad que
/// hace falta. Si esa decisión se equivoca, el refresco no ocurre y vuelve el
/// 401.
///
/// **Por qué el archivo no se llama `epayco_checkout_service_test`.** El
/// encargo lo pedía así, pero el arreglo dejó de vivir en ese servicio: es un
/// helper canónico que usan los cuatro sitios que llaman Edge Functions. Un
/// nombre atado a uno de los cuatro haría creer que el problema era de él.
void main() {
  /// Un token con la forma de un JWT y la caducidad que se le pida.
  ///
  /// `Session.expiresAt` sale de decodificar el `exp` del propio token, no de
  /// un campo aparte, así que para probar la caducidad hay que fabricarlo. La
  /// firma no se verifica: `jwt_decode` solo lee el payload.
  String tokenQueVence(Duration desdeAhora) {
    final exp = DateTime.now().add(desdeAhora).millisecondsSinceEpoch ~/ 1000;
    final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp})));
    return 'cabecera.$payload.firma';
  }

  Session sesionCon(String accessToken) => Session(
    accessToken: accessToken,
    tokenType: 'bearer',
    user: User(
      id: '11111111-1111-1111-1111-111111111111',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
    ),
  );

  group('D-207 — Cuándo hay que refrescar el token', () {
    test('sin sesión, hay que refrescar', () {
      expect(
        necesitaRefresco(null),
        isTrue,
        reason:
            'Sin sesión no hay token que mandar. Antes se enviaba la cabecera '
            'vacía y la Edge Function respondía 401 con un mensaje que no le '
            'decía a nadie que tenía que volver a entrar.',
      );
    });

    test('con el token vencido, hay que refrescar', () {
      final vencido = sesionCon(tokenQueVence(const Duration(minutes: -5)));

      expect(
        necesitaRefresco(vencido),
        isTrue,
        reason:
            'Este es el caso que tumbó el cobro: una hora sin tocar la '
            'pestaña, el token caduca, y nadie lo renovaba antes de llamar.',
      );
    });

    test('con el token vigente, no se refresca', () {
      final vigente = sesionCon(tokenQueVence(const Duration(minutes: 30)));

      expect(
        necesitaRefresco(vigente),
        isFalse,
        reason:
            'Refrescar siempre sería una llamada de más en cada pago, cada '
            'invitación y cada alerta de stock.',
      );
    });

    test('un token al que le quedan segundos cuenta como vencido', () {
      // `Session.isExpired` trae 30 segundos de margen a propósito: si no, la
      // llamada podría salir con un token que caduca en vuelo y el 401
      // llegaría igual, pero sería mucho más raro de reproducir.
      final agonizante = sesionCon(tokenQueVence(const Duration(seconds: 10)));

      expect(
        necesitaRefresco(agonizante),
        isTrue,
        reason:
            'El margen de 30 s de Constants.expiryMargin es lo que evita la '
            'carrera entre el envío y la caducidad.',
      );
    });

    test('un token sin fecha legible no se da por vencido', () {
      // Deja escrito un hueco real, no un adorno: `isExpired` devuelve `false`
      // cuando no puede leer la caducidad. Es lo correcto --no se puede
      // afirmar que algo venció si no se sabe cuándo vence-- pero significa
      // que un token con forma rara pasa de largo y lo rechaza el servidor.
      final raro = sesionCon('esto-no-es-un-jwt');

      expect(
        necesitaRefresco(raro),
        isFalse,
        reason:
            'Si esto cambiara a true, cada llamada con un token no-JWT haría '
            'un refresco extra. El comportamiento está documentado en '
            'sesion_supabase.dart; la prueba existe para que el cambio sea '
            'deliberado y no una sorpresa.',
      );
    });
  });

  group('D-207 — La cabecera que se envía', () {
    test('lleva el token en formato Bearer', () {
      final sesion = sesionCon('token-de-prueba');

      expect(cabeceraDeSesion(sesion), {
        'Authorization': 'Bearer token-de-prueba',
      });
    });

    test('se pasa explícita en vez de confiar en la que guarda el SDK', () {
      // El SupabaseClient arma la cabecera con `auth.currentSession?.accessToken`
      // y **la guarda**, actualizándola solo cuando ocurre un refresco. Esa es
      // justo la que puede estar vieja, y por eso las cuatro llamadas mandan
      // la suya. Si esta función dejara de construirla, el `headers:` de esas
      // llamadas se quedaría sin nada que poner.
      final sesion = sesionCon(tokenQueVence(const Duration(minutes: 30)));
      final cabecera = cabeceraDeSesion(sesion);

      expect(cabecera.keys, ['Authorization']);
      expect(cabecera['Authorization'], startsWith('Bearer '));
    });
  });

  group('D-207 — Ninguna Edge Function con sesión se llama sin token fresco', () {
    test('las que exigen JWT reciben cabecerasParaEdgeFunction()', () {
      // **La prueba que evita un quinto sitio.** Lee los dos lados y los
      // compara: qué funciones exigen sesión (`supabase/config.toml`) y cómo
      // las llama Flutter. El contrato estaba escrito en dos archivos que
      // ninguna prueba leía a la vez, que es exactamente lo que dejó pasar
      // este fallo en cuatro sitios a la vez.
      final config = File('supabase/config.toml').readAsLinesSync();

      // Secciones `[functions.NOMBRE]` seguidas de `verify_jwt = true`.
      final exigenSesion = <String>[];
      String? seccion;
      for (final linea in config) {
        final recortada = linea.trim();
        final encabezado = RegExp(r'^\[functions\.([^\]]+)\]').firstMatch(recortada);
        if (encabezado != null) {
          seccion = encabezado.group(1);
          continue;
        }
        if (seccion != null && recortada.startsWith('verify_jwt')) {
          if (recortada.endsWith('true')) exigenSesion.add(seccion);
          seccion = null;
        }
      }

      expect(
        exigenSesion,
        isNotEmpty,
        reason:
            'No se leyó ninguna función con verify_jwt = true en '
            'supabase/config.toml. Si cambió el formato del archivo, esta '
            'prueba dejó de vigilar nada y hay que arreglarla.',
      );

      final infractores = <String>[];

      for (final entidad in Directory('lib').listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

        final ruta = entidad.path.replaceAll(r'\', '/');
        final fuente = entidad
            .readAsLinesSync()
            .where((linea) => !linea.trimLeft().startsWith('//'))
            .join('\n');

        for (final funcion in exigenSesion) {
          for (final llamada in "'$funcion'".allMatches(fuente)) {
            // Solo interesa si es una invocación, no una mención cualquiera.
            final antes = fuente.substring(
              (llamada.start - 60).clamp(0, fuente.length),
              llamada.start,
            );
            if (!antes.contains('functions.invoke(')) continue;

            final hasta = (llamada.end + 400).clamp(0, fuente.length);
            final cuerpo = fuente.substring(llamada.end, hasta);
            if (cuerpo.contains('cabecerasParaEdgeFunction()')) continue;

            infractores.add('$ruta · $funcion');
          }
        }
      }

      expect(
        infractores,
        isEmpty,
        reason:
            'Estas llamadas van a una Edge Function que exige sesión sin '
            'refrescar el token antes. Con el token vencido devuelven 401, y '
            'en dos de los cuatro caminos el error se traga por diseño, así '
            'que el fallo es invisible. Usa '
            '`headers: await cabecerasParaEdgeFunction()`: '
            '${infractores.join(', ')}',
      );
    });
  });
}
