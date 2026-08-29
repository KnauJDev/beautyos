import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/blog_post.dart';
import 'package:salonymas/models/public_salon_blog_post.dart';

void main() {
  group('BlogPost.fromMap (D-171)', () {
    test('mapea todos los campos de un artículo publicado', () {
      final post = BlogPost.fromMap({
        'id': 'p1',
        'title': 'Cuidados después de una manicure',
        'content': 'Primer párrafo.',
        'cover_photo_url': 'https://x/portada.jpg',
        'published': true,
        'created_at': '2026-08-29T10:00:00Z',
        'updated_at': '2026-08-29T11:00:00Z',
      });

      expect(post.title, 'Cuidados después de una manicure');
      expect(post.published, isTrue);
      expect(post.statusText, 'Publicado');
      expect(post.coverPhotoUrl, 'https://x/portada.jpg');
    });

    test('un borrador sin portada mapea correctamente', () {
      final post = BlogPost.fromMap({
        'id': 'p2',
        'title': 'Borrador',
        'content': 'Sin terminar.',
        'cover_photo_url': null,
        'published': false,
        'created_at': '2026-08-29T10:00:00Z',
        'updated_at': '2026-08-29T10:00:00Z',
      });

      expect(post.published, isFalse);
      expect(post.statusText, 'Borrador');
      expect(post.coverPhotoUrl, isNull);
    });

    test('createdDateText formatea dd/mm/aaaa', () {
      final post = BlogPost.fromMap({
        'id': 'p3',
        'title': 'T',
        'content': 'C',
        'published': false,
        'created_at': '2026-01-05T10:00:00Z',
        'updated_at': '2026-01-05T10:00:00Z',
      });

      expect(post.createdDateText, '05/01/2026');
    });
  });

  group('PublicSalonBlogPost.fromMap y excerpt (D-171)', () {
    test('mapea los campos públicos', () {
      final post = PublicSalonBlogPost.fromMap({
        'id': 'p1',
        'title': 'Título',
        'content': 'Contenido corto.',
        'cover_photo_url': 'https://x/portada.jpg',
        'created_at': '2026-08-29T10:00:00Z',
      });

      expect(post.title, 'Título');
      expect(post.content, 'Contenido corto.');
      expect(post.coverPhotoUrl, 'https://x/portada.jpg');
    });

    test('contenido corto no se recorta ni agrega puntos suspensivos', () {
      final post = PublicSalonBlogPost.fromMap({
        'id': 'p1',
        'title': 'Título',
        'content': 'Un consejo breve.',
      });

      expect(post.excerpt, 'Un consejo breve.');
    });

    test('contenido largo se recorta en un límite de palabra, no a mitad', () {
      final contenido = List.filled(30, 'palabra').join(' ');
      final post = PublicSalonBlogPost.fromMap({
        'id': 'p1',
        'title': 'Título',
        'content': contenido,
      });

      expect(post.excerpt.endsWith('…'), isTrue);
      expect(post.excerpt.length, lessThanOrEqualTo(141));

      // Cada palabra antes de "…" está completa: si hubiera cortado a
      // mitad de una, alguno de estos trozos no sería "palabra" exacta.
      final sinPuntos = post.excerpt.substring(0, post.excerpt.length - 1);
      for (final palabra in sinPuntos.trim().split(' ')) {
        expect(palabra, 'palabra');
      }
    });
  });
}
