/// Lo que calcula la página pública del salón rediseñada (D-320, 08-oct),
/// sin pantalla de por medio para poder probarlo: si está abierto ahora, las
/// horas como se dicen en Colombia, hace cuánto se escribió una reseña y las
/// categorías de los servicios.
library;

import 'business_hour.dart';
import 'public_salon_profile.dart';
import 'public_salon_service_item.dart';

/// La hora en Colombia, que no cambia de horario en el año (UTC−5). Se usa
/// esta y no la del celular de quien visita: un colombiano que mira la página
/// desde fuera vería "abierto" o "cerrado" a la hora equivocada. Las horas
/// que devuelve se leen como hora local de Colombia (aunque la marca diga
/// UTC). El día que haya salones fuera de Colombia, la zona saldrá de la sede.
DateTime ahoraEnColombia([DateTime? ahora]) =>
    (ahora ?? DateTime.now()).toUtc().subtract(const Duration(hours: 5));

/// '08:00:00' → 480. Null si no se puede leer.
int? minutosDelDia(String? hora) {
  if (hora == null) return null;
  final partes = hora.trim().split(':');
  if (partes.length < 2) return null;
  final h = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// '20:00:00' → '8:00 p. m.', como se dice en Colombia.
String horaLegible(String? hora) {
  final minutos = minutosDelDia(hora);
  if (minutos == null) return '--:--';
  final h = minutos ~/ 60;
  final m = (minutos % 60).toString().padLeft(2, '0');
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${h < 12 ? 'a. m.' : 'p. m.'}';
}

/// "a las 8:00 a. m.", pero "a la 1:00 p. m.".
String _aLas(String hora) => hora.startsWith('1:') ? 'a la $hora' : 'a las $hora';

/// "Abierto ahora · cierra 8:00 p. m.", "Cerrado · abre hoy a las 8:00 a. m.",
/// "Cerrado · abre mañana…" o "…abre el lunes…". Null si el salón no tiene
/// ningún día abierto publicado: mejor nada que un "cerrado" falso.
({bool abierto, String texto})? estadoDeApertura(
  List<BusinessHour> horas,
  DateTime ahora,
) {
  BusinessHour? delDia(int dia) {
    for (final h in horas) {
      if (h.dayOfWeek == dia &&
          h.isOpen &&
          minutosDelDia(h.opensAt) != null &&
          minutosDelDia(h.closesAt) != null) {
        return h;
      }
    }
    return null;
  }

  final ahoraMin = ahora.hour * 60 + ahora.minute;
  final hoy = delDia(ahora.weekday);
  if (hoy != null) {
    final abre = minutosDelDia(hoy.opensAt)!;
    final cierra = minutosDelDia(hoy.closesAt)!;
    if (ahoraMin >= abre && ahoraMin < cierra) {
      return (abierto: true, texto: 'Abierto ahora · cierra ${horaLegible(hoy.closesAt)}');
    }
    if (ahoraMin < abre) {
      return (abierto: false, texto: 'Cerrado · abre hoy ${_aLas(horaLegible(hoy.opensAt))}');
    }
  }
  for (var k = 1; k <= 7; k++) {
    final dia = (ahora.weekday - 1 + k) % 7 + 1;
    final h = delDia(dia);
    if (h != null) {
      final cuando = k == 1 ? 'mañana' : 'el ${h.dayName.toLowerCase()}';
      return (abierto: false, texto: 'Cerrado · abre $cuando ${_aLas(horaLegible(h.opensAt))}');
    }
  }
  return null;
}

/// "hoy", "ayer", "hace 3 días", "hace 2 semanas", "hace 1 mes"…
String haceCuanto(DateTime fecha, DateTime ahora) {
  final dias = ahora.difference(fecha).inDays;
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  if (dias < 7) return 'hace $dias días';
  if (dias < 30) {
    final s = dias ~/ 7;
    return s == 1 ? 'hace 1 semana' : 'hace $s semanas';
  }
  if (dias < 365) {
    final m = dias ~/ 30;
    return m == 1 ? 'hace 1 mes' : 'hace $m meses';
  }
  final a = dias ~/ 365;
  return a == 1 ? 'hace 1 año' : 'hace $a años';
}

/// 45 → '45 min'; 120 → '2 h'; 150 → '2 h 30 min'.
String duracionLegible(int minutos) {
  if (minutos < 60) return '$minutos min';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Las categorías de los servicios, en el orden en que aparecen. Vacía si
/// hay menos de dos: un filtro con una sola opción no filtra nada.
List<String> categoriasDeServicios(List<PublicSalonServiceItem> servicios) {
  final vistas = <String>[];
  for (final s in servicios) {
    final c = s.description?.trim() ?? '';
    if (c.isNotEmpty && !vistas.contains(c)) vistas.add(c);
  }
  return vistas.length < 2 ? const <String>[] : vistas;
}

/// 4.9 → '4,9'.
String calificacionLegible(double promedio) =>
    promedio.toStringAsFixed(1).replaceAll('.', ',');

/// 'Salón Magnolia' → 'SM'; 'Erick' → 'E'.
String iniciales(String nombre) {
  final palabras = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letras = palabras.take(2).map((p) => p[0].toUpperCase()).join();
  return letras.isEmpty ? '?' : letras;
}

/// Google Maps con la dirección de la sede principal y la ciudad.
Uri? enlaceDeMapa(PublicSalonProfile salon) {
  final direccion = salon.address?.trim();
  if (direccion == null || direccion.isEmpty) return null;
  final ciudad = salon.city?.trim();
  final consulta =
      ciudad != null && ciudad.isNotEmpty ? '$direccion, $ciudad' : direccion;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': consulta,
  });
}
