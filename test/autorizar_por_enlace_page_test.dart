import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/client_consent.dart';
import 'package:salonymas/models/public_salon_profile.dart';
import 'package:salonymas/pages/autorizar_por_enlace_page.dart';
import 'package:salonymas/services/client_consent_service.dart';
import 'package:salonymas/services/public_salon_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Paso 9.48, Bloque 3 (D-287): la página del enlace directo. Lo que se
/// vigila son las tres decisiones del propietario del 28-sep: los colores
/// del salón (se piden con su slug), el enlace inválido sin "Reintentar", y
/// el botón a la página del salón al final.
class _ServicioFalso extends ClientConsentService {
  _ServicioFalso({this.datos, this.error});

  final ClientConsentOverview? datos;
  final Object? error;
  final credenciales = <ClientConsentCredential>[];

  @override
  Future<ClientConsentOverview> getOverview(ClientConsentCredential c) async {
    credenciales.add(c);
    if (error != null) throw error!;
    return datos!;
  }

  @override
  Future<String?> photoViewUrl(ConsentPhoto f, ClientConsentCredential c) async =>
      null;
}

class _SalonFalso extends PublicSalonService {
  final pedidos = <String>[];

  @override
  Future<PublicSalonProfile?> getSalonBySlug(String slug) async {
    pedidos.add(slug);
    return null;
  }
}

ClientConsentOverview _datos({String? slug = 'peluqueria-exito-prueba'}) {
  return ClientConsentOverview(
    clientName: 'Juan Carlos Rodriguez',
    businessName: 'Peluquería Éxito Prueba',
    businessWhatsapp: '3001234567',
    businessSlug: slug,
    pendingPhotos: const [],
    answeredPhotos: const [],
    pendingReviews: const [],
    answeredReviews: const [],
  );
}

Future<void> _montar(
  WidgetTester tester,
  _ServicioFalso servicio, [
  _SalonFalso? salon,
]) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AutorizarPorEnlacePage(
        token: 'tok-enlace',
        service: servicio,
        salonService: salon ?? _SalonFalso(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('el slug del salon llega desde la base (D-287)', () {
    final datos = ClientConsentOverview.fromMap({
      'client_name': 'Ana',
      'business_slug': 'naguaradeunas',
    });
    expect(datos.businessSlug, 'naguaradeunas');
    expect(ClientConsentOverview.fromMap({'client_name': 'Ana'}).businessSlug,
        isNull);
  });

  testWidgets('entra con SU enlace, no con un portal', (tester) async {
    final servicio = _ServicioFalso(datos: _datos());
    await _montar(tester, servicio);
    expect(servicio.credenciales, isNotEmpty);
    expect(servicio.credenciales.first.consentToken, 'tok-enlace');
    expect(servicio.credenciales.first.portalToken, isNull);
  });

  testWidgets('saluda y pide los colores del salon con su slug',
      (tester) async {
    final salon = _SalonFalso();
    await _montar(tester, _ServicioFalso(datos: _datos()), salon);
    expect(find.text('Hola, Juan 👋'), findsOneWidget);
    expect(find.text('Peluquería Éxito Prueba'), findsWidgets);
    expect(salon.pedidos, ['peluqueria-exito-prueba']);
  });

  testWidgets('ofrece ir a la pagina del salon', (tester) async {
    await _montar(tester, _ServicioFalso(datos: _datos()));
    expect(
      find.text(AutorizarPorEnlacePage.botonSalon('Peluquería Éxito Prueba')),
      findsOneWidget,
    );
  });

  testWidgets('sin slug no hay boton ni se piden colores', (tester) async {
    final salon = _SalonFalso();
    await _montar(tester, _ServicioFalso(datos: _datos(slug: null)), salon);
    expect(find.textContaining('Ver la página de'), findsNothing);
    expect(salon.pedidos, isEmpty);
  });

  testWidgets('un enlace invalido lo dice, sin "Reintentar"', (tester) async {
    await _montar(
      tester,
      _ServicioFalso(
        error: const PostgrestException(message: 'Este enlace no es válido.'),
      ),
    );
    expect(find.text(AutorizarPorEnlacePage.enlaceInvalido), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('sin conexion si ofrece reintentar', (tester) async {
    await _montar(tester, _ServicioFalso(error: Exception('sin red')));
    expect(find.text(AutorizarPorEnlacePage.sinConexion), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
