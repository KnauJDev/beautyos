import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_portal_data.dart';

void main() {
  group('ClientPortalUpcomingAppointment (D-167)', () {
    test('fromMap mapea todos los campos', () {
      final cita = ClientPortalUpcomingAppointment.fromMap({
        'ticket_id': 'ticket-1',
        'ticket_code': '#0000701',
        'scheduled_at': '2026-09-10T15:30:00Z',
        'status': 'confirmado',
        'service_names': 'Corte, Color',
        'stylist_names': 'Paola Jara',
      });

      expect(cita.ticketId, 'ticket-1');
      expect(cita.ticketCode, '#0000701');
      expect(cita.scheduledAt, isNotNull);
      expect(cita.status, 'confirmado');
      expect(cita.serviceNames, 'Corte, Color');
      expect(cita.stylistNames, 'Paola Jara');
    });

    test('scheduledAtText da "Sin fecha" cuando no hay fecha', () {
      final cita = ClientPortalUpcomingAppointment.fromMap({
        'ticket_id': 'ticket-1',
        'status': 'solicitado',
      });

      expect(cita.scheduledAtText, 'Sin fecha');
    });
  });

  group('ClientPortalPastAppointment (D-167)', () {
    test('fromMap mapea already_reviewed correctamente', () {
      final resenada = ClientPortalPastAppointment.fromMap({
        'ticket_id': 'ticket-2',
        'scheduled_at': '2026-08-01T10:00:00Z',
        'status': 'cerrado',
        'service_names': 'Manicure',
        'already_reviewed': true,
      });
      expect(resenada.alreadyReviewed, true);

      final sinResenar = ClientPortalPastAppointment.fromMap({
        'ticket_id': 'ticket-3',
        'status': 'finalizado',
        'service_names': 'Pedicure',
        'already_reviewed': false,
      });
      expect(sinResenar.alreadyReviewed, false);

      final sinCampo = ClientPortalPastAppointment.fromMap({
        'ticket_id': 'ticket-4',
        'status': 'cerrado',
        'service_names': 'Corte',
      });
      expect(sinCampo.alreadyReviewed, false);
    });
  });

  group('ClientPortalPhoto (D-167)', () {
    test('fromMap mapea todos los campos', () {
      final foto = ClientPortalPhoto.fromMap({
        'id': 'photo-1',
        'photo_url': 'https://ejemplo.com/foto.jpg',
        'photo_type': 'after',
        'caption': 'Resultado',
        'created_at': '2026-08-15T12:00:00Z',
      });

      expect(foto.id, 'photo-1');
      expect(foto.photoUrl, 'https://ejemplo.com/foto.jpg');
      expect(foto.photoType, 'after');
      expect(foto.caption, 'Resultado');
      expect(foto.createdAt, isNotNull);
    });
  });

  group('ClientPortalData (D-167)', () {
    test('fromMap arma el nombre y las tres listas desde el jsonb de la RPC', () {
      final data = ClientPortalData.fromMap({
        'client_name': 'Ana Pérez',
        'upcoming_appointments': [
          {
            'ticket_id': 't1',
            'status': 'confirmado',
            'service_names': 'Corte',
            'stylist_names': 'Paola',
          },
        ],
        'past_appointments': [
          {
            'ticket_id': 't2',
            'status': 'cerrado',
            'service_names': 'Color',
            'already_reviewed': true,
          },
          {
            'ticket_id': 't3',
            'status': 'finalizado',
            'service_names': 'Manicure',
            'already_reviewed': false,
          },
        ],
        'photos': [
          {'id': 'p1', 'photo_url': 'https://ejemplo.com/1.jpg'},
        ],
      });

      expect(data.clientName, 'Ana Pérez');
      expect(data.upcomingAppointments.length, 1);
      expect(data.pastAppointments.length, 2);
      expect(data.photos.length, 1);
      expect(data.pastAppointments[0].alreadyReviewed, true);
      expect(data.pastAppointments[1].alreadyReviewed, false);
    });

    test('fromMap tolera listas ausentes y cae en listas vacías', () {
      final data = ClientPortalData.fromMap({'client_name': 'Ana'});

      expect(data.clientName, 'Ana');
      expect(data.upcomingAppointments, isEmpty);
      expect(data.pastAppointments, isEmpty);
      expect(data.photos, isEmpty);
    });

    test('client_name cae en "Clienta" si la RPC no lo trae', () {
      final data = ClientPortalData.fromMap(const {});
      expect(data.clientName, 'Clienta');
    });
  });
}
