import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/review_reply_draft.dart';
import 'package:salonymas/models/review_summary.dart';

void main() {
  group('ReviewSummary.fromMap y tieneRespuesta (D-170)', () {
    ReviewSummary base({String? businessReply, String? businessReplyAt}) {
      return ReviewSummary.fromMap({
        'id': 'r1',
        'ticket_id': 't1',
        'client_name': 'Ana',
        'stylist_name': 'Carla',
        'service_name': 'Manicure',
        'rating': 5,
        'comment': 'Muy bien',
        'moderation_status': 'approved',
        'visible_to_public': true,
        'business_reply': businessReply,
        'business_reply_at': businessReplyAt,
        'created_at': '2026-08-20T10:00:00Z',
      });
    }

    test('sin respuesta, tieneRespuesta es false y ambos campos son null', () {
      final review = base();

      expect(review.tieneRespuesta, isFalse);
      expect(review.businessReply, isNull);
      expect(review.businessReplyAt, isNull);
    });

    test('con respuesta, tieneRespuesta es true y trae la fecha', () {
      final review = base(
        businessReply: 'Gracias por tu comentario',
        businessReplyAt: '2026-08-21T09:00:00Z',
      );

      expect(review.tieneRespuesta, isTrue);
      expect(review.businessReply, 'Gracias por tu comentario');
      expect(review.businessReplyAt, isNotNull);
    });
  });


  group('ReviewReplyDraftBuilder.generar (D-170)', () {
    test('5 estrellas: tono entusiasta, saluda por el nombre e invita a volver', () {
      final texto = ReviewReplyDraftBuilder.generar(
        rating: 5,
        clientName: 'Yelimar Rodríguez',
        serviceName: 'Manicure',
        businessName: 'Naguara de Uñas',
      );

      expect(texto, contains('Muchas gracias, Yelimar'));
      expect(texto, contains('Manicure'));
      expect(texto, contains('Naguara de Uñas'));
    });

    test('4 estrellas: agradece y pide qué mejorar', () {
      final texto = ReviewReplyDraftBuilder.generar(
        rating: 4,
        clientName: 'Carlos Pérez',
        serviceName: 'Corte',
        businessName: 'Salón X',
      );

      expect(texto, contains('Gracias por tu comentario, Carlos'));
      expect(texto, contains('qué podemos mejorar'));
    });

    test('3 estrellas: tono neutral, invita a escribir', () {
      final texto = ReviewReplyDraftBuilder.generar(
        rating: 3,
        clientName: 'Ana',
        serviceName: 'Pedicure',
        businessName: 'Salón X',
      );

      expect(texto, contains('Gracias por contarnos tu experiencia, Ana'));
      expect(texto, contains('escríbenos'));
    });

    test('1-2 estrellas: tono de disculpa, invita a contactar', () {
      final baja = ReviewReplyDraftBuilder.generar(
        rating: 1,
        clientName: 'Laura',
        serviceName: 'Color',
        businessName: 'Salón X',
      );
      final media = ReviewReplyDraftBuilder.generar(
        rating: 2,
        clientName: 'Laura',
        serviceName: 'Color',
        businessName: 'Salón X',
      );

      expect(baja, contains('Lamentamos'));
      expect(baja, contains('Laura'));
      expect(media, contains('Lamentamos'));
    });

    test('usa solo el primer nombre aunque llegue el nombre completo', () {
      final texto = ReviewReplyDraftBuilder.generar(
        rating: 5,
        clientName: 'Yelimar Andrea Rodríguez Pérez',
        serviceName: 'Manicure',
        businessName: 'Salón X',
      );

      expect(texto, contains(', Yelimar!'));
      expect(texto, isNot(contains('Andrea')));
    });

    test('cliente no asociado: omite el saludo en vez de un nombre genérico a mitad de frase', () {
      final texto = ReviewReplyDraftBuilder.generar(
        rating: 5,
        clientName: 'Cliente no asociado',
        serviceName: 'Manicure',
        businessName: 'Salón X',
      );

      expect(texto, isNot(contains('Cliente no asociado')));
      expect(texto, startsWith('¡Muchas gracias! '));
    });

    test('servicio no asociado cae en un texto genérico', () {
      final texto = ReviewReplyDraftBuilder.generar(
        rating: 5,
        clientName: 'Ana',
        serviceName: 'Servicio no asociado',
        businessName: 'Salón X',
      );

      expect(texto, contains('el servicio'));
      expect(texto, isNot(contains('Servicio no asociado')));
    });
  });
}
