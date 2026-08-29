import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/public_salon_photo_item.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/models/public_salon_review_item.dart';
import 'package:salonymas/models/public_salon_service_item.dart';
import 'package:salonymas/models/public_salon_team_member.dart';

void main() {
  group('PublicSalonProfile (D-098 / D-164)', () {
    test('fromMap mapea todos los campos de la RPC pública', () {
      final profile = PublicSalonProfile.fromMap({
        'tenant_id': 'tenant-1',
        'name': 'Naguara de Uñas',
        'slug': 'naguara-de-unas',
        'business_type': 'Salón de uñas',
        'logo_url': 'https://ejemplo.com/logo.png',
        'cover_photo_url': 'https://ejemplo.com/portada.png',
        'theme_key': 'esmeralda',
        'brand_color': null,
        'city': 'Bogotá',
        'address': 'Calle 100 #10-20',
        'whatsapp': '+573001234567',
        'contact_phone': '+576011234567',
        'instagram': '@naguaradeunas',
        'facebook': 'NaguaraDeUnas',
      });

      expect(profile.tenantId, 'tenant-1');
      expect(profile.name, 'Naguara de Uñas');
      expect(profile.slug, 'naguara-de-unas');
      expect(profile.businessType, 'Salón de uñas');
      expect(profile.logoUrl, 'https://ejemplo.com/logo.png');
      expect(profile.coverPhotoUrl, 'https://ejemplo.com/portada.png');
      expect(profile.themeKey, 'esmeralda');
      expect(profile.brandColor, isNull);
      expect(profile.city, 'Bogotá');
      expect(profile.address, 'Calle 100 #10-20');
      expect(profile.whatsapp, '+573001234567');
      expect(profile.contactPhone, '+576011234567');
      expect(profile.instagram, '@naguaradeunas');
      expect(profile.facebook, 'NaguaraDeUnas');
    });

    test('name cae en "Este negocio" si la RPC no trae nombre', () {
      final profile = PublicSalonProfile.fromMap({
        'tenant_id': 'tenant-1',
        'slug': 'algun-slug',
      });

      expect(profile.name, 'Este negocio');
    });

    test('locationLine combina ciudad y dirección con " · ", omitiendo lo vacío', () {
      final conAmbos = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'city': 'Bogotá',
        'address': 'Calle 1',
      });
      expect(conAmbos.locationLine, 'Bogotá · Calle 1');

      final soloCiudad = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'city': 'Bogotá',
      });
      expect(soloCiudad.locationLine, 'Bogotá');

      final ninguno = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(ninguno.locationLine, '');
    });

    test('instagramHandle quita el "@" del hint de Configuración', () {
      final conArroba = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'instagram': '@naguaradeunas',
      });
      expect(conArroba.instagramHandle, 'naguaradeunas');
      expect(conArroba.instagramUri.toString(), 'https://instagram.com/naguaradeunas');

      final sinArroba = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'instagram': 'naguaradeunas',
      });
      expect(sinArroba.instagramHandle, 'naguaradeunas');

      final vacio = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(vacio.instagramHandle, isNull);
      expect(vacio.instagramUri, isNull);
    });

    test('facebookUri respeta una URL completa y arma una a partir de un handle', () {
      final urlCompleta = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'facebook': 'https://facebook.com/paginaReal',
      });
      expect(urlCompleta.facebookUri.toString(), 'https://facebook.com/paginaReal');

      final soloHandle = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'facebook': 'NaguaraDeUnas',
      });
      expect(soloHandle.facebookUri.toString(), 'https://facebook.com/NaguaraDeUnas');

      final vacio = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(vacio.facebookUri, isNull);
    });

    test('primaryBranchId y businessHours llegan de la RPC (D-165)', () {
      final conHorario = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
        'primary_branch_id': 'branch-1',
        'business_hours': [
          {
            'day_of_week': 1,
            'opens_at': '09:00:00',
            'closes_at': '18:00:00',
            'is_open': true,
          },
          {
            'day_of_week': 7,
            'opens_at': null,
            'closes_at': null,
            'is_open': false,
          },
        ],
      });

      expect(conHorario.primaryBranchId, 'branch-1');
      expect(conHorario.businessHours.length, 2);
      expect(conHorario.businessHours[0].dayName, 'Lunes');
      expect(conHorario.businessHours[0].scheduleText, '09:00 - 18:00');
      expect(conHorario.businessHours[1].dayName, 'Domingo');
      expect(conHorario.businessHours[1].scheduleText, 'Cerrado');

      final sinNada = PublicSalonProfile.fromMap({
        'tenant_id': 't',
        'name': 'X',
        'slug': 'x',
      });
      expect(sinNada.primaryBranchId, isNull);
      expect(sinNada.businessHours, isEmpty);
    });
  });

  group('PublicSalonServiceItem (D-165)', () {
    test('fromMap mapea nombre, "description" (category), duración y precio', () {
      final service = PublicSalonServiceItem.fromMap({
        'id': 'svc-1',
        'name': 'Corte Publico',
        'description': 'Cortes',
        'duration_minutes': 45,
        'price_cop': 35000,
      });

      expect(service.id, 'svc-1');
      expect(service.name, 'Corte Publico');
      expect(service.description, 'Cortes');
      expect(service.durationMinutes, 45);
      expect(service.priceCop, 35000);
      expect(service.durationLabel, '45 min');
      expect(service.priceLabel, '\$35.000');
    });
  });

  group('PublicSalonPhotoItem (D-165)', () {
    test('fromMap mapea todos los campos', () {
      final photo = PublicSalonPhotoItem.fromMap({
        'id': 'photo-1',
        'photo_url': 'https://ejemplo.com/foto.jpg',
        'photo_type': 'despues',
        'caption': 'Resultado final',
        'created_at': '2026-08-20T10:00:00Z',
      });

      expect(photo.id, 'photo-1');
      expect(photo.photoUrl, 'https://ejemplo.com/foto.jpg');
      expect(photo.photoType, 'despues');
      expect(photo.caption, 'Resultado final');
      expect(photo.createdAt, isNotNull);
    });
  });

  group('PublicSalonTeamMember (D-165)', () {
    test('fromMap mapea nombre, foto y bio (sin color_code: no existe en stylists)', () {
      final member = PublicSalonTeamMember.fromMap({
        'id': 'st-1',
        'name': 'Estilista Uno',
        'photo_url': 'https://ejemplo.com/perfil.jpg',
        'bio': 'Especialista en color',
      });

      expect(member.id, 'st-1');
      expect(member.name, 'Estilista Uno');
      expect(member.photoUrl, 'https://ejemplo.com/perfil.jpg');
      expect(member.bio, 'Especialista en color');
    });
  });

  group('PublicSalonReviewsSummary (D-165)', () {
    test('fromRows lee el promedio/total repetido y arma la lista de reseñas', () {
      final summary = PublicSalonReviewsSummary.fromRows([
        {
          'avg_rating': 4.5,
          'total_reviews': 2,
          'client_name': 'Clienta A',
          'rating': 5,
          'comment': 'Excelente',
          'created_at': '2026-08-20T10:00:00Z',
        },
        {
          'avg_rating': 4.5,
          'total_reviews': 2,
          'client_name': 'Clienta B',
          'rating': 4,
          'comment': null,
          'created_at': '2026-08-19T10:00:00Z',
        },
      ]);

      expect(summary.avgRating, 4.5);
      expect(summary.totalReviews, 2);
      expect(summary.reviews.length, 2);
      expect(summary.reviews[0].clientName, 'Clienta A');
      expect(summary.reviews[0].rating, 5);
      expect(summary.reviews[1].comment, isNull);
    });

    test('fromRows con lista vacía cae en el resumen vacío (D-165)', () {
      final summary = PublicSalonReviewsSummary.fromRows([]);

      expect(summary.avgRating, 0);
      expect(summary.totalReviews, 0);
      expect(summary.reviews, isEmpty);
      expect(summary, same(PublicSalonReviewsSummary.empty));
    });

    test('fromRows lee la respuesta del negocio cuando existe (D-170)', () {
      final summary = PublicSalonReviewsSummary.fromRows([
        {
          'avg_rating': 5.0,
          'total_reviews': 1,
          'client_name': 'Clienta A',
          'rating': 5,
          'comment': 'Excelente',
          'business_reply': '¡Gracias, Clienta A!',
          'created_at': '2026-08-20T10:00:00Z',
        },
      ]);

      expect(summary.reviews[0].businessReply, '¡Gracias, Clienta A!');
    });

    test('fromRows sin respuesta del negocio deja businessReply en null (D-170)', () {
      final summary = PublicSalonReviewsSummary.fromRows([
        {
          'avg_rating': 5.0,
          'total_reviews': 1,
          'client_name': 'Clienta A',
          'rating': 5,
          'comment': 'Excelente',
          'created_at': '2026-08-20T10:00:00Z',
        },
      ]);

      expect(summary.reviews[0].businessReply, isNull);
    });
  });
}
