import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/main.dart';
import 'package:salonymas/pages/my_stylist_agenda_page.dart';
import 'package:salonymas/pages/tickets_page.dart';
import 'package:salonymas/models/tenant_entitlements.dart';

void main() {
  group('Paso 8.13 — Lo que el plan permite llega a la interfaz (TL-19)', () {
    // Forma real de lo que devuelve `get_my_entitlements()`.
    final respuestaBasico = <dynamic>[
      {
        'feature_key': 'inventory',
        'entitled': false,
        'limit_value': null,
        'source': 'plan',
      },
      {
        'feature_key': 'financial_reports',
        'entitled': false,
        'limit_value': null,
        'source': 'plan',
      },
      {
        'feature_key': 'portfolio',
        'entitled': false,
        'limit_value': null,
        'source': 'plan',
      },
      {
        'feature_key': 'branches',
        'entitled': true,
        'limit_value': 1,
        'source': 'plan',
      },
      {
        'feature_key': 'team_members',
        'entitled': true,
        'limit_value': 5,
        'source': 'plan',
      },
    ];

    test('fromList lee las capacidades y sus límites', () {
      final e = TenantEntitlements.fromList(respuestaBasico);

      expect(e.consultado, true);
      expect(e.permite(ClaveDeCapacidad.inventario), false);
      expect(e.permite(ClaveDeCapacidad.reportesFinancieros), false);
      expect(e.limiteDe(ClaveDeCapacidad.sedes), 1);
      expect(e.limiteDe(ClaveDeCapacidad.cuentasDeEquipo), 5);
    });

    test('un plan que sí incluye la capacidad la deja pasar', () {
      final e = TenantEntitlements.fromList(<dynamic>[
        {'feature_key': 'inventory', 'entitled': true, 'limit_value': null},
      ]);

      expect(e.permite(ClaveDeCapacidad.inventario), true);
    });

    test('bloqueadas lista solo las que el plan no cubre', () {
      final e = TenantEntitlements.fromList(respuestaBasico);

      expect(
        e.bloqueadas..sort(),
        containsAll(<String>['financial_reports', 'inventory', 'portfolio']),
      );
      expect(e.bloqueadas.contains('branches'), false);
    });

    // Estas tres son la razón de ser del diseño: la interfaz NO es la frontera
    // de seguridad — quien impide de verdad la operación es el backend, con
    // `beautyos_require_entitlement` dentro de las RPC. Si esto fallara
    // cerrado, un fallo de red dejaría a un salón que SÍ paga sin acceso a sus
    // propios módulos.
    test('sin haber consultado nada, no bloquea', () {
      const e = TenantEntitlements.desconocido();

      expect(e.consultado, false);
      expect(e.permite(ClaveDeCapacidad.inventario), true);
      expect(e.permite(ClaveDeCapacidad.reportesFinancieros), true);
    });

    test('una capacidad que no vino en la respuesta tampoco bloquea', () {
      final e = TenantEntitlements.fromList(respuestaBasico);

      expect(e.permite('capacidad_que_no_existe_todavia'), true);
    });

    test('un módulo sin capacidad exigida pasa siempre', () {
      final e = TenantEntitlements.fromList(respuestaBasico);

      expect(e.permite(null), true);
      expect(e.permite(''), true);
    });

    test('una respuesta con filas basura no rompe ni bloquea de más', () {
      final e = TenantEntitlements.fromList(<dynamic>[
        'esto no es un mapa',
        {'feature_key': null, 'entitled': false},
        {'feature_key': '', 'entitled': false},
        {'feature_key': 'inventory', 'entitled': false},
      ]);

      expect(e.permite(ClaveDeCapacidad.inventario), false);
      expect(e.permite(ClaveDeCapacidad.resenas), true);
    });
  });

  group('Paso 8.13 — El módulo se ve con candado, no se esconde', () {
    test('conCandado marca la sección y conserva todo lo demás', () {
      const original = BeautySection(
        'Inventario',
        Icons.inventory_2_outlined,
        category: BeautyCategory.finanzas,
      );

      final bloqueada = original.conCandado();

      expect(original.bloqueadoPorPlan, false);
      expect(bloqueada.bloqueadoPorPlan, true);
      // Esconder el módulo mataría la venta: la escalera de planes de D-124
      // solo funciona si el dueño ve lo que se está perdiendo.
      expect(bloqueada.title, 'Inventario');
      expect(bloqueada.icon, Icons.inventory_2_outlined);
      expect(bloqueada.category, BeautyCategory.finanzas);
    });

    test('las acciones sueltas del paso 8.14 fallan abiertas por defecto', () {
      // Si alguien cambiara estos valores por defecto a false, un salón que sí
      // paga se quedaría sin subir fotos ni mandar enlaces de reseña en cuanto
      // la consulta de entitlements fallara una vez. Quien impide de verdad la
      // operación es el backend (D-184, D-187).
      const tickets = TicketsPage(branchId: 'x', isOwnerOrAdmin: true);
      expect(tickets.puedePortafolio, true);
      expect(tickets.puedeResenas, true);

      const agenda = MyStylistAgendaPage(branchId: 'x');
      expect(agenda.puedePortafolio, true);
    });

    test('un módulo sin capacidad exigida no declara ninguna', () {
      const modulo = BeautyModule(
        section: BeautySection('Agenda', Icons.calendar_month_outlined),
        page: SizedBox.shrink(),
        allowedRoles: <String>{'owner'},
      );

      expect(modulo.requiredFeature, null);
    });
  });
}
