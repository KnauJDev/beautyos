import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/publication_studio_data.dart';

void main() {
  group('PublicationStudioData.fromMap (D-169)', () {
    test('mapea todos los campos cuando hay reseña', () {
      final data = PublicationStudioData.fromMap({
        'photo_url': 'https://ejemplo.supabase.co/foto.jpg',
        'service_names': 'Manicure, Pedicure',
        'review_rating': 5,
        'review_comment': 'Excelente atención',
        'review_client_name': 'Yelimar',
      });

      expect(data.photoUrl, 'https://ejemplo.supabase.co/foto.jpg');
      expect(data.serviceNames, 'Manicure, Pedicure');
      expect(data.reviewRating, 5);
      expect(data.reviewComment, 'Excelente atención');
      expect(data.reviewClientName, 'Yelimar');
    });

    test('sin reseña, los tres campos llegan null y no rompe el mapeo', () {
      final data = PublicationStudioData.fromMap({
        'photo_url': 'https://ejemplo.supabase.co/foto.jpg',
        'service_names': 'Manicure',
        'review_rating': null,
        'review_comment': null,
        'review_client_name': null,
      });

      expect(data.reviewRating, isNull);
      expect(data.reviewComment, isNull);
      expect(data.reviewClientName, isNull);
    });

    test('review_rating llega como texto desde la RPC y se convierte a int', () {
      final data = PublicationStudioData.fromMap({
        'photo_url': 'https://ejemplo.supabase.co/foto.jpg',
        'service_names': null,
        'review_rating': '4',
        'review_comment': 'Muy bien',
        'review_client_name': 'Carla',
      });

      expect(data.reviewRating, 4);
    });
  });

  group('tieneResena (D-169)', () {
    test('true cuando rating y comment vienen completos', () {
      const data = PublicationStudioData(
        photoUrl: 'https://x/foto.jpg',
        reviewRating: 5,
        reviewComment: 'Me encantó',
      );

      expect(data.tieneResena, isTrue);
    });

    test('false cuando no hay reseña', () {
      const data = PublicationStudioData(photoUrl: 'https://x/foto.jpg');

      expect(data.tieneResena, isFalse);
    });

    test('false cuando el comentario llega vacío', () {
      const data = PublicationStudioData(
        photoUrl: 'https://x/foto.jpg',
        reviewRating: 5,
        reviewComment: '   ',
      );

      expect(data.tieneResena, isFalse);
    });
  });

  group('servicioTexto (D-169)', () {
    test('usa los nombres de servicio cuando existen', () {
      const data = PublicationStudioData(
        photoUrl: 'https://x/foto.jpg',
        serviceNames: 'Corte, Color',
      );

      expect(data.servicioTexto, 'Corte, Color');
    });

    test('cae en un texto genérico si el ticket no trae servicios', () {
      const data = PublicationStudioData(photoUrl: 'https://x/foto.jpg');

      expect(data.servicioTexto, 'Servicio realizado');
    });
  });
}
