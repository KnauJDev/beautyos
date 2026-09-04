/// Garantiza que el token que viaja a una Edge Function esta vigente (D-207).
///
/// **El fallo que cierra.** Los tokens de Supabase caducan a la hora. Las
/// cuatro Edge Functions que exigen sesion (`create-epayco-session`,
/// `verify-epayco-transaction`, `send-invitation-email` y
/// `send-low-stock-alert`) validan el token con `auth.getUser(token)` y
/// responden **401** si vencio. El sintoma que reporto el propietario fue el
/// mas visible: *"Se requiere una sesion autenticada para generar la sesion de
/// pago"* al darle a renovar la suscripcion. **No se podia cobrar.**
///
/// **Por que no bastaba con el SDK.** `SupabaseClient` arma la cabecera con
/// `auth.currentSession?.accessToken` y **la guarda**, actualizandola solo
/// cuando ocurre un refresco. Si el token vence sin que el refresco dispare
/// --una pestana de fondo en web, donde los temporizadores se estrangulan--
/// la cabecera guardada queda igual de vieja. Leer `currentSession` a mano,
/// como hacia `epayco_checkout_service`, tiene exactamente el mismo problema:
/// **nadie fuerza el refresco antes de llamar.**
///
/// **Por que en un solo sitio.** Es la leccion de D-198 aplicada antes de que
/// duela: el mismo fallo estaba en los cuatro sitios que llaman Edge
/// Functions, y en dos de ellos era **invisible** porque el error ya se traga
/// por diseno --la alerta de stock y el correo de invitacion simplemente no
/// salian--. Arreglarlo solo donde se noto habria dejado tres vivos.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Si hay que pedir un token nuevo antes de llamar.
///
/// `Session.isExpired` trae **30 segundos de margen** (`Constants.expiryMargin`)
/// a proposito: un token al que le quedan menos de 30 segundos ya se considera
/// vencido, porque si no la llamada podria salir con un token que caduca en
/// vuelo. (El comentario del propio `gotrue` dice "10 seconds" y esta
/// desactualizado respecto a su constante: manda la constante.)
///
/// **Ojo con un detalle de `isExpired`:** devuelve `false` cuando no puede
/// leer la fecha de caducidad, o sea cuando el token no es un JWT que se pueda
/// decodificar. Es lo correcto --no se puede afirmar que algo vencio si no se
/// sabe cuando vence-- pero significa que un token con forma rara pasa de
/// largo y sera el servidor quien lo rechace.
bool necesitaRefresco(Session? sesion) => sesion == null || sesion.isExpired;

/// La cabecera de autorizacion de una sesion.
///
/// Se pasa **explicitamente** en cada llamada en vez de confiar en la que el
/// SDK guarda, porque esa es justo la que puede estar vieja.
Map<String, String> cabeceraDeSesion(Session sesion) => <String, String>{
  'Authorization': 'Bearer ${sesion.accessToken}',
};

/// Devuelve una sesion con el token vigente, refrescandolo si hace falta.
///
/// Lanza si no hay forma de conseguir una: el llamador decide si eso se le
/// ensena a la persona (como en el cobro, donde tiene que volver a entrar) o
/// se traga (como en la alerta de stock, que es de mejor esfuerzo).
Future<Session> sesionFresca() async {
  final auth = Supabase.instance.client.auth;
  var sesion = auth.currentSession;

  if (necesitaRefresco(sesion)) {
    final refrescada = await auth.refreshSession();
    sesion = refrescada.session;
  }

  if (sesion == null) {
    throw Exception(
      'Tu sesión ha expirado. Por favor inicia sesión de nuevo.',
    );
  }

  return sesion;
}

/// Atajo para `functions.invoke`: las cabeceras con el token ya fresco.
///
/// Uso: `headers: await cabecerasParaEdgeFunction()`.
Future<Map<String, String>> cabecerasParaEdgeFunction() async {
  return cabeceraDeSesion(await sesionFresca());
}
