/// La contraseña nueva, al recuperarla o al cambiarla (hallazgo CO, D-327).
///
/// La regla es la misma que al registrarse (`register_page.dart`): al menos
/// 8 caracteres. Quien decide de verdad es Supabase; esto solo evita mandar
/// lo que se sabe que va a fallar, y dice qué hacer.
class ContrasenaNueva {
  const ContrasenaNueva._();

  static const minimo = 8;

  /// `null` si se puede mandar; si no, el aviso para la persona.
  static String? aviso(String nueva, String repetida) {
    if (nueva.isEmpty) return 'Escribe la contraseña nueva.';
    if (nueva.length < minimo) {
      return 'Usa al menos $minimo caracteres.';
    }
    if (nueva != repetida) return 'Las dos contraseñas no coinciden.';
    return null;
  }
}
