import 'package:flutter/services.dart';

/// La regla del celular en la pantalla, y **el único sitio de Dart donde está
/// escrito el 10** (D-249).
///
/// **Por qué existe.** El celular es la llave de la clienta: con él y un PIN
/// entra al portal a ver sus citas y sus fotos (D-167). El propietario decidió
/// el 19-sep que esa llave no se comparte — *"cuando un usuario del número
/// autorice datos del otro, ahí qué?"* — y que el campo la exija bien escrita
/// en vez de arreglarla después.
///
/// **Por qué el número no se reparte por el código.** Esta misma semana costó
/// dos veces escribir a mano un valor que vive en otra parte: `'profesional'`
/// dentro de `register_tenant` dejó el registro roto dieciséis días (D-245), y
/// el `6` del código de confirmación habría cortado dos dígitos de un código
/// de ocho (hallazgo AY). Aquí el 10 está una vez, igual que en la base está
/// una vez en `private.beautyos_celular_valido`.
///
/// **El día que haya un segundo país**, esto deja de ser una constante y pasa
/// a ser un dato del país elegido. Hoy hay un país y sobra la tabla.
class CelularColombiano {
  const CelularColombiano._();

  /// Lo que se le enseña delante del campo. **No es editable a propósito:**
  /// si se pudiera escribir, volvería a haber dos formas de guardar el mismo
  /// número, que es exactamente lo que costó el hallazgo AW.
  static const indicativo = '+57';

  static const digitos = 10;

  static const ejemplo = '3001234567';

  /// Solo números, y nunca más de los que caben. Cortar aquí evita que
  /// alguien pegue un número con el indicativo dentro y se lleve un rechazo
  /// que no entiende.
  static final formatos = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(digitos),
  ];

  /// Deja el número como se guarda: solo dígitos, y sin el indicativo cuando
  /// alguien lo pegó de WhatsApp.
  static String normalizar(String escrito) {
    final soloDigitos = escrito.replaceAll(RegExp(r'[^0-9]'), '');

    if (soloDigitos.length == digitos + 2 && soloDigitos.startsWith('57')) {
      return soloDigitos.substring(2);
    }

    return soloDigitos;
  }

  /// El validador del formulario. Devuelve `null` cuando está bien.
  static String? validar(String? valor) {
    final numero = normalizar(valor ?? '');

    if (numero.isEmpty) {
      return 'Escribe el celular de la clienta';
    }

    if (numero.length != digitos) {
      return 'El celular son $digitos números (van ${numero.length})';
    }

    return null;
  }
}
