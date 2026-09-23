import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_subscription.dart';
import 'package:salonymas/models/platform_tenant_summary.dart';
import 'package:salonymas/models/tenant_subscription_status.dart';

/// Hallazgo **BI** (23-sep): vencer sin pagar no pasa a mora.
///
/// Solo un pago **rechazado** por ePayco pone una suscripción en `past_due`, y
/// aquí el pago es manual cada mes: quien simplemente no paga se queda en
/// `active` con la fecha pasada. El propietario lo vio en su pantalla el
/// 23-sep: la cabecera decía en verde *Vence 22/09/2026*, la sede *Al día ·
/// Pagada hasta 22/09*, y **Nueva cita** respondía *"La prueba gratis de este
/// negocio esta vencida"*.
///
/// Estas pruebas cubren **la mitad de la pantalla**: que lo vencido se vea
/// vencido y que una sede vencida se pueda renovar. La otra mitad —que el
/// servidor mueva el estado por fecha, con su gracia, y corte las sedes— es
/// una migración con su control, y no la ejercita ninguna prueba de Flutter.
final _ayer = DateTime.now().subtract(const Duration(days: 1));
final _enTresDias = DateTime.now().add(const Duration(days: 3));
final _enVeinteDias = DateTime.now().add(const Duration(days: 20));

TenantSubscriptionStatus _negocio(String estado, DateTime? finDePeriodo) =>
    TenantSubscriptionStatus.fromMap({
      'tenant_id': 'x',
      'tenant_name': 'Naguara de Uñas',
      'subscription_status': estado,
      'plan_name': 'Todo Incluido',
      'current_period_end': finDePeriodo?.toIso8601String(),
    });

BranchSubscription _sede({
  String status = 'active',
  bool alDia = true,
  DateTime? finDePeriodo,
  bool activada = true,
}) => BranchSubscription.fromMap({
  'branch_id': 's',
  'branch_name': 'Naguara de Uñas',
  'is_primary': true,
  'branch_active': true,
  'status': status,
  'al_dia': alDia,
  'precio_cop': 10000,
  'current_period_end': finDePeriodo?.toIso8601String(),
  'activated_at': activada ? '2026-08-22T00:00:00Z' : null,
});

void main() {
  group('BI — el negocio: activo con la fecha pasada no es verde', () {
    test('activo y vencido se reconoce como vencido', () {
      final s = _negocio('active', _ayer);

      expect(s.isActive, isTrue, reason: 'la base sigue diciendo active');
      expect(s.isPeriodExpired, isTrue);
      expect(s.isActiveAndCurrent, isFalse);
      expect(s.statusLabel, 'Período vencido');
    });

    test('activo y dentro de su período sigue siendo verde', () {
      final s = _negocio('active', _enVeinteDias);

      expect(s.isPeriodExpired, isFalse);
      expect(s.isActiveAndCurrent, isTrue);
      expect(s.statusLabel, 'Suscripción Activa');
    });

    test('la prueba vencida no se confunde con el período vencido', () {
      final s = TenantSubscriptionStatus.fromMap({
        'tenant_id': 'x',
        'tenant_name': 'x',
        'subscription_status': 'trialing',
        'trial_ends_at': _ayer.toIso8601String(),
      });

      expect(s.isPeriodExpired, isFalse);
      expect(s.statusLabel, 'Prueba Vencida');
    });

    test('el panel de plataforma dice VENCIDO SIN PAGAR, no ACTIVO', () {
      final t = PlatformTenantSummary.fromMap({
        'tenant_id': 'x',
        'tenant_name': 'Naguara de Uñas',
        'subscription_status': 'active',
        'current_period_end': _ayer.toIso8601String(),
      });

      expect(t.isPeriodExpired, isTrue);
      expect(t.estadoLegible, 'VENCIDO SIN PAGAR');
    });

    test('la ficha ya no enseña el estado crudo en inglés', () {
      // La lista decía ACTIVO y la ficha "Estado: ACTIVE". Ahora las dos leen
      // del mismo sitio.
      final t = PlatformTenantSummary.fromMap({
        'tenant_id': 'x',
        'tenant_name': 'x',
        'subscription_status': 'active',
        'current_period_end': _enVeinteDias.toIso8601String(),
      });

      expect(t.estadoLegible, 'ACTIVO');
      final panel = File(
        'lib/pages/platform_panel_page.dart',
      ).readAsStringSync();
      expect(panel, isNot(contains(r"'Estado: ${status?.toUpperCase()")));
    });
  });

  group('BI — la sede: la fecha manda sobre la bandera del servidor', () {
    test('"al día" con la fecha pasada ya no está al día', () {
      final s = _sede(finDePeriodo: _ayer);

      expect(s.alDia, isTrue, reason: 'es lo que manda el servidor hoy');
      expect(s.periodoVencido, isTrue);
      expect(s.estaAlDia, isFalse);
      expect(s.etiquetaEstado, 'Período vencido');
    });

    test('al día y lejos de vencer: al día, sin botón de pagar antes', () {
      final s = _sede(finDePeriodo: _enVeinteDias);

      expect(s.estaAlDia, isTrue);
      expect(s.etiquetaEstado, 'Al día');
      expect(s.puedeRenovarAntes, isFalse);
    });

    test('a pocos días de vencer se puede pagar el mes siguiente', () {
      // El servidor ya lo cobra sin correr la fecha de corte
      // (renovacion_anticipada, D-191); lo que faltaba era el botón.
      final s = _sede(finDePeriodo: _enTresDias);

      expect(s.estaAlDia, isTrue);
      expect(s.puedeRenovarAntes, isTrue);
    });

    test('una sede que nunca se pagó no es "vencida"', () {
      final s = _sede(status: 'pending', alDia: false, activada: false);

      expect(s.periodoVencido, isFalse);
      expect(s.etiquetaEstado, 'Pendiente de activar');
    });
  });

  group('BI — la cabecera ya no abre el cobro que D-252 cerró', () {
    // Las tres píldoras llamaban a `iniciarPago` sin sede: el cobro del
    // negocio entero, que el servidor niega desde el 22-sep. Quien pulsaba
    // "Prueba vencida · Activar plan" recibía un error.
    final main = File('lib/main.dart').readAsStringSync();
    final inicio = main.indexOf('class _TrialHeaderBadge');
    final fin = main.indexOf('class _UserProfileMenu');
    final pildora = main.substring(inicio, fin);

    test('la píldora no llama a iniciarPago', () {
      expect(inicio, greaterThan(0));
      expect(pildora, isNot(contains('iniciarPago')));
      expect(pildora, contains('onIrAPagar'));
    });

    test('la píldora vencida existe y es roja', () {
      expect(pildora, contains('isPeriodExpired'));
      expect(pildora, contains("'Venció el "));
    });

    test('el respaldo del nombre del plan ya no es un plan jubilado (BD)', () {
      expect(pildora, isNot(contains('?? "Profesional"')));
    });
  });

  group('D-261 — pasada la gracia, la pantalla dice lo que la base ya hace', () {
    test('la cabecera avisa del negocio suspendido o sin gracia', () {
      final main = File('lib/main.dart').readAsStringSync();
      final inicio = main.indexOf('class _TrialHeaderBadge');
      final pildora = main.substring(
        inicio,
        main.indexOf('class _UserProfileMenu'),
      );

      expect(pildora, contains('status.isSuspended'));
      expect(pildora, contains("'Suspendido por falta de pago · Pagar'"));
      expect(pildora, contains('!status.isGracePeriodActive'));
    });

    test('Tus sedes explica qué no puede hacer una sede suspendida', () {
      final tarjeta = File(
        'lib/widgets/sedes_suscripcion_card.dart',
      ).readAsStringSync();

      expect(tarjeta, contains("sede.status == 'suspended'"));
      expect(tarjeta, contains('no puede agendar citas'));
    });
  });

  group('BJ — el resumen de la cita no enseña una barra invertida', () {
    test('el salto de línea es un salto, no los caracteres \\n', () {
      final tickets = File('lib/pages/tickets_page.dart').readAsStringSync();
      expect(tickets, isNot(contains(r"$resolvedStylistName\\n'")));
    });
  });
}
