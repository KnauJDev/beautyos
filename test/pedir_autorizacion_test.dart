import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_consent.dart';
import 'package:salonymas/models/work_photo_summary.dart';
import 'package:salonymas/services/client_consent_service.dart';
import 'package:salonymas/widgets/pedir_autorizacion.dart';

/// Paso 9.48, Bloque 4 (D-288): el permiso de publicar solo lo da ella, y el
/// salón se lo pide por WhatsApp con su enlace. Lo que se vigila: el mensaje
/// exacto que decidió el propietario, que el botón de la galería salga solo
/// en las fotos que ella nunca ha respondido, y que el asistente no vea la
/// oferta al subir una foto.
class _ServicioFalso extends ClientConsentService {
  _ServicioFalso(this.datos);

  final ClientConsentWhatsapp datos;
  final pedidos = <String>[];

  @override
  Future<ClientConsentWhatsapp> whatsappData(String clientId) async {
    pedidos.add(clientId);
    return datos;
  }
}

WorkPhotoSummary _foto({
  String? clientId = 'cli-1',
  bool consent = false,
  String? decidio,
}) {
  return WorkPhotoSummary.fromMap({
    'id': 'f1',
    'ticket_id': 't1',
    'client_id': clientId,
    'client_name': 'Juan',
    'stylist_name': 'Erick',
    'photo_url': null,
    'storage_bucket': 'work-photos-private',
    'storage_path': 'b/f1.jpg',
    'photo_type': 'after',
    'caption': null,
    'ai_status': 'not_required',
    'visible_to_customer': true,
    'approved_for_portfolio': false,
    'client_consent': consent,
    'client_consent_at': null,
    'client_consent_decided_at': decidio,
    'created_at': '2026-09-28T10:00:00Z',
  });
}

void main() {
  group('El mensaje (decidido por el propietario el 28-sep)', () {
    test('saluda por el primer nombre y lleva el enlace', () {
      final texto = PedirAutorizacion.mensaje(
        nombre: 'Juan Carlos Rodriguez',
        salon: 'Peluquería Éxito Prueba',
        enlace: 'https://salonymas.com/?autorizar=abc',
      );
      expect(
        texto,
        'Hola Juan, en Peluquería Éxito Prueba nos encantó cómo quedó tu '
        'servicio. Aquí puedes decidir si nos autorizas a mostrar tus fotos y '
        'tu reseña: https://salonymas.com/?autorizar=abc. Tú decides y puedes '
        'cambiarlo cuando quieras.',
      );
    });

    test('el enlace es el de la pagina del Bloque 3', () {
      expect(
        PedirAutorizacion.enlace('abc', origen: 'https://salonymas.com'),
        'https://salonymas.com/?autorizar=abc',
      );
    });
  });

  group('Galeria: "Pedir autorizacion" solo donde toca', () {
    test('foto sin respuesta y sin permiso: si', () {
      expect(_foto().puedePedirAutorizacion, isTrue);
    });

    test('si ella ya dijo que no, no se le insiste', () {
      expect(
        _foto(decidio: '2026-09-27T21:04:00Z').puedePedirAutorizacion,
        isFalse,
      );
    });

    test('con permiso (de ella o de la casilla vieja): no', () {
      expect(_foto(consent: true).puedePedirAutorizacion, isFalse);
      expect(
        _foto(consent: true, decidio: '2026-09-27T17:13:00Z')
            .puedePedirAutorizacion,
        isFalse,
      );
    });

    test('sin clienta asociada: no', () {
      expect(_foto(clientId: null).puedePedirAutorizacion, isFalse);
    });

    test('la fecha en que ella respondio llega de la base', () {
      expect(
        _foto(decidio: '2026-09-27T21:04:00Z').clientConsentDecidedAt,
        isNotNull,
      );
    });
  });

  testWidgets('sin celular: copia el mensaje y lo dice', (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado = (llamada.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    final servicio = _ServicioFalso(
      const ClientConsentWhatsapp(
        token: 'tok',
        clientName: 'Ana Gómez',
        businessName: 'Naguara de Uñas',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotonPedirAutorizacion(clientId: 'cli-9', service: servicio),
        ),
      ),
    );
    await tester.tap(find.text(PedirAutorizacion.textoBoton));
    await tester.pumpAndSettle();

    expect(servicio.pedidos, ['cli-9']);
    expect(copiado, contains('?autorizar=tok'));
    expect(copiado, startsWith('Hola Ana, en Naguara de Uñas'));
    expect(find.textContaining('no tiene celular'), findsOneWidget);
  });

  test('al subir la foto, solo dueno o admin ven la oferta', () {
    final codigo = File('lib/pages/tickets_page.dart').readAsStringSync();
    expect(
      codigo,
      contains('if (widget.isOwnerOrAdmin && clientId != null) {'),
      reason: 'al asistente la base le niega el enlace: no se le ofrece',
    );
    final agenda =
        File('lib/pages/my_stylist_agenda_page.dart').readAsStringSync();
    expect(
      agenda,
      isNot(contains('ofrecerPedirAutorizacion')),
      reason: 'decision del propietario: el estilista no manda el enlace',
    );
  });
}
