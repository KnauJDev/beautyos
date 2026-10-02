import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Lo que se le dice a una clienta cuando algo falla en una página pública
/// (la reserva y la reseña). CE, D-307.
///
/// **El problema que resuelve.** Las dos páginas tenían copiada la misma
/// `_friendlyError`, que devolvía el texto crudo de la base. Cuando la base
/// negó el permiso, la clienta leyó *"permission denied for function
/// public_get_branch_booking_info"*: en inglés y con el nombre de una función
/// interna, lo que D-208 prohíbe enseñarle a nadie.
///
/// **Qué deja pasar y qué no.** Los mensajes que nuestras funciones escriben
/// para la clienta (`raise exception`, código `P0001`, como *"Ese horario ya
/// no está disponible"*) se enseñan tal cual: están pensados para ella, y la
/// página de reserva incluso los lee para recargar las horas (AX). Lo técnico
/// —permisos, una función o tabla que no aparece, los errores de la propia
/// API— se cambia por una frase humana. Y sin conexión, otra.
String mensajeParaLaClienta(Object error) {
  if (error is PostgrestException) {
    if (_esTecnico(error.code)) return algoFalloDeNuestroLado;
    final texto = error.message.trim();
    return texto.isEmpty ? algoFalloDeNuestroLado : texto;
  }
  if (error is TimeoutException || _pareceDeConexion(error)) {
    return sinConexion;
  }
  return algoFalloDeNuestroLado;
}

const algoFalloDeNuestroLado =
    'Algo falló de nuestro lado. Intenta de nuevo en unos minutos.';
const sinConexion =
    'No pudimos conectarnos. Revisa tu internet e intenta de nuevo.';

bool _esTecnico(String? codigo) {
  if (codigo == null || codigo.isEmpty) return false;
  if (codigo.startsWith('PGRST')) return true; // errores de la API, no del salón
  if (codigo.startsWith('08')) return true; // conexión con la base
  return const {
    '42501', // insufficient_privilege: el fallo de CE
    '42883', // undefined_function
    '42P01', // undefined_table
    '42703', // undefined_column
    '57014', // query_canceled (tiempo agotado)
  }.contains(codigo);
}

bool _pareceDeConexion(Object error) {
  final t = error.toString();
  return t.contains('SocketException') ||
      t.contains('ClientException') ||
      t.contains('Failed to fetch') ||
      t.contains('XMLHttpRequest');
}
