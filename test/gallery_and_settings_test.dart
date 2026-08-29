import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/sale_numbering.dart';
import 'package:salonymas/models/work_photo_summary.dart';

void main() {
  group('Galería de Fotos de Trabajo (Paso 4.9 / D-156)', () {
    test('WorkPhotoSummary mapea ticketCode, ticketNumber, clientId y stylistId desde RPC', () {
      final map = {
        'id': 'wp-100',
        'ticket_id': 'tk-701',
        'ticket_number': 701,
        'ticket_code': '#0000701',
        'client_id': 'cli-55',
        'client_name': 'Camila Restrepo',
        'stylist_id': 'sty-12',
        'stylist_name': 'Valentina Gómez',
        'photo_url': 'https://storage.beautyos.com/photos/final.jpg',
        'storage_bucket': 'work-photos',
        'storage_path': 'branches/b1/final.jpg',
        'photo_type': 'after',
        'caption': 'Balayage dorado y peinado con ondas',
        'ai_status': 'processed',
        'visible_to_customer': true,
        'approved_for_portfolio': true,
        'created_at': '2026-08-18T14:30:00Z',
      };

      final photo = WorkPhotoSummary.fromMap(map);

      expect(photo.id, 'wp-100');
      expect(photo.ticketId, 'tk-701');
      expect(photo.ticketNumber, 701);
      expect(photo.ticketCode, '#0000701');
      expect(photo.clientId, 'cli-55');
      expect(photo.clientName, 'Camila Restrepo');
      expect(photo.stylistId, 'sty-12');
      expect(photo.stylistName, 'Valentina Gómez');
      expect(photo.photoTypeText, 'Después');
      expect(photo.estaPublicada, isTrue);
      expect(photo.captionText, 'Balayage dorado y peinado con ondas');
    });

    test('WorkPhotoSummary formatea ticketCode automáticamente si viene solo ticket_number numérico', () {
      final map = {
        'id': 'wp-101',
        'ticket_id': 'tk-702',
        'ticket_number': 45,
        'ticket_code': null,
        'client_name': 'Mariana Morales',
        'stylist_name': 'Sofía Pérez',
        'photo_url': null,
        'photo_type': 'before',
        'caption': null,
        'ai_status': 'not_required',
        'visible_to_customer': false,
        'approved_for_portfolio': false,
        'created_at': '2026-08-18T10:00:00Z',
      };

      final photo = WorkPhotoSummary.fromMap(map);

      expect(photo.ticketNumber, 45);
      expect(photo.ticketCode, '#0000045');
      expect(photo.photoTypeText, 'Antes');
      expect(photo.estaPublicada, isFalse);
      expect(photo.captionText, 'Sin descripción');
    });

    test('WorkPhotoSummary maneja fotos sin ticket asociado con elegancia', () {
      final map = {
        'id': 'wp-102',
        'ticket_id': null,
        'photo_type': 'portfolio',
        'ai_status': 'pending',
        'visible_to_customer': true,
        'approved_for_portfolio': false,
        'created_at': '2026-08-18T11:00:00Z',
      };

      final photo = WorkPhotoSummary.fromMap(map);

      expect(photo.ticketId, isNull);
      expect(photo.ticketNumber, isNull);
      expect(photo.ticketCode, isNull);
      expect(photo.clientName, 'Cliente no asociado');
      expect(photo.stylistName, 'Estilista no asociado');
      expect(photo.photoTypeText, 'Portafolio');
      expect(photo.aiStatusText, 'IA pendiente');
    });

    test('WorkPhotoSummary mapea client_consent y client_consent_at (D-167)', () {
      final conConsentimiento = WorkPhotoSummary.fromMap({
        'id': 'wp-103',
        'ticket_id': 'tk-703',
        'client_name': 'Laura Gómez',
        'stylist_name': 'Sofía Pérez',
        'photo_url': null,
        'photo_type': 'after',
        'ai_status': 'not_required',
        'visible_to_customer': false,
        'approved_for_portfolio': false,
        'client_consent': true,
        'client_consent_at': '2026-08-29T09:00:00Z',
        'created_at': '2026-08-29T09:00:00Z',
      });

      expect(conConsentimiento.clientConsent, isTrue);
      expect(conConsentimiento.clientConsentAt, isNotNull);

      final sinConsentimiento = WorkPhotoSummary.fromMap({
        'id': 'wp-104',
        'ticket_id': 'tk-704',
        'client_name': 'Laura Gómez',
        'stylist_name': 'Sofía Pérez',
        'photo_url': null,
        'photo_type': 'after',
        'ai_status': 'not_required',
        'visible_to_customer': false,
        'approved_for_portfolio': false,
        'client_consent': false,
        'client_consent_at': null,
        'created_at': '2026-08-29T09:00:00Z',
      });

      expect(sinConsentimiento.clientConsent, isFalse);
      expect(sinConsentimiento.clientConsentAt, isNull);
    });
  });

  group('Numeración de Ventas y DIAN (Paso 4.9 / D-156)', () {
    test('BranchSaleNumbering genera previewNextCode con padding configurable', () {
      final numbering7 = BranchSaleNumbering(
        tenantId: 't-1',
        branchId: 'b-1',
        prefix: 'VTA-',
        nextNumber: 15,
        padding: 7,
        updatedAt: DateTime.now(),
      );
      expect(numbering7.previewNextCode, 'VTA-0000015');

      final numberingCustom = BranchSaleNumbering(
        tenantId: 't-1',
        branchId: 'b-1',
        prefix: 'POS-',
        nextNumber: 250,
        padding: 6,
        updatedAt: DateTime.now(),
      );
      expect(numberingCustom.previewNextCode, 'POS-000250');
    });

    test('BranchSaleNumbering detecta resolución DIAN y alertas de rango', () {
      final withResolution = BranchSaleNumbering(
        tenantId: 't-1',
        branchId: 'b-1',
        prefix: 'FAC-',
        nextNumber: 950,
        padding: 6,
        resolutionNumber: '18764000001234',
        resolutionDate: DateTime(2026, 1, 1),
        rangeFrom: 1,
        rangeTo: 1000,
        validUntil: DateTime(2027, 1, 1),
        lastEmittedNumber: 949,
        updatedAt: DateTime.now(),
      );

      expect(withResolution.hasResolution, isTrue);
      expect(withResolution.isNearLimit, isTrue); // 1000 - 950 = 50 <= 100
      expect(withResolution.previewNextCode, 'FAC-000950');
    });
  });
}
