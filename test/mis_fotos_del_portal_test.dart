import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_consent.dart';
import 'package:salonymas/models/client_portal_data.dart';
import 'package:salonymas/services/client_consent_service.dart';
import 'package:salonymas/widgets/mis_fotos_del_portal.dart';
import 'package:salonymas/widgets/photo_grid_viewer.dart';

/// AU (D-286): "Mis fotos de trabajos" muestra también las fotos privadas
/// que el salón le marcó como visibles, cada una con su etiqueta. Lo que se
/// vigila: que a una privada se le pida la URL temporal (y a una publicada
/// no), que la etiqueta diga la verdad, y que retirar una foto del
/// portafolio cambie su etiqueta sin tener que salir del portal.
class _ServicioFalso extends ClientConsentService {
  final pedidas = <String>[];

  @override
  Future<String?> urlTemporal(String id, ClientConsentCredential c) async {
    pedidas.add(id);
    return 'https://ejemplo.com/firmada/$id.jpg';
  }
}

const _publicada = ClientPortalPhoto(
  id: 'pub',
  photoUrl: 'https://ejemplo.com/object/public/work-photos/pub.jpg',
  inPortfolio: true,
);
const _privada = ClientPortalPhoto(id: 'priv');

Future<void> _montar(
  WidgetTester tester,
  _ServicioFalso servicio,
  List<ClientPortalPhoto> fotos,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MisFotosDelPortal(
            fotos: fotos,
            credencial: const ClientConsentCredential.portal('tok'),
            service: servicio,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ClientPortalPhoto (D-286)', () {
    test('una privada llega sin direccion y sin marca de publicada', () {
      final foto = ClientPortalPhoto.fromMap({
        'id': 'p1',
        'photo_url': null,
        'in_portfolio': false,
      });
      expect(foto.photoUrl, isNull);
      expect(foto.inPortfolio, isFalse);
    });

    test('una publicada trae su direccion y la marca', () {
      final foto = ClientPortalPhoto.fromMap({
        'id': 'p2',
        'photo_url': 'https://ejemplo.com/a.jpg',
        'in_portfolio': true,
      });
      expect(foto.photoUrl, 'https://ejemplo.com/a.jpg');
      expect(foto.inPortfolio, isTrue);
    });
  });

  group('MisFotosDelPortal (D-286, AU)', () {
    testWidgets('sin fotos lo dice, sin prometer "publicadas"', (tester) async {
      await _montar(tester, _ServicioFalso(), const []);
      expect(find.text(MisFotosDelPortal.sinFotos), findsOneWidget);
      expect(find.textContaining('publicadas'), findsNothing);
    });

    testWidgets('pide URL temporal solo para la privada', (tester) async {
      final servicio = _ServicioFalso();
      await _montar(tester, servicio, const [_publicada, _privada]);
      expect(servicio.pedidas, ['priv']);
    });

    testWidgets('cada foto lleva la etiqueta que le corresponde', (tester) async {
      await _montar(tester, _ServicioFalso(), const [_publicada, _privada]);
      expect(find.text(MisFotosDelPortal.etiquetaPublicada), findsOneWidget);
      expect(find.text(MisFotosDelPortal.etiquetaSoloParaTi), findsOneWidget);
    });

    testWidgets('al retirarla del portafolio, la etiqueta cambia sin salir',
        (tester) async {
      final servicio = _ServicioFalso();
      await _montar(tester, servicio, const [_publicada]);
      expect(find.text(MisFotosDelPortal.etiquetaPublicada), findsOneWidget);

      // La misma foto, como llega después de que ella la retira.
      await _montar(tester, servicio, const [ClientPortalPhoto(id: 'pub')]);
      expect(find.text(MisFotosDelPortal.etiquetaPublicada), findsNothing);
      expect(find.text(MisFotosDelPortal.etiquetaSoloParaTi), findsOneWidget);
      expect(servicio.pedidas, ['pub']);
    });
  });

  group('PhotoGridViewer sin etiquetas (portafolio publico)', () {
    testWidgets('no pinta ninguna etiqueta: se ve igual que antes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhotoGridViewer(
              photos: [(url: 'https://ejemplo.com/a.jpg', caption: null)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(MisFotosDelPortal.etiquetaPublicada), findsNothing);
      expect(find.text(MisFotosDelPortal.etiquetaSoloParaTi), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });
  });
}
