import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/platform_tenant_summary.dart';

/// Hallazgo **AG**: el panel enseñaba un precio que **no leía del servidor,
/// sino que recalculaba aquí**.
///
/// **Qué tenía dentro aquella cuenta**, y por qué cada cosa estaba mal:
///
/// * Los precios de `basico`, `business` y `profesional` — **tres planes que
///   D-188 jubiló**. La base los marca `retired`; el único activo es `pro`.
/// * Un `isFounder → × 0.5` que es **el 50% del pionero que D-221 borró del
///   servidor**, y para el que existe el control 207.
/// * Devolvía el precio pactado **saltándose el descuento**, cuando el
///   servidor los **acumula** (control 207, comprobación 6). El panel podía
///   enseñar más de lo que se cobraba.
///
/// Es la corrección de **D-193** repetida: *"no fue actualizar las cifras:
/// fue quitarlas del cliente, porque esa cuenta vive en el servidor"*.
///
/// Lo que estas pruebas **no** cubren: que el servidor calcule bien, ni que el
/// cobro por negocio esté cerrado. Eso lo ejercita el **control 220** contra
/// la base real (D-245).
Map<String, dynamic> _negocio({
  String plan = 'pro',
  bool pionero = false,
  int? pactado,
  num? descuento,
  required int loQueDiceElServidor,
}) {
  return {
    'tenant_id': 'x',
    'tenant_name': 'Salón de prueba',
    'plan_code': plan,
    'is_founder': pionero,
    'price_cop': pactado,
    'discount_percent': descuento,
    'effective_monthly_price': loQueDiceElServidor,
  };
}

void main() {
  group('AG — el precio sale del servidor, no de una cuenta local', () {
    test('lo que se enseña es lo que el servidor dice', () {
      final t = PlatformTenantSummary.fromMap(
        _negocio(loQueDiceElServidor: 150000),
      );

      expect(t.effectivePriceCop, 150000);
      expect(t.formattedEffectivePrice, r'$150.000 COP/mes');
    });

    test('un pionero NO se lleva la mitad por su cuenta', () {
      // La trampa exacta: antes, `isFounder` disparaba un × 0.5 aquí aunque
      // D-221 lo hubiera quitado de la base. Un pionero con tarifa completa
      // habría salido a $75.000 en el panel y a $150.000 en la factura.
      final t = PlatformTenantSummary.fromMap(
        _negocio(pionero: true, loQueDiceElServidor: 150000),
      );

      expect(
        t.effectivePriceCop,
        150000,
        reason: 'el pionero es una etiqueta, no un 50% (D-221, control 207)',
      );
    });

    test('un precio pactado CON descuento no se salta el descuento', () {
      // El servidor los acumula: 50.000 pactados con un 50% cobran 25.000
      // (control 207, comprobación 6). La cuenta vieja devolvía el pactado y
      // enseñaba 50.000 — más de lo que se cobraba.
      final t = PlatformTenantSummary.fromMap(
        _negocio(pactado: 50000, descuento: 50, loQueDiceElServidor: 25000),
      );

      expect(t.effectivePriceCop, 25000);
    });

    test('un plan jubilado ya no trae su precio viejo escondido', () {
      // `profesional` está `retired` y valía 240.000. Lo que mande el
      // servidor es lo que hay, venga de donde venga ese código.
      final t = PlatformTenantSummary.fromMap(
        _negocio(plan: 'profesional', loQueDiceElServidor: 150000),
      );

      expect(
        t.effectivePriceCop,
        150000,
        reason: 'ningún precio de plan vive ya en la aplicación',
      );
    });

    test('sin respuesta del servidor no se inventa una cifra', () {
      // Cero es honesto: significa "el servidor no lo dijo". Antes, un mapa
      // sin precio devolvía 150.000 inventados y parecían reales.
      final t = PlatformTenantSummary.fromMap({
        'tenant_id': 'x',
        'tenant_name': 'Salón sin datos',
      });

      expect(t.effectivePriceCop, 0);
    });
  });

  group('AG — saber si ese número es un acuerdo o la tarifa', () {
    test('con precio pactado, es un acuerdo', () {
      final t = PlatformTenantSummary.fromMap(
        _negocio(pactado: 80000, loQueDiceElServidor: 80000),
      );
      expect(t.tieneAcuerdo, isTrue);
    });

    test('con descuento, también', () {
      final t = PlatformTenantSummary.fromMap(
        _negocio(descuento: 97, loQueDiceElServidor: 4500),
      );
      expect(t.tieneAcuerdo, isTrue);
    });

    test('sin nada de eso, es la tarifa del plan', () {
      final t = PlatformTenantSummary.fromMap(
        _negocio(loQueDiceElServidor: 150000),
      );
      expect(t.tieneAcuerdo, isFalse);
    });

    test('no se deduce leyendo el motivo, igual que en la sede (D-237)', () {
      // Un negocio cuyo motivo dice "Pionero (50% de por vida)" pero que no
      // tiene ni precio ni descuento **no tiene acuerdo**. Existe de verdad
      // en la base: Prueba Barberia Elite, con `is_founder` en false y ese
      // texto puesto. Una cadena pensada para leerse no decide sobre dinero.
      final t = PlatformTenantSummary.fromMap({
        'tenant_id': 'x',
        'tenant_name': 'El del motivo que no cuadra',
        'price_reason': 'Pionero (50% de por vida)',
        'effective_monthly_price': 150000,
      });

      expect(t.tieneAcuerdo, isFalse);
    });
  });
}
