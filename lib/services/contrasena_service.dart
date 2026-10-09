import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Recuperar y cambiar la contraseña (hallazgo CO, D-327). Prototipo
/// aprobado: https://claude.ai/artifact/G1TdLy6V3VVGmbKWGpJCoK
///
/// **Con un código, no con un enlace**, igual que activar la cuenta (D-248):
/// los revisores de correo abren los enlaces antes que la persona y los
/// gastan. El correo *Reset Password* de Supabase lleva el código
/// (`PLANTILLAS_CORREO_AUTH.md`, sección 5).

/// Entró con el código de recuperar y le falta crear la contraseña nueva.
/// [AuthGate] la pide en cuanto la sesión está completa: después de la
/// verificación en dos pasos, si la cuenta la tiene.
final crearContrasenaNueva = ValueNotifier<bool>(false);

class ContrasenaService {
  const ContrasenaService();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Manda el código al correo. Si el correo no tiene cuenta, Supabase no
  /// dice nada (así nadie averigua qué correos están registrados).
  Future<void> pedirCodigo(String correo) =>
      _auth.resetPasswordForEmail(correo.trim());

  /// Entra con el código. Si sirve, queda pendiente crear la contraseña nueva.
  Future<void> entrarConCodigo({
    required String correo,
    required String codigo,
  }) async {
    // Se marca ANTES: al abrirse la sesión, AuthGate se redibuja enseguida y
    // tiene que saber ya que falta la contraseña nueva.
    crearContrasenaNueva.value = true;
    try {
      final respuesta = await _auth.verifyOTP(
        email: correo.trim(),
        token: codigo,
        type: OtpType.recovery,
      );
      if (respuesta.session == null) {
        throw const AuthException('Ese código no sirvió. Pide otro.');
      }
    } catch (_) {
      crearContrasenaNueva.value = false;
      rethrow;
    }
  }

  /// Cambia la contraseña de quien tiene la sesión abierta. `codigo` es el de
  /// seguridad que Supabase pide a veces (ver [pedirCodigoDeSeguridad]).
  Future<void> cambiar(String nueva, {String? codigo}) async {
    await _auth.updateUser(UserAttributes(password: nueva, nonce: codigo));
  }

  /// Si la sesión es de hace más de un día, Supabase pide confirmar con un
  /// código al correo antes de cambiar la contraseña
  /// (`reauthentication_needed`). Esto lo manda.
  Future<void> pedirCodigoDeSeguridad() => _auth.reauthenticate();
}
