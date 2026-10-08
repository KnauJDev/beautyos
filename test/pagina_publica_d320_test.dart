import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/business_hour.dart';
import 'package:salonymas/models/pagina_publica.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/models/public_salon_review_item.dart';
import 'package:salonymas/models/public_salon_service_item.dart';
import 'package:salonymas/models/public_salon_team_member.dart';
import 'package:salonymas/pages/public_salon_page.dart';

/// D-320 (08-oct): la página pública rediseñada con el prototipo que aprobó
/// el propietario (https://claude.ai/artifact/H4GUdBqnaVu1h3rhzTgGPF).
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

BusinessHour dia(int d, {String? abre = '08:00:00', String? cierra = '20:00:00', bool abierto = true}) =>
    BusinessHour(id: '$d', dayOfWeek: d, opensAt: abre, closesAt: cierra, isOpen: abierto);

/// Lunes a sábado de 8 a 8; el domingo, cerrado.
final semana = [for (var d = 1; d <= 6; d++) dia(d), dia(7, abierto: false)];

/// Miércoles 7 de octubre de 2026 a una hora de Colombia.
DateTime miercolesA(int h, [int m = 0]) => DateTime(2026, 10, 7, h, m);

PublicSalonFullProfile perfilDeEjemplo() => PublicSalonFullProfile(
  profile: PublicSalonProfile.fromMap({
    'tenant_id': 't1',
    'name': 'Salón Magnolia',
    'slug': 'salon-magnolia',
    'business_type': 'salon',
    'city': 'Bogotá',
    'address': 'Cra. 13 # 63-41',
    'whatsapp': '3001234567',
    'instagram': '@magnolia',
    'tiktok': '@magnolia',
    'primary_branch_id': 'b1',
    'business_hours': [
      for (var d = 1; d <= 6; d++)
        {'day_of_week': d, 'opens_at': '08:00:00', 'closes_at': '20:00:00', 'is_open': true},
      {'day_of_week': 7, 'opens_at': null, 'closes_at': null, 'is_open': false},
    ],
  }),
  services: const [
    PublicSalonServiceItem(id: 's1', name: 'Corte dama', description: 'Cabello', durationMinutes: 45, priceCop: 35000),
    PublicSalonServiceItem(id: 's2', name: 'Tinte completo', description: 'Cabello', durationMinutes: 120, priceCop: 120000),
    PublicSalonServiceItem(id: 's3', name: 'Rubber', description: 'Uñas', durationMinutes: 75, priceCop: 55000),
  ],
  portfolio: const [],
  team: const [
    PublicSalonTeamMember(id: 'e1', name: 'Paola', bio: 'Colorista · 8 años de experiencia'),
    PublicSalonTeamMember(id: 'e2', name: 'Erick', bio: 'Cortes y barbería'),
  ],
  reviews: PublicSalonReviewsSummary(
    avgRating: 4.9,
    totalReviews: 37,
    reviews: [
      PublicSalonReviewItem(
        clientName: 'Reseña verificada',
        rating: 5,
        comment: 'Me encantó el tinte, quedó tal cual lo pedí.',
        businessReply: '¡Gracias! Te esperamos.',
        createdAt: DateTime(2026, 10, 5),
      ),
    ],
  ),
  blogPosts: const [],
);

void main() {
  group('abierto ahora', () {
    test('abierto: dice a qué hora cierra', () {
      expect(estadoDeApertura(semana, miercolesA(10)), (abierto: true, texto: 'Abierto ahora · cierra 8:00 p. m.'));
    });
    test('antes de abrir: abre hoy', () {
      expect(estadoDeApertura(semana, miercolesA(6, 30))?.texto, 'Cerrado · abre hoy a las 8:00 a. m.');
    });
    test('después de cerrar: abre mañana', () {
      expect(estadoDeApertura(semana, miercolesA(21))?.texto, 'Cerrado · abre mañana a las 8:00 a. m.');
    });
    test('el sábado por la noche, con el domingo cerrado: abre el lunes', () {
      expect(estadoDeApertura(semana, DateTime(2026, 10, 10, 21))?.texto, 'Cerrado · abre el lunes a las 8:00 a. m.');
    });
    test('a la 1, no "a las 1"', () {
      final tarde = [dia(3, abre: '13:00:00', cierra: '19:00:00')];
      expect(estadoDeApertura(tarde, miercolesA(9))?.texto, 'Cerrado · abre hoy a la 1:00 p. m.');
    });
    test('sin horario publicado, nada: mejor que un "cerrado" falso', () {
      expect(estadoDeApertura(const [], miercolesA(10)), isNull);
      expect(estadoDeApertura([dia(1, abierto: false)], miercolesA(10)), isNull);
    });
    test('la hora es la de Colombia, no la del celular de quien visita', () {
      // 03:00 UTC del 8 de octubre son las 10 p. m. del 7 en Bogotá.
      final bogota = ahoraEnColombia(DateTime.utc(2026, 10, 8, 3));
      expect((bogota.day, bogota.hour), (7, 22));
    });
  });

  group('cómo se dicen las cosas', () {
    test('las horas', () {
      expect(horaLegible('08:00:00'), '8:00 a. m.');
      expect(horaLegible('20:00:00'), '8:00 p. m.');
      expect(horaLegible('12:30'), '12:30 p. m.');
      expect(horaLegible('00:15:00'), '12:15 a. m.');
      expect(horaLegible(null), '--:--');
    });
    test('hace cuánto', () {
      final hoy = DateTime(2026, 10, 8, 12);
      expect(haceCuanto(DateTime(2026, 10, 8, 9), hoy), 'hoy');
      expect(haceCuanto(DateTime(2026, 10, 7, 9), hoy), 'ayer');
      expect(haceCuanto(DateTime(2026, 10, 5, 9), hoy), 'hace 3 días');
      expect(haceCuanto(DateTime(2026, 9, 20), hoy), 'hace 2 semanas');
      expect(haceCuanto(DateTime(2026, 8, 1), hoy), 'hace 2 meses');
      expect(haceCuanto(DateTime(2025, 9, 1), hoy), 'hace 1 año');
    });
    test('la duración, la calificación y las iniciales', () {
      expect(duracionLegible(45), '45 min');
      expect(duracionLegible(120), '2 h');
      expect(duracionLegible(150), '2 h 30 min');
      expect(calificacionLegible(4.9), '4,9');
      expect(iniciales('Salón Magnolia'), 'SM');
      expect(iniciales('Erick'), 'E');
    });
    test('las categorías: sin filtro si hay una sola', () {
      final s = perfilDeEjemplo().services;
      expect(categoriasDeServicios(s), ['Cabello', 'Uñas']);
      expect(categoriasDeServicios(s.take(2).toList()), isEmpty);
    });
  });

  group('la página dibujada', () {
    Widget pagina({VoidCallback? onBook, void Function(String)? onReserve}) => MaterialApp(
      home: Scaffold(
        body: ContenidoDeLaPaginaPublica(
          perfil: perfilDeEjemplo(),
          ahora: miercolesA(10),
          onBook: onBook ?? () {},
          onReserve: onReserve ?? (_) {},
          onOpenPortal: () {},
          onAbrir: (_) async {},
        ),
      ),
    );

    for (final (nombre, ancho) in [('celular', 390.0), ('computador', 1280.0)]) {
      testWidgets('se dibuja sin desbordes en un $nombre', (tester) async {
        tester.view.physicalSize = Size(ancho, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(pagina());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Salón Magnolia'), findsOneWidget);
        expect(find.text('Abierto ahora · cierra 8:00 p. m.'), findsWidgets);
        expect(find.text('Quién te atiende'), findsOneWidget);
        expect(find.text('Lo que dicen'), findsOneWidget);
        expect(find.text('Horarios y ubicación'), findsOneWidget);
        expect(find.text('Miércoles · hoy'), findsOneWidget);
        expect(find.text('TikTok'), findsOneWidget);
        // En el computador, la reserva va también en la columna de la derecha.
        expect(find.text('Reserva en línea'), ancho >= anchoParaDosColumnas ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('los filtros de categoría filtran, y Reservar lleva el servicio', (tester) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? reservado;
      await tester.pumpWidget(pagina(onReserve: (id) => reservado = id));
      await tester.pumpAndSettle();
      expect(find.text('3 servicios'), findsOneWidget);
      await tester.tap(find.text('Uñas'));
      await tester.pumpAndSettle();
      expect(find.text('1 servicio'), findsOneWidget);
      expect(find.text('Corte dama'), findsNothing);
      await tester.ensureVisible(find.text('Reservar'));
      await tester.tap(find.text('Reservar'));
      expect(reservado, 's3');
    });

    testWidgets('en el celular, la barra de abajo agenda y abre WhatsApp', (tester) async {
      var agendo = false;
      var whatsapp = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraDeReserva(
            onBook: () => agendo = true,
            onWhatsApp: () => whatsapp = true,
          ),
        ),
      ));
      await tester.tap(find.text('Agendar cita'));
      await tester.tap(find.bySemanticsLabel('WhatsApp'));
      expect((agendo, whatsapp), (true, true));
    });
  });

  group('lo que la página de antes ya cuidaba', () {
    final pagina = leer('lib/pages/public_salon_page.dart');
    test('la reserva con el servicio ya elegido, y el portal de la clienta', () {
      expect(pagina, contains('preselectedServiceId: serviceId,'));
      expect(pagina, contains('ClientPortalPage('));
      expect(pagina, contains('PublicBlogPostPage(post: post)'));
    });
    test('los colores del salón, antes de pintar', () {
      expect(pagina, contains('AppBrand.aplicar(result.profile.themeKey, result.profile.brandColor);'));
    });
    test('sin emojis: ni el 📍 del mapa', () {
      expect(pagina, isNot(contains("Text('📍'")));
    });
    test('no promete "confirmada": con caja, la reserva queda pendiente', () {
      expect(pagina, isNot(contains("'Sin crear cuenta ni contraseña. Tu cita queda confirmada")));
    });
  });
}
