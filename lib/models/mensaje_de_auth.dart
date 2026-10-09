import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce al español lo que Supabase Auth responde en inglés (hallazgo BA).
///
/// **Por qué existe.** El 19-sep el propietario probó a propósito un código
/// caducado y la pantalla le contestó **«Token has expired or is invalid»**.
/// Está en inglés, dice *token* — una palabra que nadie usa fuera de esto — y
/// **no dice qué hacer**. Es el mismo defecto que [AvisoDeEnlaceDeCorreo]
/// vino a cerrar para los errores de la dirección, en el otro sitio por donde
/// entran: las respuestas de `AuthException`.
///
/// **La regla, igual que allí:** todo mensaje dice **qué pasó y qué hacer**, y
/// **lo que no se conoce no se traga en silencio** — se deja pasar el texto
/// original antes que callar. Un mensaje en inglés es malo; ninguno es peor.
class MensajeDeAuth {
  const MensajeDeAuth._();

  /// Devuelve el mensaje que se le enseña a una persona.
  static String enEspanol(AuthException error) {
    switch (error.code) {
      case 'otp_expired':
        // CF (D-309): Supabase da este mismo error para un código vencido,
        // uno equivocado y uno VIEJO. El 02-oct el equipo del primer cliente
        // real escribió el del primer correo cuando ya se había pedido otro.
        return 'Ese código ya no sirve. Si te llegaron varios correos, usa el '
            'del más reciente, o pide otro aquí abajo.';
      case 'invalid_credentials':
        return 'El correo o la contraseña no coinciden.';
      case 'email_not_confirmed':
        return 'Tu correo todavía no está confirmado.';
      case 'over_email_send_rate_limit':
        return 'Pediste varios códigos muy seguido. Espera un minuto y '
            'vuelve a intentarlo.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Ya existe una cuenta con ese correo. Inicia sesión.';
      case 'weak_password':
        return 'Esa contraseña es muy débil. Usa al menos 8 caracteres.';
      case 'validation_failed':
        return 'Revisa el correo: parece que está mal escrito.';
      case 'signup_disabled':
        return 'Los registros están cerrados en este momento.';
      // Recuperar y cambiar la contraseña (hallazgo CO, D-327).
      case 'same_password':
        return 'Esa es la misma contraseña que ya tienes. Escribe una distinta.';
      case 'reauthentication_not_valid':
        return 'Ese código no sirve. Revisa el del correo más reciente o pide otro.';
      case 'insufficient_aal':
        return 'Primero confirma con el código de tu app autenticadora.';
      default:
        // A propósito: si no lo conocemos, se enseña tal cual. Tragarse un
        // error porque no está traducido es exactamente lo que hacía AM.
        return error.message;
    }
  }
}
