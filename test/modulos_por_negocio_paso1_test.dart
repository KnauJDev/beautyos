import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/tenant_entitlements.dart';

/// Lee un archivo del proyecto con los saltos de línea normalizados: los del
/// repositorio están en CRLF y las comparaciones de abajo usan `\n`.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// D-310, paso 1 del plan del primer cliente real (D-308): la plataforma le
/// apaga a un negocio los módulos que no usa, y desaparecen de su app.
void main() {
  group('el modelo distingue "apagado por la plataforma" de "no lo trae el plan"', () {
    final e = TenantEntitlements.fromList([
      {'feature_key': 'cash_register', 'entitled': false, 'source': 'override'},
      {'feature_key': 'inventory', 'entitled': false, 'source': 'plan'},
      {'feature_key': 'blog', 'entitled': true, 'source': 'plan'},
      {'feature_key': 'reviews', 'entitled': true, 'source': 'override'},
    ]);

    test('apagado desde el Panel: se esconde', () {
      expect(e.apagadoPorLaPlataforma(ClaveDeCapacidad.cajaYCobros), isTrue);
    });

    test('el plan no lo trae: NO se esconde (sigue con candado, D-184)', () {
      expect(e.apagadoPorLaPlataforma(ClaveDeCapacidad.inventario), isFalse);
      expect(e.permite(ClaveDeCapacidad.inventario), isFalse);
    });

    test('encendido, por el plan o por una excepción que concede: se ve', () {
      expect(e.apagadoPorLaPlataforma(ClaveDeCapacidad.blog), isFalse);
      expect(e.apagadoPorLaPlataforma(ClaveDeCapacidad.resenas), isFalse);
    });

    test('sin consultar, o sin clave, no se esconde nada', () {
      const nada = TenantEntitlements.desconocido();
      expect(nada.apagadoPorLaPlataforma(ClaveDeCapacidad.cajaYCobros), isFalse);
      expect(e.apagadoPorLaPlataforma(null), isFalse);
      expect(e.apagadoPorLaPlataforma('no_existe'), isFalse);
    });
  });

  group('la app', () {
    final main = leer('lib/main.dart');

    test('cada módulo que se puede apagar dice con qué interruptor', () {
      for (final (pagina, clave) in [
        ('TicketsPage', 'cajaYCobros'),
        // El Dashboard tiene su propio interruptor desde el 04-oct (D-317):
        // lo vigila `dashboard_de_atenciones_d317_test.dart`.
        ('FotosTrabajosPage', 'portafolio'),
        ('ResenasPage', 'resenas'),
        ('BlogPage', 'blog'),
        ('MyCommissionSummaryPage', 'comisiones'),
        ('MyStylistWorkPhotosPage', 'portafolio'),
        ('MyStylistReviewsPage', 'resenas'),
      ]) {
        expect(
          main,
          contains('ocultableCon: ClaveDeCapacidad.$clave,\n        page: $pagina('),
          reason: pagina,
        );
      }
    });

    test('lo apagado se filtra del menú, con su interruptor o el del plan', () {
      expect(
        main,
        contains(
          '!entitlements.apagadoPorLaPlataforma(\n'
          '            module.ocultableCon ?? module.requiredFeature,',
        ),
      );
    });

    test('con la caja apagada, la agenda no ofrece abrir el ticket ni cobrar', () {
      // Sin esto, abrir el ticket saltaría al módulo siguiente a la agenda,
      // que sin Tickets sería Clientes.
      expect(main, contains('onOpenTicket: cajaOculta\n              ? null'));
      expect(main, contains('onCollectTicket: cajaOculta\n              ? null'));
    });
  });

  group('el Panel', () {
    final panel = leer('lib/pages/platform_panel_page.dart');

    test('ofrece los siete interruptores, con las claves del servidor', () {
      for (final clave in [
        ClaveDeCapacidad.cajaYCobros,
        ClaveDeCapacidad.reportesFinancieros,
        ClaveDeCapacidad.inventario,
        ClaveDeCapacidad.comisiones,
        ClaveDeCapacidad.portafolio,
        ClaveDeCapacidad.resenas,
        ClaveDeCapacidad.blog,
      ]) {
        expect(panel, contains("('$clave', "), reason: clave);
      }
      expect(panel, contains("'Módulos que ve este negocio'"));
    });

    test('apagar pone una excepción y encender la cierra; ninguna se borra', () {
      expect(panel, contains('enabled: false,'));
      expect(panel, contains('deleteTenantFeatureOverride(o.overrideId)'));
    });

    test('una excepción que apaga no se lee como un límite', () {
      expect(panel, contains(": apagado',"));
    });
  });

  test('la migración solo añade, y enciende lo nuevo en todos los planes', () {
    final m = leer(
      'supabase/migrations/20261002180000_capacidades_por_negocio_paso1.sql',
    );
    for (final clave in ['cash_register', 'commissions', 'blog']) {
      expect(m, contains("'$clave'"), reason: clave);
    }
    expect(m, contains('select p.id, f.id, true'));
    expect('on conflict ('.allMatches(m).length, 2);
    expect(m.toLowerCase(), isNot(contains('create or replace function')));
    expect(m.toLowerCase(), isNot(contains('update ')));
    expect(m.toLowerCase(), isNot(contains('delete ')));
  });
}
