import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_consent.dart';
import 'package:salonymas/models/review_reply_draft.dart';
import 'package:salonymas/models/review_summary.dart';
import 'package:salonymas/services/client_consent_service.dart';
import 'package:salonymas/widgets/autorizaciones_de_la_clienta.dart';

/// Paso 9.48, Bloque 2 (D-282): la clienta decide sobre sus fotos y su
/// nombre, y puede arrepentirse. Lo que se vigila aquí es lo que cambia lo
/// que ve el público: que un "no" a una foto publicada vaya por el camino
/// que la saca de internet, que el nombre elegido se respete, y que el
/// salón no lo revele por la puerta de atrás de su respuesta.
class _ServicioFalso extends ClientConsentService {
  _ServicioFalso(this.datos);

  ClientConsentOverview datos;
  final llamadas = <String>[];

  @override
  Future<ClientConsentOverview> getOverview(ClientConsentCredential c) async =>
      datos;

  @override
  Future<String?> photoViewUrl(ConsentPhoto f, ClientConsentCredential c) async =>
      null;

  @override
  Future<void> setPhoto(String id, bool autoriza, ClientConsentCredential c) async =>
      llamadas.add('setPhoto:$id:$autoriza');

  @override
  Future<void> revokePublishedPhoto(String id, ClientConsentCredential c) async =>
      llamadas.add('revoke:$id');

  @override
  Future<void> setReviewName(
    String id,
    bool nombreReal,
    ClientConsentCredential c,
  ) async =>
      llamadas.add('setReviewName:$id:$nombreReal');

  @override
  Future<void> setReviewAlias(
    String id,
    String alias,
    ClientConsentCredential c,
  ) async =>
      llamadas.add('setReviewAlias:$id:$alias');
}

ClientConsentOverview _datos({
  List<ConsentPhoto> pendientes = const [],
  List<ConsentPhoto> respondidas = const [],
  List<ConsentReview> resenasPendientes = const [],
  List<ConsentReview> resenasRespondidas = const [],
}) {
  return ClientConsentOverview(
    clientName: 'Ana Gómez',
    businessName: 'Naguara de Uñas',
    businessWhatsapp: '3001234567',
    pendingPhotos: pendientes,
    answeredPhotos: respondidas,
    pendingReviews: resenasPendientes,
    answeredReviews: resenasRespondidas,
  );
}

Future<void> _montar(WidgetTester tester, _ServicioFalso servicio) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AutorizacionesDeLaClienta(
            credencial: const ClientConsentCredential.enlace('tok'),
            nombreSalon: 'Respaldo',
            service: servicio,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('D-282 — Lo que llega de la base', () {
    test('separa pendientes de respondidas y trae los datos del salón', () {
      final datos = ClientConsentOverview.fromMap({
        'client_name': 'Ana',
        'business_name': 'Naguara',
        'business_whatsapp': '300',
        'pending_photos': [
          {'id': 'f1', 'is_published': false, 'photo_url': null},
        ],
        'answered_photos': [
          {
            'id': 'f2',
            'authorized': true,
            'is_published': true,
            'photo_url': 'https://x/object/public/work-photos/a.jpg',
          },
        ],
        'pending_reviews': [
          {'id': 'r1', 'rating': 5, 'comment': 'Bien'},
        ],
        'answered_reviews': [],
      });

      expect(datos.businessName, 'Naguara');
      expect(datos.pendientes, 2);
      expect(datos.pendingPhotos.single.authorized, isNull,
          reason: 'Una foto pendiente no tiene respuesta: null, no false.');
      expect(datos.answeredPhotos.single.authorized, isTrue);
      expect(datos.answeredPhotos.single.isPublished, isTrue);
      expect(datos.pendingReviews.single.choice, isNull);
    });

    test('la forma de aparecer en la reseña sale de sus dos columnas', () {
      ConsentReview resena(bool? consiente, String? alias, [String? estado]) =>
          ConsentReview.fromMap({
            'id': 'r',
            'rating': 4,
            'name_consent': ?consiente,
            'display_name': alias,
            'moderation_status': estado,
          });

      expect(resena(null, null).choice, isNull);
      expect(resena(false, null).choice, ReviewNameChoice.verificada);
      expect(resena(true, null).choice, ReviewNameChoice.nombreReal);
      expect(resena(true, 'Caro').choice, ReviewNameChoice.nombrePropio);
      expect(resena(true, 'Caro', 'pending').esperaRevision, isTrue);
      expect(resena(true, null, 'pending').esperaRevision, isFalse,
          reason: 'Solo un nombre escrito por ella espera revisión.');
    });

    test('la credencial manda uno de los dos tokens, nunca los dos', () {
      const portal = ClientConsentCredential.portal('p');
      const enlace = ClientConsentCredential.enlace('e');
      expect(portal.rpcParams, {'p_portal_token': 'p', 'p_consent_token': null});
      expect(enlace.edgeParams, {'consentToken': 'e'});
    });
  });

  group('D-282 — Reglas que también vigila la base', () {
    test('el nombre propio va de 2 a 40 letras, igual que el candado', () {
      expect(AutorizacionesDeLaClienta.validarNombrePropio(' A '), isNotNull);
      expect(AutorizacionesDeLaClienta.validarNombrePropio('Caro'), isNull);
      expect(AutorizacionesDeLaClienta.validarNombrePropio('x' * 41), isNotNull);
    });

    test('el nombre público respeta lo que ella eligió', () {
      String publico(ReviewNameChoice? c, [String? alias]) =>
          AutorizacionesDeLaClienta.nombrePublico(
            ConsentReview(id: 'r', rating: 5, choice: c, displayName: alias),
            'Ana Gómez',
          );
      expect(publico(null), 'Clienta verificada');
      expect(publico(ReviewNameChoice.verificada), 'Clienta verificada');
      expect(publico(ReviewNameChoice.nombreReal), 'Ana Gómez');
      expect(publico(ReviewNameChoice.nombrePropio, 'Caro'), 'Caro');
    });
  });

  group('D-282 — El salón no revela el nombre por la puerta de atrás', () {
    test('el borrador de respuesta no saluda a una «Clienta verificada»', () {
      final borrador = ReviewReplyDraftBuilder.generar(
        rating: 5,
        clientName: 'Clienta verificada',
        serviceName: 'Manicure',
        businessName: 'Naguara',
      );
      expect(borrador, startsWith('¡Muchas gracias!'),
          reason: 'La respuesta se publica bajo la reseña: si ella eligió no '
              'mostrar su nombre, el borrador no puede ponerlo.');
      expect(borrador, isNot(contains('Clienta')));
    });

    test('ReviewSummary trae el nombre público, y sin él asume el genérico',
        () {
      Map<String, dynamic> fila([String? publico]) => {
            'id': 'r1',
            'client_name': 'Ana Gómez',
            'rating': 5,
            'created_at': '2026-09-26T10:00:00Z',
            'public_name': ?publico,
          };
      expect(ReviewSummary.fromMap(fila('Caro')).publicName, 'Caro');
      expect(ReviewSummary.fromMap(fila()).publicName, 'Clienta verificada',
          reason: 'Si falta el dato, el valor seguro es no revelar el nombre.');
    });
  });

  group('D-282 — La pantalla', () {
    testWidgets('sin nada que decidir y en modo portal, no ocupa sitio',
        (tester) async {
      final servicio = _ServicioFalso(_datos());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutorizacionesDeLaClienta(
              credencial: const ClientConsentCredential.portal('tok'),
              nombreSalon: 'Naguara',
              ocultarSiNoHayNada: true,
              service: servicio,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('pregunta con el texto aprobado y guarda el «sí»',
        (tester) async {
      final servicio = _ServicioFalso(
        _datos(pendientes: [const ConsentPhoto(id: 'f1', isPublished: false)]),
      );
      await _montar(tester, servicio);

      expect(
        find.text(AutorizacionesDeLaClienta.preguntaDeFoto('Naguara de Uñas')),
        findsOneWidget,
        reason: 'El nombre del salón sale de la base, no del respaldo.',
      );
      // La foto es cuadrada y ocupa el ancho: se baja hasta el botón, como
      // lo haría ella en el teléfono.
      await tester.ensureVisible(find.text('Sí, autorizo'));
      await tester.tap(find.text('Sí, autorizo'));
      await tester.pumpAndSettle();
      expect(servicio.llamadas, ['setPhoto:f1:true']);
    });

    testWidgets(
        'un «no» a una foto YA publicada la retira por el camino que la saca '
        'de internet, y avisa lo de las redes', (tester) async {
      final servicio = _ServicioFalso(
        _datos(
          respondidas: [
            const ConsentPhoto(
              id: 'f2',
              authorized: true,
              isPublished: true,
              photoUrl: 'https://x/a.jpg',
            ),
          ],
        ),
      );
      await _montar(tester, servicio);

      await tester.tap(find.text('Retirar autorización'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, retirarla'));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, ['revoke:f2'],
          reason: 'Nunca setPhoto(false) sobre una foto publicada: la base '
              'la rechaza porque el archivo seguiría en internet.');
      expect(find.textContaining('esa publicación la tiene que borrar el salón'),
          findsOneWidget);
      expect(find.text('Avisar al salón por WhatsApp'), findsOneWidget);
    });

    testWidgets('retirar una foto autorizada pero NO publicada es solo cambiar '
        'la respuesta', (tester) async {
      final servicio = _ServicioFalso(
        _datos(
          respondidas: [
            const ConsentPhoto(id: 'f3', authorized: true, isPublished: false),
          ],
        ),
      );
      await _montar(tester, servicio);

      await tester.tap(find.text('Retirar autorización'));
      await tester.pumpAndSettle();
      expect(servicio.llamadas, ['setPhoto:f3:false']);
    });

    testWidgets('el nombre propio se valida y se guarda', (tester) async {
      final servicio = _ServicioFalso(
        _datos(
          resenasPendientes: [
            const ConsentReview(id: 'r1', rating: 5, comment: 'Divino'),
          ],
        ),
      );
      await _montar(tester, servicio);

      await tester.tap(find.text('Elegir cómo aparezco'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Con otro nombre, que escribo yo'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe al menos 2 letras.'), findsOneWidget);
      expect(servicio.llamadas, isEmpty);

      await tester.enterText(find.byType(TextField), '  Caro de Chapinero ');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(servicio.llamadas, ['setReviewAlias:r1:Caro de Chapinero']);
    });

    testWidgets('elegir «Clienta verificada» manda el nombre real en falso',
        (tester) async {
      final servicio = _ServicioFalso(
        _datos(
          resenasRespondidas: [
            const ConsentReview(
              id: 'r2',
              rating: 4,
              choice: ReviewNameChoice.nombreReal,
            ),
          ],
        ),
      );
      await _montar(tester, servicio);

      expect(find.text('Apareces como: Ana Gómez'), findsOneWidget);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Como «Clienta verificada»'));
      await tester.pumpAndSettle();
      expect(servicio.llamadas, ['setReviewName:r2:false']);
    });
  });
}
